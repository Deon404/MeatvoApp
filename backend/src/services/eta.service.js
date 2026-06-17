/**
 * ETA (Estimated Time of Arrival) Service
 * Calculates and updates real-time delivery ETA based on rider location
 */

const { query } = require('../db/postgres');
const { haversineDistanceKm } = require('../utils/distance.util');
const { logger } = require('../utils/logger');

// Vehicle average speeds (km/h)
const VEHICLE_SPEEDS = {
  bike: 25,
  scooter: 30,
  motorcycle: 35,
  car: 40,
  bicycle: 15,
  walking: 5,
  default: 25,
};

// Traffic multipliers by time of day
const TRAFFIC_FACTORS = {
  // Hour: multiplier
  7: 1.3,  // Morning rush
  8: 1.4,
  9: 1.3,
  12: 1.2, // Lunch
  13: 1.2,
  17: 1.4, // Evening rush
  18: 1.5,
  19: 1.3,
  20: 1.2,
  default: 1.0,
};

/**
 * Get traffic multiplier based on current hour
 */
function getTrafficMultiplier(date = new Date()) {
  const hour = date.getHours();
  return TRAFFIC_FACTORS[hour] || TRAFFIC_FACTORS.default;
}

/**
 * Get rider's average speed from historical data
 */
async function getRiderAverageSpeed(riderUserId) {
  const { rows } = await query(
    `SELECT 
      dp.vehicle_type,
      AVG(EXTRACT(EPOCH FROM (oa.updated_at - oa.assigned_at)) / 60) as avg_minutes,
      AVG(CASE WHEN reh.distance_km > 0 THEN reh.distance_km ELSE 2 END) as avg_distance
     FROM delivery_partners dp
     LEFT JOIN order_assignments oa ON oa.delivery_partner_id = dp.id
     LEFT JOIN rider_earnings_history reh ON reh.order_id = oa.order_id
     WHERE dp.user_id = $1
       AND oa.status = 'DELIVERED'
       AND oa.assigned_at >= NOW() - INTERVAL '30 days'
     GROUP BY dp.vehicle_type`,
    [riderUserId]
  );

  if (rows[0] && rows[0].avg_minutes && rows[0].avg_distance) {
    const avgMinutes = parseFloat(rows[0].avg_minutes);
    const avgDistance = parseFloat(rows[0].avg_distance);
    // Speed = Distance / Time (convert minutes to hours)
    const speedKmh = (avgDistance / avgMinutes) * 60;
    return Math.max(10, Math.min(50, speedKmh)); // Clamp between 10-50 km/h
  }

  // Fallback to vehicle type default speed
  const vehicleType = rows[0]?.vehicle_type || 'default';
  return VEHICLE_SPEEDS[vehicleType] || VEHICLE_SPEEDS.default;
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
  const roadDistanceKm = distanceKm * 1.2;

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
  const bufferMinutes = 2;
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

    // Update order ETA in database
    await query(
      `UPDATE orders 
       SET eta_minutes = $1, updated_at = CURRENT_TIMESTAMP 
       WHERE id = $2`,
      [etaData.etaMinutes, orderId]
    );

    // Emit real-time update to customer and admin
    const etaPayload = {
      orderId: Number(orderId),
      eta: etaData.etaMinutes,
      distance: etaData.distanceKm,
      riderLocation: {
        lat: riderLocation.lat,
        lng: riderLocation.lng,
      },
      timestamp: new Date().toISOString(),
    };

    if (io) {
      // Emit to customer
      if (order.customer_id) {
        io.to(`customer_${order.customer_id}`).emit('eta:updated', etaPayload);
        io.to(`order_${orderId}`).emit('eta:updated', etaPayload);
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
    if (distanceMeters <= 500 && order.status === 'OUT_FOR_DELIVERY') {
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
      return { etaMinutes: 30, distanceKm: 0 }; // Default 30 minutes
    }

    const storeLat = parseFloat(storeRows[0].center_lat);
    const storeLng = parseFloat(storeRows[0].center_lng);
    const deliveryLat = parseFloat(orderAddress.lat);
    const deliveryLng = parseFloat(orderAddress.lng);

    const distanceKm = haversineDistanceKm(storeLat, storeLng, deliveryLat, deliveryLng);
    const roadDistanceKm = distanceKm * 1.2;

    // Use default speed if no rider assigned yet
    const avgSpeed = riderId 
      ? await getRiderAverageSpeed(riderId) 
      : VEHICLE_SPEEDS.default;

    // Add packing time (10 minutes) + delivery time
    const packingMinutes = 10;
    let deliveryMinutes = (roadDistanceKm / avgSpeed) * 60;
    deliveryMinutes *= getTrafficMultiplier();
    deliveryMinutes += 2; // Buffer

    const totalMinutes = packingMinutes + deliveryMinutes;

    return {
      etaMinutes: Math.ceil(totalMinutes),
      distanceKm: Number(distanceKm.toFixed(2)),
    };
  } catch (error) {
    logger.error('initial_eta_calculation_failed', { error: error.message });
    return { etaMinutes: 30, distanceKm: 0 };
  }
}

module.exports = {
  calculateETA,
  updateLiveETA,
  handleRiderLocationUpdate,
  checkRiderNearby,
  getInitialETA,
  VEHICLE_SPEEDS,
};
