/**
 * Order State Middleware
 * Validates order state transitions and permissions
 */

const { query } = require('../db/postgres');
const { fail } = require('../utils/response');
const { logger } = require('../utils/logger');
const {
  canTransition,
  canActorTriggerState,
} = require('../utils/enhancedOrderStateMachine');

/**
 * Middleware to validate order state transition
 */
const validateStateTransition = async (req, res, next) => {
  try {
    const orderId = Number(req.params.id || req.body.orderId);
    const newState = req.body.newState;
    
    if (!orderId || !newState) {
      return fail(res, 400, 'Order ID and new state are required');
    }

    // Get current order state
    const { rows } = await query(
      'SELECT status FROM orders WHERE id = $1',
      [orderId]
    );

    if (!rows[0]) {
      return fail(res, 404, 'Order not found');
    }

    const currentState = rows[0].status;

    // Check if transition is valid
    if (!canTransition(currentState, newState)) {
      logger.warn('invalid_state_transition_attempted', {
        orderId,
        from: currentState,
        to: newState,
        userId: req.user?.id,
        userRole: req.user?.role,
      });
      return fail(
        res,
        400,
        `Invalid state transition from ${currentState} to ${newState}`
      );
    }

    // Attach current state to request
    req.currentOrderState = currentState;
    req.validatedOrderId = orderId;
    req.validatedNewState = newState;

    next();
  } catch (error) {
    logger.error('validate_state_transition_error', {
      error: error.message,
      orderId: req.params.id,
    });
    return fail(res, 500, 'Failed to validate state transition');
  }
};

/**
 * Middleware to check if user can trigger state
 */
const validateActorPermission = async (req, res, next) => {
  try {
    const newState = req.validatedNewState || req.body.status || req.body.state;
    const userRole = req.user?.role;

    if (!userRole) {
      return fail(res, 401, 'Authentication required');
    }

    // Map role to actor type
    let actorRole = userRole;
    if (userRole === 'delivery') {
      actorRole = 'rider';
    }

    // Check if actor can trigger this state
    if (!canActorTriggerState(newState, actorRole)) {
      logger.warn('unauthorized_state_transition_attempted', {
        userId: req.user?.id,
        userRole,
        state: newState,
      });
      return fail(
        res,
        403,
        `Your role (${userRole}) cannot trigger state ${newState}`
      );
    }

    req.actorRole = actorRole;
    next();
  } catch (error) {
    logger.error('validate_actor_permission_error', {
      error: error.message,
      userId: req.user?.id,
    });
    return fail(res, 500, 'Failed to validate permissions');
  }
};

/**
 * Middleware to validate order ownership for customers
 */
const validateOrderOwnership = async (req, res, next) => {
  try {
    const orderId = Number(req.params.id || req.body.orderId);
    const userId = req.user?.id;
    const userRole = req.user?.role;

    // Admin can access any order
    if (userRole === 'admin') {
      return next();
    }

    // Get order
    const { rows } = await query(
      'SELECT customer_id FROM orders WHERE id = $1',
      [orderId]
    );

    if (!rows[0]) {
      return fail(res, 404, 'Order not found');
    }

    // Check ownership for customers
    if (userRole === 'customer' && rows[0].customer_id !== userId) {
      logger.warn('unauthorized_order_access_attempted', {
        orderId,
        userId,
        actualCustomerId: rows[0].customer_id,
      });
      return fail(res, 403, 'You do not have access to this order');
    }

    // Check assignment for delivery partners
    if (userRole === 'delivery') {
      const { rows: assignmentRows } = await query(
        `SELECT oa.id
         FROM order_assignments oa
         JOIN delivery_partners dp ON dp.id = oa.delivery_partner_id
         WHERE oa.order_id = $1 AND dp.user_id = $2`,
        [orderId, userId]
      );

      if (!assignmentRows[0]) {
        logger.warn('unauthorized_order_access_by_rider', {
          orderId,
          riderUserId: userId,
        });
        return fail(res, 403, 'This order is not assigned to you');
      }
    }

    if (userRole !== 'admin' && userRole !== 'customer' && userRole !== 'delivery') {
      logger.warn('unauthorized_order_access_unknown_role', {
        orderId,
        userId,
        userRole,
      });
      return fail(res, 403, 'Insufficient permissions');
    }

    next();
  } catch (error) {
    logger.error('validate_order_ownership_error', {
      error: error.message,
      orderId: req.params.id,
      userId: req.user?.id,
    });
    return fail(res, 500, 'Failed to validate order ownership');
  }
};

/**
 * Middleware to validate order is in specific states
 */
const requireOrderState = (...allowedStates) => {
  return async (req, res, next) => {
    try {
      const orderId = Number(req.params.id || req.body.orderId);

      const { rows } = await query(
        'SELECT status FROM orders WHERE id = $1',
        [orderId]
      );

      if (!rows[0]) {
        return fail(res, 404, 'Order not found');
      }

      const currentState = rows[0].status;

      if (!allowedStates.includes(currentState)) {
        return fail(
          res,
          400,
          `Order must be in one of these states: ${allowedStates.join(', ')}`
        );
      }

      req.currentOrderState = currentState;
      next();
    } catch (error) {
      logger.error('require_order_state_error', {
        error: error.message,
        orderId: req.params.id,
      });
      return fail(res, 500, 'Failed to validate order state');
    }
  };
};

module.exports = {
  validateStateTransition,
  validateActorPermission,
  validateOrderOwnership,
  requireOrderState,
};
