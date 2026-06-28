/**
 * ETA (Estimated Time of Arrival) Service
 * Calculates and updates real-time delivery ETA based on rider location
 */

const { query } = require('../db/postgres');
const { haversineDistanceKm } = require('../utils/distance.util');
const { logger } = require('../utils/logger');
const { ETA, ROUTING, STORE, getTrafficMultiplier } = require('../config/businessRules');
const { haversineKm } = require('../modules/delivery/route-optimizer');

const BATCH_ETA_MESSAGE = 'Rider is completing earlier deliveries.';

const VEHICLE_SPEEDS = ETA.vehicleSpeedsKmh;
const TRAFFIC_FACTORS = ETA.trafficFactors;

/**
 * Get rider's average speed from historical data
 */
async function getRiderAverageSpeed(riderUserId) {
  const { rows } = await query(
    `SELECT 
      dp.vehicle_type,
      AVG(EXTRACT(EPOCH FROM (oa.updated_at - oa.assigned_at)) / 60) as avg_minutes,
      AVG(CASE WHEN reh.distance_km > 0 THEN reh.distance_km ELSE ${ETA.fallbackAvgDistanceKm} END) as avg_distance
     FROM delivery_partners dp
     LEFT JOIN order_assignments oa ON oa.delivery_partner_id = dp.id
     LEFT JOIN rider_earnings_history reh ON reh.order_id = oa.order_id
     WHERE dp.user_id = $1
       AND oa.status = 'DELIVERED'
       AND oa.assigned_at >= NOW() - INTERVAL '${ETA.riderHistoricalLookbackDays} days'
     GROUP BY dp.vehicle_type`,
    [riderUserId]
  );

  if (rows[0] && rows[0].avg_minutes && rows[0].avg_distance) {
    const avgMinutes = parseFloat(rows[0].avg_minutes);
    const avgDistance = parseFloat(rows[0].avg_distance);
    // Speed = Distance / Time (convert minutes to hours)
    const speedKmh = (avgDistance / avgMinutes) * 60;
    return Math.max(ETA.riderSpeedClampMinKmh, Math.min(ETA.riderSpeedClampMaxKmh, speedKmh));
  }

  // Fallback to vehicle type default speed
  const vehicleType = rows[0]?.vehicle_type || 'default';
  return VEHICLE_SPEEDS[vehicleType] || VEHICLE_SPEEDS.default;
}

function parseAddressCoords(address) {
  const parsed = typeof address === 'string' ? JSON.parse(address) : address;
  const lat = Number(parsed?.lat);
  const lng = Number(parsed?.lng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) return null;
  return { lat, lng, text: parsed?.text || '' };
}

async function getStoreCenter() {
  try {
    const { rows } = await query(
      `SELECT center_lat, center_lng
       FROM store_settings
       ORDER BY updated_at DESC
       LIMIT 1`
    );
    const lat = Number(rows[0]?.center_lat);
    const lng = Number(rows[0]?.center_lng);
    if (Number.isFinite(lat) && Number.isFinite(lng)) {
      return { lat, lng };
    }
  } catch {
    // fall through to businessRules default
  }
  return { lat: STORE.centerLat, lng: STORE.centerLng };
}

/**
 * Fetch active delivery stops for a partner (out-for-delivery + pending returns).
 */
async function getActiveDeliveryStops(deliveryPartnerId, dbClient = null) {
  const runQuery = dbClient ? dbClient.query.bind(dbClient) : query;
  const { rows } = await runQuery(
    `SELECT o.id, o.address, o.status
     FROM order_assignments oa
     JOIN orders o ON o.id = oa.order_id
     WHERE oa.delivery_partner_id = $1
       AND oa.status IN ('ASSIGNED', 'ACCEPTED', 'PICKED')
       AND o.status NOT IN ('DELIVERED', 'CANCELLED')`,
    [deliveryPartnerId]
  );

  return rows
    .map((row) => {
      const coords = parseAddressCoords(row.address);
      if (!coords) return null;
      return {
        orderId: Number(row.id),
        lat: coords.lat,
        lng: coords.lng,
        status: row.status,
      };
    })
    .filter(Boolean);
}

/**
 * Greedy route through remaining stops, then return leg to store.
 * Used for rider return ETA (Phase 4).
 */
