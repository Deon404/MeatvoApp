/**
 * Order Lifecycle Service
 * Manages complete order lifecycle with state transitions and notifications
 */

const { query, withTransaction } = require('../db/postgres');
const { logger } = require('../utils/logger');
const {
  ORDER_STATES,
  canTransition,
  canActorTriggerState,
  getAvailableActions,
} = require('../utils/enhancedOrderStateMachine');
const {
  sendOrderStateNotifications,
  sendRiderNearbyNotification,
} = require('./notification.service');
const {
  assignOrderToPartner,
  cancelRiderAssignmentForOrder,
  notifyRiderAssignmentCancelled,
} = require('./assignment.service');
const {
  calculateDeliveryEarnings,
  recordEarningsHistory,
  updateRiderEarnings,
} = require('./earnings.service');
const { emitOrderLifecycleEvent } = require('../utils/orderSocketEmit');
const { instrumentOrderStateTransition } = require('../utils/operationalEvents.util');
const { assertWeightReconciliationForDispatch } = require('../utils/weightReconciliationDispatch.util');

/**
 * Transition order to new state
 */
async function transitionOrderState({
  orderId,
  newState,
  actor,
  actorRole,
  context = {},
  io = null,
}) {
  try {
    // Get current order
    const { rows: orderRows } = await query(
      'SELECT id, customer_id, status, payment_mode, payment_status FROM orders WHERE id = $1',
      [orderId]
    );
    
    const order = orderRows[0];
    if (!order) {
      throw new Error('Order not found');
    }

    const currentState = order.status;

    // Validate transition
    if (!canTransition(currentState, newState)) {
      throw new Error(
        `Invalid transition from ${currentState} to ${newState}`
      );
    }

    // Validate actor
    if (!canActorTriggerState(newState, actorRole)) {
      throw new Error(
        `Role ${actorRole} cannot trigger state ${newState}`
      );
    }

    // LIFECYCLE FIX: block CONFIRMED+ for online orders until payment settles (COD exempt)
    const paymentMode = String(order.payment_mode || '').toUpperCase();
    const paymentStatus = String(order.payment_status || 'PENDING').toUpperCase();
    const postConfirmStates = new Set([
      ORDER_STATES.CONFIRMED,
      ORDER_STATES.PACKING_STARTED,
      ORDER_STATES.PACKED,
      ORDER_STATES.RIDER_ASSIGNED,
      ORDER_STATES.RIDER_ACCEPTED,
      ORDER_STATES.OUT_FOR_DELIVERY,
      ORDER_STATES.DELIVERED,
    ]);
    if (
      paymentMode === 'ONLINE' &&
      postConfirmStates.has(newState) &&
      !['PAID', 'PAYMENT_VERIFIED'].includes(paymentStatus) &&
      newState !== ORDER_STATES.CANCELLED
    ) {
      const isAdminOverride = actorRole === 'admin' && context.adminOverride === true;
      if (!isAdminOverride) {
        throw new Error(
          `Online payment must be PAID before transitioning to ${newState} (current: ${paymentStatus})`
        );
      }
      logger.warn('admin_payment_override', {
        orderId,
        actor,
        newState,
        paymentStatus,
      });
    }

    // Weight reconciliation must complete before PACKED or dispatch (OUT_FOR_DELIVERY).
    if (
      newState === ORDER_STATES.PACKED ||
      newState === ORDER_STATES.OUT_FOR_DELIVERY
    ) {
      const { rows: reconRows } = await query(
        `SELECT weight_reconciliation_status FROM orders WHERE id = $1`,
        [orderId]
      );
      assertWeightReconciliationForDispatch(
        reconRows[0]?.weight_reconciliation_status
      );
    }

    // Update order state
    await query('UPDATE orders SET status = $1 WHERE id = $2', [
      newState,
      orderId,
    ]);

    let cancelledPartnerUserId = null;
    if (newState === ORDER_STATES.CANCELLED) {
      const assignmentResult = await cancelRiderAssignmentForOrder({ orderId });
      cancelledPartnerUserId = assignmentResult.partnerUserId;
    }

    // Log state change
    logger.info('order_state_changed', {
      orderId,
      from: currentState,
      to: newState,
      actor,
      actorRole,
    });

    // Get rider info if exists
    let riderUserId = null;
    const { rows: assignmentRows } = await query(
      `SELECT dp.user_id, u.name as rider_name, u.phone as rider_phone
       FROM order_assignments oa
       JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
       JOIN users u ON u.id = dp.user_id
       WHERE oa.order_id = $1`,
      [orderId]
    );
    
    if (assignmentRows[0]) {
      riderUserId = assignmentRows[0].user_id;
      context.riderName = assignmentRows[0].rider_name;
      context.riderPhone = assignmentRows[0].rider_phone;
    }

    // Get customer info
    const { rows: customerRows } = await query(
      'SELECT phone FROM users WHERE id = $1',
      [order.customer_id]
    );
    if (customerRows[0]) {
      context.customerPhone = customerRows[0].phone;
    }

    // Get address for context
    const { rows: orderDetailRows } = await query(
      'SELECT address FROM orders WHERE id = $1',
      [orderId]
    );
    if (orderDetailRows[0] && orderDetailRows[0].address) {
      const address = orderDetailRows[0].address;
      if (typeof address === 'object' && address.text) {
        context.customerAddress = address.text.substring(0, 50) + '...';
      }
    }

    // Send notifications
    await sendOrderStateNotifications({
      orderId,
      newState,
      customerId: order.customer_id,
      riderUserId,
      context,
      io,
    });

    if (newState === ORDER_STATES.CANCELLED) {
      notifyRiderAssignmentCancelled({
        orderId,
        partnerUserId: cancelledPartnerUserId,
        io,
        reason: 'order_cancelled',
      });
    }

    // LIFECYCLE FIX: emit to canonical + legacy socket rooms on every transition
    if (io) {
      const payload = {
        orderId,
        status: newState,
        updatedAt: new Date().toISOString(),
        ...context,
      };
      emitOrderLifecycleEvent(io, {
        orderId,
        customerId: order.customer_id,
        riderUserId,
        payload,
      });
    }

    // Handle automatic state-based actions
    await handleStateActions(orderId, newState, io);

    instrumentOrderStateTransition(io, {
      orderId,
      previousState: currentState,
      newState,
      actor,
      actorRole,
      metadata: context,
    });

    if (
      newState === ORDER_STATES.PACKED ||
      newState === ORDER_STATES.DELIVERED
    ) {
      const { scheduleCapacitySuggestionCheck } = require('./capacitySuggestion.service');
      scheduleCapacitySuggestionCheck(io);
    }

    return {
      success: true,
      orderId,
      oldState: currentState,
      newState,
    };
  } catch (error) {
    logger.error('order_state_transition_failed', {
      error: error.message,
      orderId,
      newState,
    });
    throw error;
  }
}

