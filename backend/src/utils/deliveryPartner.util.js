const { query } = require('../db/postgres');
const { ASSIGNMENT } = require('../config/businessRules');
const { activeAssignmentStatuses } = require('../services/assignment.constants');
const { logger } = require('../utils/logger');
const {
  FLEET_OPERATIONAL_STATUS,
  RIDER_RETURN_ETA_SOCKET_EVENT,
} = require('../constants/deliveryPartner.constants');

const loadEtaService = () => require('../services/eta.service');
const loadOperationalEvents = () => require('../utils/operationalEvents.util');

const MAX_ACTIVE_ORDERS = ASSIGNMENT.maxActiveOrders;

/**
 * Count rider orders that are assigned or out-for-delivery (load-cap basis).
 */
async function countRiderActiveOrders(deliveryPartnerId, dbClient = null) {
  const runQuery = dbClient ? dbClient.query.bind(dbClient) : query;
  const { rows } = await runQuery(
    `SELECT COUNT(*)::int AS active_count
     FROM order_assignments oa
     JOIN orders o ON o.id = oa.order_id
     WHERE oa.delivery_partner_id = $1
       AND oa.status = ANY($2::assignment_status[])
       AND o.status NOT IN ('DELIVERED', 'CANCELLED')`,
    [deliveryPartnerId, activeAssignmentStatuses]
  );
  return Number(rows[0]?.active_count || 0);
}

async function countRiderActiveOrdersForUser(userId, dbClient = null) {
  const partnerId = await getDeliveryPartnerIdForUser(userId);
  if (!partnerId) return 0;
  return countRiderActiveOrders(partnerId, dbClient);
}

function getRiderRemainingCapacity(activeCount) {
  return Math.max(0, MAX_ACTIVE_ORDERS - Number(activeCount || 0));
}

function isRiderAtLoadCap(activeCount) {
  return Number(activeCount || 0) >= MAX_ACTIVE_ORDERS;
}

async function getDeliveryPartnerIdForUser(userId) {
  const { rows } = await query(
    'SELECT id FROM delivery_partners WHERE user_id = $1',
    [userId]
  );
  return rows[0]?.id ? Number(rows[0].id) : null;
}

/**
 * Derive fleet operational status from online flag and active order count.
 */
function deriveFleetOperationalStatus(isOnline, activeOrderCount) {
  if (!isOnline) return FLEET_OPERATIONAL_STATUS.OFFLINE;
  if (Number(activeOrderCount || 0) > 0) return FLEET_OPERATIONAL_STATUS.BUSY;
  return FLEET_OPERATIONAL_STATUS.AVAILABLE;
}

function formatOperationalSnapshot(row) {
  if (!row) return null;
  const activeOrderCount = Number(row.active_order_count ?? 0);
  const operationalStatus =
    row.availability_status ||
    deriveFleetOperationalStatus(Boolean(row.is_online), activeOrderCount);

  return {
    deliveryPartnerId: Number(row.id),
    riderUserId: row.user_id != null ? Number(row.user_id) : null,
    operationalStatus,
    estimatedReturnMinutes:
      row.estimated_return_minutes != null ? Number(row.estimated_return_minutes) : null,
    estimatedReturnAt: row.estimated_return_at
      ? new Date(row.estimated_return_at).toISOString()
      : null,
    activeOrderCount,
    isOnline: Boolean(row.is_online),
  };
}

/**
 * Build return ETA metadata for assignment observe mode (no persistence).
 */
async function buildReturnEtaObserveMetadata({
  deliveryPartnerId,
  riderUserId,
  riderLat,
  riderLng,
  isOnline,
  activeOrderCount,
}) {
  const operationalStatus = deriveFleetOperationalStatus(isOnline, activeOrderCount);
  let estimatedReturnMinutes = 0;
  let estimatedReturnAt = null;

  if (
    operationalStatus === FLEET_OPERATIONAL_STATUS.BUSY &&
    Number.isFinite(Number(riderLat)) &&
    Number.isFinite(Number(riderLng))
  ) {
    const returnEta = await loadEtaService().calculateReturnToStoreETA({
      riderUserId,
      riderLat: Number(riderLat),
      riderLng: Number(riderLng),
      deliveryPartnerId,
    });
    estimatedReturnMinutes = returnEta.estimatedReturnMinutes;
    estimatedReturnAt = returnEta.estimatedReturnAt;
  }

  return {
    deliveryPartnerId: Number(deliveryPartnerId),
    riderUserId: riderUserId != null ? Number(riderUserId) : null,
    operationalStatus,
    estimatedReturnMinutes,
    estimatedReturnAt,
    activeOrderCount: Number(activeOrderCount || 0),
  };
}

function hasOperationalSnapshotChanged(previous, next) {
  if (!previous) return true;
  return (
    previous.operationalStatus !== next.operationalStatus ||
    previous.activeOrderCount !== next.activeOrderCount ||
    previous.estimatedReturnMinutes !== next.estimatedReturnMinutes ||
    previous.estimatedReturnAt !== next.estimatedReturnAt
  );
}