async function calculateReturnToStoreETA({
  riderUserId,
  riderLat,
  riderLng,
  deliveryPartnerId,
  dbClient = null,
}) {
  const lat = Number(riderLat);
  const lng = Number(riderLng);
  if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
    return { estimatedReturnMinutes: 0, estimatedReturnAt: null, distanceKm: 0 };
  }

  const stops = await getActiveDeliveryStops(deliveryPartnerId, dbClient);
  if (!stops.length) {
    return { estimatedReturnMinutes: 0, estimatedReturnAt: null, distanceKm: 0 };
  }

  const store = await getStoreCenter();
  let currentLat = lat;
  let currentLng = lng;
  let totalMinutes = 0;
  let totalDistanceKm = 0;
  const visited = new Set();

  while (visited.size < stops.length) {
    let nearestIdx = -1;
    let nearestDist = Infinity;
    for (let i = 0; i < stops.length; i++) {
      if (visited.has(i)) continue;
      const dist = haversineKm(currentLat, currentLng, stops[i].lat, stops[i].lng);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIdx = i;
      }
    }
    if (nearestIdx < 0) break;

    const stop = stops[nearestIdx];
    visited.add(nearestIdx);
    totalDistanceKm += nearestDist;
    const roadKm = nearestDist * ETA.roadDistanceFactor;
    const segmentMinutes = (roadKm / ROUTING.avgSpeedKmh) * 60;
    totalMinutes += Math.ceil(segmentMinutes * getTrafficMultiplier());
    totalMinutes += ROUTING.stopMinutes;
    currentLat = stop.lat;
    currentLng = stop.lng;
  }

  const returnLeg = await calculateETA({
    riderLat: currentLat,
    riderLng: currentLng,
    deliveryLat: store.lat,
    deliveryLng: store.lng,
    riderUserId,
  });
  totalMinutes += returnLeg.etaMinutes;
  totalDistanceKm += returnLeg.distanceKm;

  const estimatedReturnMinutes = Math.max(0, Math.ceil(totalMinutes));
  const estimatedReturnAt =
    estimatedReturnMinutes > 0
      ? new Date(Date.now() + estimatedReturnMinutes * 60_000).toISOString()
      : null;

  return {
    estimatedReturnMinutes,
    estimatedReturnAt,
    distanceKm: Number(totalDistanceKm.toFixed(2)),
  };
}

async function resolveBatchQueueContext(orderId, riderLocation) {
  const { rows } = await query(
    `SELECT o.id, o.address, o.status, oa.batch_ids
     FROM orders o
     JOIN order_assignments oa ON oa.order_id = o.id
     WHERE o.id = $1`,
    [orderId]
  );
  const order = rows[0];
  if (!order?.batch_ids) return null;

  let batchIds = order.batch_ids;
  if (typeof batchIds === 'string') {
    try {
      batchIds = JSON.parse(batchIds);
    } catch {
      return null;
    }
  }
  if (!Array.isArray(batchIds) || batchIds.length <= 1) return null;

  const numericBatchIds = batchIds.map(Number).filter((id) => id > 0);
  const { rows: batchOrders } = await query(
    `SELECT o.id, o.address, o.status
     FROM orders o
     WHERE o.id = ANY($1::bigint[])
       AND o.status NOT IN ('DELIVERED', 'CANCELLED')`,
    [numericBatchIds]
  );

  if (batchOrders.length <= 1) return null;

  const points = batchOrders
    .map((row) => {
      const coords = parseAddressCoords(row.address);
      if (!coords) return null;
      return {
        orderId: Number(row.id),
        lat: coords.lat,
        lng: coords.lng,
        status: row.status,
      };
    })
    .filter(Boolean);

  if (points.length <= 1) return null;

  let currentLat = Number(riderLocation.lat);
  let currentLng = Number(riderLocation.lng);
  const visited = new Set();
  const routeOrder = [];
  let totalDistanceKm = 0;

  while (visited.size < points.length) {
    let nearestIdx = -1;
    let nearestDist = Infinity;
    for (let i = 0; i < points.length; i++) {
      if (visited.has(i)) continue;
      const dist = haversineKm(currentLat, currentLng, points[i].lat, points[i].lng);
      if (dist < nearestDist) {
        nearestDist = dist;
        nearestIdx = i;
      }
    }
    if (nearestIdx < 0) break;
    visited.add(nearestIdx);
    totalDistanceKm += nearestDist;
    routeOrder.push(points[nearestIdx]);
    currentLat = points[nearestIdx].lat;
    currentLng = points[nearestIdx].lng;
  }

  const queuePosition = routeOrder.findIndex((stop) => stop.orderId === Number(orderId)) + 1;
  if (queuePosition <= 0) return null;

  const stopsRemaining = routeOrder.length - queuePosition;
  const isFirstStop = queuePosition === 1;

  let adjustedETA = null;
  if (!isFirstStop) {
    let cumulativeKm = 0;
    let lat = Number(riderLocation.lat);
    let lng = Number(riderLocation.lng);
    for (let i = 0; i < queuePosition; i++) {
      const stop = routeOrder[i];
      cumulativeKm += haversineKm(lat, lng, stop.lat, stop.lng);
      lat = stop.lat;
      lng = stop.lng;
    }
    const travelMinutes = Math.ceil((cumulativeKm / ROUTING.avgSpeedKmh) * 60);
    adjustedETA =
      travelMinutes + queuePosition * ROUTING.stopMinutes + ETA.bufferMinutes;
  }

  return {
    queuePosition,
    stopsRemaining,
    adjustedETA,
    isFirstStop,
    batchSize: routeOrder.length,
    message: isFirstStop ? null : BATCH_ETA_MESSAGE,
  };
}