/**
 * Handle automatic actions when entering a state
 */
async function handleStateActions(orderId, state, io) {
  try {
    switch (state) {
      case ORDER_STATES.CONFIRMED:
        // Auto-start packing after a delay (optional)
        // setTimeout(() => {
        //   transitionOrderState({
        //     orderId,
        //     newState: ORDER_STATES.PACKING_STARTED,
        //     actor: 'system',
        //     actorRole: 'system',
        //     io,
        //   });
        // }, 5000);
        break;

      case ORDER_STATES.PACKED:
        // Auto-assign rider (fire-and-forget — do not block mark-packed response)
        logger.info('auto_assigning_rider', { orderId });
        assignOrderToPartner({ orderId, io }).catch((err) => {
          logger.error('packed_auto_assign_failed', { orderId, error: err.message });
        });
        break;

      case ORDER_STATES.RIDER_REJECTED:
        // Reassign to another rider
        logger.info('reassigning_after_rejection', { orderId });
        await query('UPDATE orders SET status = $1 WHERE id = $2', [
          ORDER_STATES.PACKED,
          orderId,
        ]);
        setTimeout(() => {
          assignOrderToPartner({ orderId, io });
        }, 2000);
        break;

      case ORDER_STATES.DELIVERED:
        // Calculate and record advanced earnings
        const { rows: assignmentRows } = await query(
          `SELECT oa.delivery_partner_id, oa.assigned_at, oa.updated_at,
                  o.total_amount, o.created_at, o.address,
                  dp.user_id as rider_user_id
           FROM order_assignments oa
           JOIN orders o ON o.id = oa.order_id
           JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
           WHERE oa.order_id = $1`,
          [orderId]
        );
        
        if (assignmentRows[0]) {
          const assignment = assignmentRows[0];
          
          // Calculate distance if address has coordinates
          let distanceKm = 2; // Default 2km
          try {
            const address = typeof assignment.address === 'string' 
              ? JSON.parse(assignment.address) 
              : assignment.address;
            
            if (address && address.lat && address.lng) {
              // Calculate distance from store to delivery location
              // For now, use a simple calculation (can be enhanced with Google Maps API)
              const { rows: storeRows } = await query(
                `SELECT center_lat, center_lng FROM settings WHERE id = 1`
              );
              if (storeRows[0] && storeRows[0].center_lat && storeRows[0].center_lng) {
                const storeLat = parseFloat(storeRows[0].center_lat);
                const storeLng = parseFloat(storeRows[0].center_lng);
                const deliveryLat = parseFloat(address.lat);
                const deliveryLng = parseFloat(address.lng);
                
                // Haversine formula for distance
                const R = 6371; // Earth's radius in km
                const dLat = (deliveryLat - storeLat) * Math.PI / 180;
                const dLng = (deliveryLng - storeLng) * Math.PI / 180;
                const a = Math.sin(dLat / 2) * Math.sin(dLat / 2) +
                         Math.cos(storeLat * Math.PI / 180) * Math.cos(deliveryLat * Math.PI / 180) *
                         Math.sin(dLng / 2) * Math.sin(dLng / 2);
                const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
                distanceKm = R * c;
              }
            }
          } catch (e) {
            logger.warn('distance_calculation_failed', { error: e.message, orderId });
          }
          
          // Calculate earnings using advanced formula
          const earnings = await calculateDeliveryEarnings(
            {
              total_amount: parseFloat(assignment.total_amount),
              created_at: assignment.created_at,
            },
            {
              delivery_partner_id: assignment.rider_user_id,
              assigned_at: assignment.assigned_at,
              updated_at: assignment.updated_at || new Date(),
              distance_km: distanceKm,
            }
          );
          
          // Record in earnings history
          await recordEarningsHistory(orderId, assignment.rider_user_id, earnings);
          
          // Update rider's total earnings
          await updateRiderEarnings(assignment.rider_user_id, earnings.total);
          
          logger.info('earnings_calculated', {
            orderId,
            riderId: assignment.rider_user_id,
            earnings: earnings.total,
            breakdown: earnings,
          });
        }
        break;

      default:
        break;
    }
  } catch (error) {
    logger.error('handle_state_actions_failed', {
      error: error.message,
      orderId,
      state,
    });
  }
}

