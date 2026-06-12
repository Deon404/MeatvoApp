/**
 * Tracking Service
 * ETA calculation and real-time rider tracking
 */

const { query } = require('../db/postgres');
const { logger } = require('../utils/logger');
const { haversineDistanceKm } = require('../utils/distance.util');
const { sendRiderNearbyNotification } = require('./notification.service');
const { ORDER_STATES, transitionOrderState } = require('./orderLifecycle.service');
const { 
  handleRiderLocationUpdate, 
  checkRiderNearby 
} = require('./eta.service');

// Average speed in km/h for different vehicle types
const VEHICLE_SPEEDS = {
  bike: 25,
  scooter: 30,
  bicycle: 15,
  car: 35,
  default: 25,
};

// Nearby distance threshold in km
const NEARBY_THRESHOLD_KM = 0.5; // 500 meters

// Store last known rider positions
const riderPositions = new Map();

/**
 * Calculate ETA based on distance and vehicle type
 */
function calculateETA(distanceKm, vehicleType = 'default') {
  const speed = VEHICLE_SPEEDS[vehicleType] || VEHICLE_SPEEDS.default;
  
  // Time in hours
  const timeHours = distanceKm / speed;
  
  // Convert to minutes and add buffer time (20%)
  const timeMinutes = Math.ceil(timeHours * 60 * 1.2);
  
  return Math.max(5, timeMinutes); // Minimum 5 minutes
}

/**
 * Get distance to customer
 */
async function getDistanceToCustomer(riderLat, riderLng, orderId) {
  try {
    const { rows } = await query(
      'SELECT address FROM orders WHERE id = $1',
      [orderId]
    );
    
    if (!rows[0] || !rows[0].address) {
      return null;
    }

    const address = rows[0].address;
    if (typeof address === 'object' && address.lat && address.lng) {
      const customerLat = Number(address.lat);
      const customerLng = Number(address.lng);
      
      if (Number.isFinite(customerLat) && Number.isFinite(customerLng)) {
        return haversineDistanceKm(
          riderLat,
          riderLng,
          customerLat,
          customerLng
        );
      }
    }
    
    return null;
  } catch (error) {
    logger.error('get_distance_to_customer_failed', {
      error: error.message,
      orderId,
    });
    return null;
  }
}

/**
 * Update rider location and calculate ETA
 */
async function updateRiderLocation({
  riderUserId,
  lat,
  lng,
  orderId = null,
  io = null,
}) {
  try {
    // Store position
    const position = {
      lat: Number(lat),
      lng: Number(lng),
      timestamp: new Date().toISOString(),
    };
    riderPositions.set(riderUserId, position);

    // Update in database
    const { rows: dpRows } = await query(
      `UPDATE delivery_partners
       SET current_lat = $1, current_lng = $2
       WHERE user_id = $3
       RETURNING id, user_id, is_online, current_lat, current_lng, vehicle_type`,
      [lat, lng, riderUserId]
    );

    if (!dpRows[0]) {
      throw new Error('Delivery partner not found');
    }

    // Use advanced ETA service to recalculate for all active orders
    await handleRiderLocationUpdate(riderUserId, { lat, lng }, io);

    // Check if rider is nearby any order
    if (orderId) {
      const isNearby = await checkRiderNearby(orderId, { lat, lng });
      
      if (isNearby) {
        // Get order and rider info
        const { rows: orderRows } = await query(
          'SELECT customer_id FROM orders WHERE id = $1',
          [orderId]
        );
        
        const { rows: userRows } = await query(
          'SELECT name FROM users WHERE id = $1',
          [riderUserId]
        );
        
        if (orderRows[0]) {
          const riderName = userRows[0]?.name || 'Your delivery partner';
          
          // Send nearby notification
          await sendRiderNearbyNotification({
            orderId,
            customerId: orderRows[0].customer_id,
            riderName,
            eta: 5, // Nearby = ~5 minutes
            io,
          });
        }
      }
    }

    // Emit location update with backward compatibility
    const { rows: activeOrders } = await query(
      `SELECT o.id AS order_id, o.customer_id
       FROM order_assignments oa
       JOIN orders o ON o.id = oa.order_id
       JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
       WHERE dp.user_id = $1
         AND o.status IN ($2, $3, $4)`,
      [riderUserId, ORDER_STATES.OUT_FOR_DELIVERY, ORDER_STATES.RIDER_NEARBY, ORDER_STATES.RIDER_ACCEPTED]
    );

    // Emit legacy location updates for backward compatibility
    for (const order of activeOrders) {
      if (io) {
        io.to(`customer_${order.customer_id}`).emit('rider:location_update', {
          orderId: order.order_id,
          lat,
          lng,
          timestamp: position.timestamp,
        });

        // Also emit legacy events
        io.to(`customer_${order.customer_id}`).emit('delivery:location', {
          orderId: order.order_id,
          lat,
          lng,
          timestamp: position.timestamp,
        });

        io.to(`customer_${order.customer_id}`).emit('partner:location_update', {
          orderId: order.order_id,
          lat,
          lng,
          timestamp: position.timestamp,
        });
      }
    }

    return {
      success: true,
      position,
    };
  } catch (error) {
    logger.error('update_rider_location_failed', {
      error: error.message,
      riderUserId,
      orderId,
    });
    throw error;
  }
}