function buildEtaPayload(orderId, etaData, batchContext = null) {
  const payload = {
    orderId: Number(orderId),
    eta: etaData.etaMinutes,
    distance: etaData.distanceKm,
    timestamp: new Date().toISOString(),
  };

  if (batchContext && !batchContext.isFirstStop) {
    payload.queuePosition = batchContext.queuePosition;
    payload.stopsRemaining = batchContext.stopsRemaining;
    payload.adjustedETA = batchContext.adjustedETA;
    payload.eta = batchContext.adjustedETA;
    payload.etaMinutes = batchContext.adjustedETA;
    payload.message = batchContext.message;
    payload.isBatchEta = true;
  } else if (batchContext) {
    payload.queuePosition = 1;
    payload.stopsRemaining = batchContext.stopsRemaining;
    payload.adjustedETA = etaData.etaMinutes;
    payload.isBatchEta = true;
  }

  return payload;
}

/**
 * Calculate ETA in minutes
 */
async function calculateETA({
  riderLat,
  riderLng,
  deliveryLat,
  deliveryLng,
  riderUserId,
  includeTraffic = true,
}) {
  // Calculate straight-line distance
  const distanceKm = haversineDistanceKm(riderLat, riderLng, deliveryLat, deliveryLng);

  // Add 20% for actual road distance (conservative estimate)
  const roadDistanceKm = distanceKm * ETA.roadDistanceFactor;

  // Get rider's average speed
  const avgSpeed = await getRiderAverageSpeed(riderUserId);

  // Calculate base time in minutes
  let etaMinutes = (roadDistanceKm / avgSpeed) * 60;

  // Apply traffic factor
  if (includeTraffic) {
    const trafficMultiplier = getTrafficMultiplier();
    etaMinutes *= trafficMultiplier;
  }

  // Add buffer time (stops, parking, finding address)
  const bufferMinutes = ETA.bufferMinutes;
  etaMinutes += bufferMinutes;

  return {
    etaMinutes: Math.ceil(etaMinutes),
    distanceKm: Number(distanceKm.toFixed(2)),
    roadDistanceKm: Number(roadDistanceKm.toFixed(2)),
    avgSpeedKmh: Number(avgSpeed.toFixed(1)),
    trafficFactor: includeTraffic ? getTrafficMultiplier() : 1.0,
  };
}

/**
 * Update live ETA for an order based on rider's current location
 */
async function updateLiveETA(orderId, riderLocation, io) {
  try {
    // Get order delivery address
    const { rows: orderRows } = await query(
      `SELECT o.id, o.customer_id, o.address, oa.delivery_partner_id, dp.user_id as rider_user_id
       FROM orders o
       JOIN order_assignments oa ON oa.order_id = o.id
       JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
       WHERE o.id = $1`,
      [orderId]
    );

    if (!orderRows[0]) {
      return null;
    }

    const order = orderRows[0];
    const address = typeof order.address === 'string' 
      ? JSON.parse(order.address) 
      : order.address;

    if (!address || !address.lat || !address.lng) {
      logger.warn('eta_calculation_no_address', { orderId });
      return null;
    }

    const deliveryLat = parseFloat(address.lat);
    const deliveryLng = parseFloat(address.lng);

    // Calculate ETA
    const etaData = await calculateETA({
      riderLat: riderLocation.lat,
      riderLng: riderLocation.lng,
      deliveryLat,
      deliveryLng,
      riderUserId: order.rider_user_id,
    });

    const batchContext = await resolveBatchQueueContext(orderId, riderLocation);
    const effectiveEtaMinutes =
      batchContext && !batchContext.isFirstStop
        ? batchContext.adjustedETA
        : etaData.etaMinutes;

    // Update order ETA in database
    await query(
      `UPDATE orders 
       SET eta_minutes = $1, updated_at = CURRENT_TIMESTAMP 
       WHERE id = $2`,
      [effectiveEtaMinutes, orderId]
    );

    const etaPayload = {
      ...buildEtaPayload(orderId, etaData, batchContext),
      riderLocation: {
        lat: riderLocation.lat,
        lng: riderLocation.lng,
      },
    };

    if (io) {
      // Emit to customer
      if (order.customer_id) {
        io.to(`customer_${order.customer_id}`).emit('eta:updated', etaPayload);
        io.to(`order:${orderId}`).emit('eta:updated', etaPayload);
      }
      
      // Emit to admin
      io.to('admin_room').emit('eta:updated', etaPayload);
    }

    logger.info('eta_updated', {
      orderId,
      etaMinutes: etaData.etaMinutes,
      distanceKm: etaData.distanceKm,
    });

    return etaData;
  } catch (error) {
    logger.error('eta_calculation_failed', {
      error: error.message,
      orderId,
    });
    return null;
  }
}