/**
 * Get order lifecycle timeline
 */
async function getOrderTimeline(orderId) {
  try {
    // For now, return basic timeline from order status
    // In production, you'd have a separate order_history table
    const { rows: orderRows } = await query(
      `SELECT id, status, created_at, payment_mode
       FROM orders WHERE id = $1`,
      [orderId]
    );
    
    if (!orderRows[0]) {
      throw new Error('Order not found');
    }

    const order = orderRows[0];
    
    // Get assignment info
    const { rows: assignmentRows } = await query(
      `SELECT oa.assigned_at, oa.status, u.name as rider_name
       FROM order_assignments oa
       JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
       JOIN users u ON u.id = dp.user_id
       WHERE oa.order_id = $1`,
      [orderId]
    );

    const timeline = [
      {
        state: ORDER_STATES.PLACED,
        timestamp: order.created_at,
        completed: true,
      },
    ];

    // Add intermediate states based on current status
    const statusOrder = [
      ORDER_STATES.PAYMENT_PENDING,
      ORDER_STATES.PAYMENT_VERIFIED,
      ORDER_STATES.CONFIRMED,
      ORDER_STATES.PACKING_STARTED,
      ORDER_STATES.PACKED,
      ORDER_STATES.RIDER_ASSIGNED,
      ORDER_STATES.RIDER_ACCEPTED,
      ORDER_STATES.OUT_FOR_DELIVERY,
      ORDER_STATES.RIDER_NEARBY,
      ORDER_STATES.DELIVERED,
    ];

    const currentIndex = statusOrder.indexOf(order.status);
    
    for (let i = 0; i < statusOrder.length; i++) {
      const state = statusOrder[i];
      timeline.push({
        state,
        timestamp: i <= currentIndex ? order.created_at : null,
        completed: i <= currentIndex,
        current: i === currentIndex,
      });
    }

    // Add assignment timestamp if available
    if (assignmentRows[0]) {
      const assignmentIndex = timeline.findIndex(
        t => t.state === ORDER_STATES.RIDER_ASSIGNED
      );
      if (assignmentIndex !== -1) {
        timeline[assignmentIndex].timestamp = assignmentRows[0].assigned_at;
        timeline[assignmentIndex].riderName = assignmentRows[0].rider_name;
      }
    }

    return timeline;
  } catch (error) {
    logger.error('get_order_timeline_failed', {
      error: error.message,
      orderId,
    });
    throw error;
  }
}

/**
 * Get available actions for current user on order
 */
async function getOrderActions(orderId, userId, userRole) {
  try {
    const { rows } = await query(
      'SELECT status, customer_id FROM orders WHERE id = $1',
      [orderId]
    );
    
    if (!rows[0]) {
      return [];
    }

    const order = rows[0];
    const currentState = order.status;

    // Get base actions for role and state
    let actions = getAvailableActions(currentState, userRole);

    // Filter based on user permissions
    if (userRole === 'customer' && order.customer_id !== userId) {
      return [];
    }

    return actions;
  } catch (error) {
    logger.error('get_order_actions_failed', {
      error: error.message,
      orderId,
      userId,
    });
    return [];
  }
}

module.exports = {
  transitionOrderState,
  handleStateActions,
  getOrderTimeline,
  getOrderActions,
  ORDER_STATES,
};
