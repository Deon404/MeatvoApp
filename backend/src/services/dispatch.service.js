const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { PACK_AGE } = require('../config/businessRules');
const { assignableOrderStatuses } = require('./assignment.constants');
const { assignOrderToPartner } = require('./assignment.service');
const { computePackAgeMinutes, getPackAgeTier } = require('./packAge.service');

/**
 * Fetch PACKED orders waiting in the dispatch queue (no active assignment).
 * Priority orders (pack age >= threshold) are returned first.
 */
async function getDispatchQueueOrders({ limit = 20 } = {}) {
  const { rows } = await query(
    `SELECT o.id, o.packed_at, o.created_at, o.status
     FROM orders o
     LEFT JOIN order_assignments oa
       ON oa.order_id = o.id
       AND oa.status = ANY($2::assignment_status[])
     WHERE o.status = ANY($1::order_status[])
       AND oa.id IS NULL
       AND COALESCE(o.failed_delivery_resolution, '') != 'PENDING'
     ORDER BY
       CASE
         WHEN o.packed_at IS NOT NULL
           AND o.packed_at <= NOW() - ($3::text || ' minutes')::interval
         THEN 0
         ELSE 1
       END,
       o.packed_at ASC NULLS LAST,
       o.created_at ASC
     LIMIT $4`,
    [
      assignableOrderStatuses,
      ['ASSIGNED', 'ACCEPTED', 'PICKED'],
      String(PACK_AGE.dispatchPriorityMinutes),
      limit,
    ]
  );
  return rows;
}

/**
 * Attempt to assign queued PACKED orders after a rider slot opens.
 */
async function processDispatchQueue(io, { triggerOrderId = null } = {}) {
  const queued = await getDispatchQueueOrders({ limit: 10 });
  if (!queued.length) {
    return { processed: 0, assigned: [] };
  }

  const assigned = [];
  for (const row of queued) {
    if (triggerOrderId && Number(row.id) === Number(triggerOrderId)) {
      continue;
    }
    try {
      const result = await assignOrderToPartner({ orderId: row.id, io });
      if (result?.assigned) {
        assigned.push(Number(row.id));
      }
      if (result?.reason === 'rider_load_cap' || result?.reason === 'no_eligible_partners') {
        break;
      }
    } catch (err) {
      logger.error('dispatch_queue_assign_failed', {
        orderId: row.id,
        error: err.message,
      });
    }
  }

  if (assigned.length) {
    logger.info('dispatch_queue_processed', {
      assignedOrderIds: assigned,
      triggerOrderId: triggerOrderId ?? null,
    });
  }

  return { processed: queued.length, assigned };
}

function enrichDispatchQueueMeta(orderRow) {
  const packAgeMinutes = computePackAgeMinutes(orderRow.packed_at);
  const packAgeTier = getPackAgeTier(packAgeMinutes);
  return {
    packAgeMinutes,
    packAgeTier,
    dispatchPriority: packAgeTier === 'priority' || packAgeTier === 'warning' || packAgeTier === 'critical',
  };
}

module.exports = {
  getDispatchQueueOrders,
  processDispatchQueue,
  enrichDispatchQueueMeta,
};
