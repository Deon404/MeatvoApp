/**
 * Lifecycle Compatibility Bridge
 * Helps migrate from old order system to new enhanced lifecycle system
 */

const { ORDER_STATES } = require('./enhancedOrderStateMachine');

/**
 * Map old status names to new enhanced states
 */
const OLD_TO_NEW_STATE_MAP = {
  'PLACED': ORDER_STATES.PLACED,
  'CONFIRMED': ORDER_STATES.CONFIRMED,
  'PACKED': ORDER_STATES.PACKED,
  'OUT_FOR_DELIVERY': ORDER_STATES.OUT_FOR_DELIVERY,
  'DELIVERED': ORDER_STATES.DELIVERED,
  'CANCELLED': ORDER_STATES.CANCELLED,
};

/**
 * Map new states back to old for backward compatibility
 */
const NEW_TO_OLD_STATE_MAP = {
  [ORDER_STATES.PLACED]: 'PLACED',
  [ORDER_STATES.PAYMENT_PENDING]: 'PLACED', // Show as PLACED to old clients
  [ORDER_STATES.PAYMENT_VERIFIED]: 'CONFIRMED',
  [ORDER_STATES.CONFIRMED]: 'CONFIRMED',
  [ORDER_STATES.PACKING_STARTED]: 'CONFIRMED', // Show as CONFIRMED to old clients
  [ORDER_STATES.PACKED]: 'PACKED',
  [ORDER_STATES.RIDER_ASSIGNED]: 'PACKED', // Show as PACKED to old clients
  [ORDER_STATES.RIDER_ACCEPTED]: 'PACKED',
  [ORDER_STATES.RIDER_REJECTED]: 'PACKED',
  [ORDER_STATES.OUT_FOR_DELIVERY]: 'OUT_FOR_DELIVERY',
  [ORDER_STATES.RIDER_NEARBY]: 'OUT_FOR_DELIVERY', // Show as OUT_FOR_DELIVERY to old clients
  [ORDER_STATES.DELIVERED]: 'DELIVERED',
  [ORDER_STATES.CANCELLED]: 'CANCELLED',
  [ORDER_STATES.REFUNDED]: 'CANCELLED',
};

/**
 * Convert old state to new enhanced state
 */
function mapOldStateToNew(oldState) {
  return OLD_TO_NEW_STATE_MAP[oldState] || oldState;
}

/**
 * Convert new enhanced state to old state for backward compatibility
 */
function mapNewStateToOld(newState) {
  return NEW_TO_OLD_STATE_MAP[newState] || newState;
}

/**
 * Check if state is an intermediate enhanced state
 */
function isIntermediateState(state) {
  const intermediateStates = [
    ORDER_STATES.PAYMENT_PENDING,
    ORDER_STATES.PAYMENT_VERIFIED,
    ORDER_STATES.PACKING_STARTED,
    ORDER_STATES.RIDER_ASSIGNED,
    ORDER_STATES.RIDER_ACCEPTED,
    ORDER_STATES.RIDER_REJECTED,
    ORDER_STATES.RIDER_NEARBY,
  ];
  return intermediateStates.includes(state);
}

/**
 * Get user-friendly display state
 */
function getDisplayState(state, userRole = 'customer') {
  const displayMap = {
    [ORDER_STATES.PLACED]: 'Order Placed',
    [ORDER_STATES.PAYMENT_PENDING]: 'Payment Pending',
    [ORDER_STATES.PAYMENT_VERIFIED]: 'Payment Verified',
    [ORDER_STATES.CONFIRMED]: 'Order Confirmed',
    [ORDER_STATES.PACKING_STARTED]: 'Preparing Your Order',
    [ORDER_STATES.PACKED]: 'Ready for Pickup',
    [ORDER_STATES.RIDER_ASSIGNED]: 'Delivery Partner Assigned',
    [ORDER_STATES.RIDER_ACCEPTED]: 'Delivery Partner On the Way',
    [ORDER_STATES.RIDER_REJECTED]: 'Finding Delivery Partner',
    [ORDER_STATES.OUT_FOR_DELIVERY]: 'Out for Delivery',
    [ORDER_STATES.RIDER_NEARBY]: 'Arriving Soon',
    [ORDER_STATES.DELIVERED]: 'Delivered',
    [ORDER_STATES.CANCELLED]: 'Cancelled',
    [ORDER_STATES.REFUNDED]: 'Refunded',
  };

  return displayMap[state] || state;
}

/**
 * Transform order object for backward compatibility
 */
function transformOrderForOldClient(order) {
  if (!order) return null;

  return {
    ...order,
    status: mapNewStateToOld(order.status),
    // Add enhanced state info for clients that support it
    enhancedStatus: order.status,
    isIntermediateState: isIntermediateState(order.status),
    displayStatus: getDisplayState(order.status),
  };
}

/**
 * Transform orders array for backward compatibility
 */
function transformOrdersForOldClient(orders) {
  if (!Array.isArray(orders)) return orders;
  return orders.map(transformOrderForOldClient);
}

/**
 * Check if client supports enhanced states
 */
function supportsEnhancedStates(req) {
  // Check for header or query param indicating enhanced support
  return (
    req.headers['x-enhanced-states'] === 'true' ||
    req.query.enhanced === 'true'
  );
}

module.exports = {
  mapOldStateToNew,
  mapNewStateToOld,
  isIntermediateState,
  getDisplayState,
  transformOrderForOldClient,
  transformOrdersForOldClient,
  supportsEnhancedStates,
  OLD_TO_NEW_STATE_MAP,
  NEW_TO_OLD_STATE_MAP,
};