function emitReturnEtaSocketUpdate(io, snapshot) {
  if (!io || !snapshot) return;
  const payload = {
    deliveryPartnerId: snapshot.deliveryPartnerId,
    riderUserId: snapshot.riderUserId,
    operationalStatus: snapshot.operationalStatus,
    estimatedReturnMinutes: snapshot.estimatedReturnMinutes,
    estimatedReturnAt: snapshot.estimatedReturnAt,
    activeOrderCount: snapshot.activeOrderCount,
    timestamp: new Date().toISOString(),
  };
  io.to('admin_room').emit(RIDER_RETURN_ETA_SOCKET_EVENT, payload);
  if (snapshot.riderUserId) {
    const riderUserId = Number(snapshot.riderUserId);
    io.to(`delivery_${riderUserId}`).emit(RIDER_RETURN_ETA_SOCKET_EVENT, payload);
    io.to(`rider:${riderUserId}`).emit(RIDER_RETURN_ETA_SOCKET_EVENT, payload);
  }
}

/**
 * Recompute and persist fleet operational state + return ETA for a delivery partner.
 */
async function refreshPartnerOperationalState({
  deliveryPartnerId,
  io = null,
  dbClient = null,
  reason = 'refresh',
  recordEvent = true,
}) {
  const partnerId = Number(deliveryPartnerId);
  if (!Number.isFinite(partnerId) || partnerId <= 0) {
    return null;
  }

  const runQuery = dbClient ? dbClient.query.bind(dbClient) : query;

  const { rows } = await runQuery(
    `SELECT id, user_id, is_online, current_lat, current_lng,
            availability_status, estimated_return_at, estimated_return_minutes, active_order_count
     FROM delivery_partners
     WHERE id = $1`,
    [partnerId]
  );
  const partner = rows[0];
  if (!partner) return null;

  const previousSnapshot = formatOperationalSnapshot(partner);
  const activeOrderCount = await countRiderActiveOrders(partnerId, dbClient);
  const operationalStatus = deriveFleetOperationalStatus(partner.is_online, activeOrderCount);

  let estimatedReturnMinutes = null;
  let estimatedReturnAt = null;

  if (operationalStatus === FLEET_OPERATIONAL_STATUS.BUSY) {
    const lat = Number(partner.current_lat);
    const lng = Number(partner.current_lng);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      const returnEta = await loadEtaService().calculateReturnToStoreETA({
        riderUserId: Number(partner.user_id),
        riderLat: lat,
        riderLng: lng,
        deliveryPartnerId: partnerId,
        dbClient,
      });
      estimatedReturnMinutes = returnEta.estimatedReturnMinutes;
      estimatedReturnAt = returnEta.estimatedReturnAt;
    } else {
      estimatedReturnMinutes = 0;
    }
  } else {
    estimatedReturnMinutes = 0;
  }

  await runQuery(
    `UPDATE delivery_partners
     SET availability_status = $1,
         active_order_count = $2,
         estimated_return_at = $3,
         estimated_return_minutes = $4,
         updated_at = NOW()
     WHERE id = $5`,
    [
      operationalStatus,
      activeOrderCount,
      estimatedReturnAt,
      estimatedReturnMinutes,
      partnerId,
    ]
  );

  const nextSnapshot = {
    deliveryPartnerId: partnerId,
    riderUserId: Number(partner.user_id),
    operationalStatus,
    estimatedReturnMinutes,
    estimatedReturnAt,
    activeOrderCount,
    isOnline: Boolean(partner.is_online),
  };

  const changed = hasOperationalSnapshotChanged(previousSnapshot, nextSnapshot);
  if (changed && io) {
    emitReturnEtaSocketUpdate(io, nextSnapshot);
  }

  if (changed && recordEvent && io) {
    const { publishOperationalEventAsync, OPERATIONAL_EVENT_TYPES, ACTOR_TYPES } =
      loadOperationalEvents();
    publishOperationalEventAsync(io, {
      eventType: OPERATIONAL_EVENT_TYPES.RIDER_RETURN_ETA_UPDATED,
      actorType: ACTOR_TYPES.SYSTEM,
      riderId: partnerId,
      metadata: {
        reason,
        operationalStatus,
        estimatedReturnMinutes,
        estimatedReturnAt,
        activeOrderCount,
      },
    });
  }

  logger.debug('partner_operational_state_refreshed', {
    deliveryPartnerId: partnerId,
    reason,
    operationalStatus,
    activeOrderCount,
    estimatedReturnMinutes,
    changed,
  });

  return nextSnapshot;
}

async function getPartnerOperationalSnapshot(deliveryPartnerId) {
  const { rows } = await query(
    `SELECT id, user_id, is_online, availability_status,
            estimated_return_at, estimated_return_minutes, active_order_count
     FROM delivery_partners
     WHERE id = $1`,
    [Number(deliveryPartnerId)]
  );
  return formatOperationalSnapshot(rows[0]);
}

module.exports = {
  getDeliveryPartnerIdForUser,
  countRiderActiveOrders,
  countRiderActiveOrdersForUser,
  getRiderRemainingCapacity,
  isRiderAtLoadCap,
  deriveFleetOperationalStatus,
  buildReturnEtaObserveMetadata,
  refreshPartnerOperationalState,
  getPartnerOperationalSnapshot,
  formatOperationalSnapshot,
  emitReturnEtaSocketUpdate,
  MAX_ACTIVE_ORDERS,
  FLEET_OPERATIONAL_STATUS,
};
