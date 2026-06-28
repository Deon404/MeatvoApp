const { PACK_AGE } = require('../config/businessRules');
const redis = require('../db/redis');
const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const {
  publishOperationalEventAsync,
  OPERATIONAL_EVENT_TYPES,
  ACTOR_TYPES,
} = require('../utils/operationalEvents.util');
const { assignableOrderStatuses } = require('./assignment.constants');

function computePackAgeMinutes(packedAt) {
  if (!packedAt) return null;
  const packedMs = new Date(packedAt).getTime();
  if (!Number.isFinite(packedMs)) return null;
  return Math.floor((Date.now() - packedMs) / 60_000);
}

function getPackAgeTier(packAgeMinutes) {
  if (packAgeMinutes == null) return 'unknown';
  if (packAgeMinutes >= PACK_AGE.criticalMinutes) return 'critical';
  if (packAgeMinutes >= PACK_AGE.warningMinutes) return 'warning';
  if (packAgeMinutes >= PACK_AGE.dispatchPriorityMinutes) return 'priority';
  return 'normal';
}

function enrichOrderWithPackAge(orderRow) {
  const packAgeMinutes = computePackAgeMinutes(orderRow.packed_at);
  const packAgeTier = getPackAgeTier(packAgeMinutes);
  return {
    packedAt: orderRow.packed_at ?? null,
    packAgeMinutes,
    packAgeTier,
    dispatchPriority: packAgeTier !== 'normal' && packAgeTier !== 'unknown',
  };
}

const ALERT_TTL_SECONDS = 24 * 60 * 60;

async function shouldEmitPackAgeAlert(orderId, tier) {
  const key = `pack_age:alert:${orderId}:${tier}`;
  const set = await redis.set(key, '1', 'EX', ALERT_TTL_SECONDS, 'NX');
  return set === 'OK';
}

async function clearPackAgeAlerts(orderId) {
  const tiers = ['warning', 'critical'];
  await Promise.all(
    tiers.map((tier) => redis.del(`pack_age:alert:${orderId}:${tier}`))
  );
}

/**
 * Scan PACKED unassigned orders and emit admin warnings / critical alerts.
 */
async function monitorPackAge(io) {
  const { rows } = await query(
    `SELECT o.id, o.packed_at, o.status
     FROM orders o
     LEFT JOIN order_assignments oa
       ON oa.order_id = o.id
       AND oa.status = ANY($2::assignment_status[])
     WHERE o.status = ANY($1::order_status[])
       AND oa.id IS NULL
       AND o.packed_at IS NOT NULL`,
    [assignableOrderStatuses, ['ASSIGNED', 'ACCEPTED', 'PICKED']]
  );

  let warnings = 0;
  let critical = 0;

  for (const row of rows) {
    const packAgeMinutes = computePackAgeMinutes(row.packed_at);
    const tier = getPackAgeTier(packAgeMinutes);

    if (tier === 'warning') {
      const emit = await shouldEmitPackAgeAlert(row.id, 'warning');
      if (!emit) continue;
      warnings += 1;
      publishOperationalEventAsync(io, {
        eventType: OPERATIONAL_EVENT_TYPES.PACK_AGE_WARNING,
        orderId: row.id,
        actorType: ACTOR_TYPES.SYSTEM,
        metadata: {
          packAge: packAgeMinutes,
          packAgeMinutes,
          tier,
          dispatchDelay: packAgeMinutes,
          message: 'Packed order waiting over 15 minutes',
        },
      });
      if (io) {
        io.to('admin_room').emit('order:pack_age_alert', {
          orderId: Number(row.id),
          packAgeMinutes,
          tier: 'warning',
          message: `Order #${row.id} packed ${packAgeMinutes} min ago — dispatch delayed`,
          timestamp: new Date().toISOString(),
        });
      }
    } else if (tier === 'critical') {
      const emit = await shouldEmitPackAgeAlert(row.id, 'critical');
      if (!emit) continue;
      critical += 1;
      publishOperationalEventAsync(io, {
        eventType: OPERATIONAL_EVENT_TYPES.PACK_AGE_CRITICAL,
        orderId: row.id,
        actorType: ACTOR_TYPES.SYSTEM,
        metadata: {
          packAge: packAgeMinutes,
          packAgeMinutes,
          tier,
          dispatchDelay: packAgeMinutes,
          message: 'Packed order waiting over 20 minutes',
        },
      });
      if (io) {
        io.to('admin_room').emit('order:pack_age_alert', {
          orderId: Number(row.id),
          packAgeMinutes,
          tier: 'critical',
          message: `CRITICAL: Order #${row.id} packed ${packAgeMinutes} min ago — immediate dispatch required`,
          timestamp: new Date().toISOString(),
        });
      }
    }
  }

  if (warnings || critical) {
    logger.warn('pack_age_monitor_alerts', { warnings, critical });
  }

  return { scanned: rows.length, warnings, critical };
}

module.exports = {
  computePackAgeMinutes,
  getPackAgeTier,
  enrichOrderWithPackAge,
  monitorPackAge,
  clearPackAgeAlerts,
};