/**
 * Get rider's current location
 */
async function getRiderLocation(riderUserId) {
  try {
    // Check memory first
    const cached = riderPositions.get(riderUserId);
    if (cached) {
      const age = Date.now() - new Date(cached.timestamp).getTime();
      // Return cached if less than 30 seconds old
      if (age < 30000) {
        return cached;
      }
    }

    // Fetch from database
    const { rows } = await query(
      `SELECT current_lat as lat, current_lng as lng
       FROM delivery_partners
       WHERE user_id = $1`,
      [riderUserId]
    );

    if (rows[0] && rows[0].lat && rows[0].lng) {
      const position = {
        lat: Number(rows[0].lat),
        lng: Number(rows[0].lng),
        timestamp: new Date().toISOString(),
      };
      riderPositions.set(riderUserId, position);
      return position;
    }

    return null;
  } catch (error) {
    logger.error('get_rider_location_failed', {
      error: error.message,
      riderUserId,
    });
    return null;
  }
}

/**
 * Get order tracking info
 */
async function getOrderTrackingInfo(orderId) {
  try {
    // Get order details
    const { rows: orderRows } = await query(
      `SELECT o.id, o.customer_id, o.status, o.address, o.created_at,
              oa.delivery_partner_id, oa.assigned_at,
              dp.current_lat, dp.current_lng, dp.vehicle_type,
              u.name as rider_name, u.phone as rider_phone
       FROM orders o
       LEFT JOIN order_assignments oa ON oa.order_id = o.id
       LEFT JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
       LEFT JOIN users u ON u.id = dp.user_id
       WHERE o.id = $1`,
      [orderId]
    );

    if (!orderRows[0]) {
      throw new Error('Order not found');
    }

    const order = orderRows[0];
    const tracking = {
      orderId: order.id,
      status: order.status,
      createdAt: order.created_at,
      customerAddress: null,
      rider: null,
      eta: null,
      distance: null,
    };

    // Parse customer address
    if (order.address && typeof order.address === 'object') {
      tracking.customerAddress = {
        text: order.address.text || '',
        lat: order.address.lat,
        lng: order.address.lng,
      };
    }

    // Add rider info if assigned
    if (order.delivery_partner_id && order.current_lat && order.current_lng) {
      const riderLat = Number(order.current_lat);
      const riderLng = Number(order.current_lng);

      tracking.rider = {
        name: order.rider_name,
        phone: order.rider_phone,
        vehicleType: order.vehicle_type,
        location: {
          lat: riderLat,
          lng: riderLng,
        },
      };

      // Calculate distance and ETA
      const distance = await getDistanceToCustomer(riderLat, riderLng, orderId);
      if (distance !== null) {
        tracking.distance = distance.toFixed(2);
        tracking.eta = calculateETA(distance, order.vehicle_type);
      }
    }

    return tracking;
  } catch (error) {
    logger.error('get_order_tracking_info_failed', {
      error: error.message,
      orderId,
    });
    throw error;
  }
}

/**
 * Monitor rider's online status
 */
async function checkRiderOnlineStatus(riderUserId, io) {
  try {
    const position = riderPositions.get(riderUserId);
    
    if (!position) {
      return true; // No data yet
    }

    const age = Date.now() - new Date(position.timestamp).getTime();
    const OFFLINE_THRESHOLD = 5 * 60 * 1000; // 5 minutes

    if (age > OFFLINE_THRESHOLD) {
      // Rider might be offline
      const { rows: activeOrders } = await query(
        `SELECT o.id, o.customer_id
         FROM order_assignments oa
         JOIN orders o ON o.id = oa.order_id
         JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
         WHERE dp.user_id = $1
           AND o.status IN ($2, $3)`,
        [riderUserId, ORDER_STATES.OUT_FOR_DELIVERY, ORDER_STATES.RIDER_NEARBY]
      );

      if (activeOrders.length > 0 && io) {
        // Alert admin
        io.to('admin_room').emit('rider:potentially_offline', {
          riderUserId,
          activeOrders: activeOrders.map(o => o.id),
          lastSeen: position.timestamp,
        });
      }

      return false;
    }

    return true;
  } catch (error) {
    logger.error('check_rider_online_status_failed', {
      error: error.message,
      riderUserId,
    });
    return true;
  }
}

module.exports = {
  calculateETA,
  updateRiderLocation,
  getRiderLocation,
  getOrderTrackingInfo,
  checkRiderOnlineStatus,
  getDistanceToCustomer,
};