/**
 * Handle rider location update and recalculate ETA
 */
async function handleRiderLocationUpdate(riderId, location, io) {
  try {
    // Get all active orders for this rider
    const { rows } = await query(
      `SELECT o.id
       FROM orders o
       JOIN order_assignments oa ON oa.order_id = o.id
       JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
       WHERE dp.user_id = $1
         AND o.status IN ('OUT_FOR_DELIVERY', 'RIDER_NEARBY')
         AND oa.status IN ('ACCEPTED', 'PICKED')`,
      [riderId]
    );

    // Update ETA for each active order
    for (const row of rows) {
      await updateLiveETA(row.id, location, io);
    }

    return { updated: rows.length };
  } catch (error) {
    logger.error('rider_location_eta_update_failed', {
      error: error.message,
      riderId,
    });
    return { updated: 0 };
  }
}

/**
 * Check if rider is nearby (within 500m) and trigger notification
 */
async function checkRiderNearby(orderId, riderLocation) {
  try {
    const { rows } = await query(
      `SELECT o.id, o.customer_id, o.address, o.status
       FROM orders o
       WHERE o.id = $1`,
      [orderId]
    );

    if (!rows[0]) return false;

    const order = rows[0];
    const address = typeof order.address === 'string' 
      ? JSON.parse(order.address) 
      : order.address;

    if (!address || !address.lat || !address.lng) {
      return false;
    }

    const distanceKm = haversineDistanceKm(
      riderLocation.lat,
      riderLocation.lng,
      parseFloat(address.lat),
      parseFloat(address.lng)
    );

    const distanceMeters = distanceKm * 1000;

    // Rider is within 500 meters
    if (distanceMeters <= ETA.nearbyThresholdMeters && order.status === 'OUT_FOR_DELIVERY') {
      // Auto-transition to RIDER_NEARBY
      await query(
        `UPDATE orders SET status = 'RIDER_NEARBY' WHERE id = $1 AND status = 'OUT_FOR_DELIVERY'`,
        [orderId]
      );

      logger.info('rider_nearby_triggered', {
        orderId,
        distanceMeters: Math.round(distanceMeters),
      });

      return true;
    }

    return false;
  } catch (error) {
    logger.error('check_rider_nearby_failed', {
      error: error.message,
      orderId,
    });
    return false;
  }
}

/**
 * Get estimated delivery time for a new order
 */
async function getInitialETA(orderAddress, riderId = null) {
  try {
    // Get store location
    const { rows: storeRows } = await query(
      `SELECT center_lat, center_lng FROM settings WHERE id = 1`
    );

    if (!storeRows[0] || !orderAddress.lat || !orderAddress.lng) {
      return { etaMinutes: ETA.initialFallbackMinutes, distanceKm: 0 };
    }

    const storeLat = parseFloat(storeRows[0].center_lat);
    const storeLng = parseFloat(storeRows[0].center_lng);
    const deliveryLat = parseFloat(orderAddress.lat);
    const deliveryLng = parseFloat(orderAddress.lng);

    const distanceKm = haversineDistanceKm(storeLat, storeLng, deliveryLat, deliveryLng);
    const roadDistanceKm = distanceKm * ETA.roadDistanceFactor;

    // Use default speed if no rider assigned yet
    const avgSpeed = riderId 
      ? await getRiderAverageSpeed(riderId) 
      : VEHICLE_SPEEDS.default;

    // Add packing time (10 minutes) + delivery time
    const packingMinutes = ETA.initialPackingMinutes;
    let deliveryMinutes = (roadDistanceKm / avgSpeed) * 60;
    deliveryMinutes *= getTrafficMultiplier();
    deliveryMinutes += ETA.bufferMinutes;

    const totalMinutes = packingMinutes + deliveryMinutes;

    return {
      etaMinutes: Math.ceil(totalMinutes),
      distanceKm: Number(distanceKm.toFixed(2)),
    };
  } catch (error) {
    logger.error('initial_eta_calculation_failed', { error: error.message });
    return { etaMinutes: ETA.initialFallbackMinutes, distanceKm: 0 };
  }
}

module.exports = {
  calculateETA,
  calculateReturnToStoreETA,
  getStoreCenter,
  getActiveDeliveryStops,
  updateLiveETA,
  handleRiderLocationUpdate,
  checkRiderNearby,
  getInitialETA,
  resolveBatchQueueContext,
  buildEtaPayload,
  BATCH_ETA_MESSAGE,
  VEHICLE_SPEEDS,
};
