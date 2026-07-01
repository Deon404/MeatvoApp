/**
 * Enhanced Order State Machine
 * Defines complete order lifecycle with intermediate states and transition rules
 */

const ORDER_STATES = {
  PLACED: 'PLACED',
  PAYMENT_PENDING: 'PAYMENT_PENDING',
  PAYMENT_VERIFIED: 'PAYMENT_VERIFIED',
  CONFIRMED: 'CONFIRMED',
  PACKING_STARTED: 'PACKING_STARTED',
  PACKED: 'PACKED',
  RIDER_ASSIGNED: 'RIDER_ASSIGNED',
  RIDER_ACCEPTED: 'RIDER_ACCEPTED',
  RIDER_REJECTED: 'RIDER_REJECTED',
  OUT_FOR_DELIVERY: 'OUT_FOR_DELIVERY',
  RIDER_NEARBY: 'RIDER_NEARBY',
  DELIVERED: 'DELIVERED',
  FAILED_DELIVERY: 'FAILED_DELIVERY',
  CANCELLED: 'CANCELLED',
  REFUNDED: 'REFUNDED',
};

// Define valid transitions between states
const STATE_TRANSITIONS = {
  [ORDER_STATES.PLACED]: [
    ORDER_STATES.PAYMENT_PENDING,
    ORDER_STATES.CONFIRMED,
    ORDER_STATES.CANCELLED,
  ],
  [ORDER_STATES.PAYMENT_PENDING]: [
    ORDER_STATES.PAYMENT_VERIFIED,
    ORDER_STATES.CANCELLED,
  ],
  [ORDER_STATES.PAYMENT_VERIFIED]: [ORDER_STATES.CONFIRMED],
  [ORDER_STATES.CONFIRMED]: [
    ORDER_STATES.PACKING_STARTED,
    ORDER_STATES.PACKED,
    ORDER_STATES.CANCELLED,
  ],
  [ORDER_STATES.PACKING_STARTED]: [ORDER_STATES.PACKED, ORDER_STATES.CANCELLED],
  [ORDER_STATES.PACKED]: [
    ORDER_STATES.RIDER_ASSIGNED,
    ORDER_STATES.OUT_FOR_DELIVERY,
    ORDER_STATES.CANCELLED,
  ],
  [ORDER_STATES.RIDER_ASSIGNED]: [
    ORDER_STATES.RIDER_ACCEPTED,
    ORDER_STATES.RIDER_REJECTED,
    ORDER_STATES.PACKED, // Reassignment fallback
  ],
  [ORDER_STATES.RIDER_REJECTED]: [ORDER_STATES.PACKED], // Back to packed for reassignment
  [ORDER_STATES.RIDER_ACCEPTED]: [ORDER_STATES.OUT_FOR_DELIVERY],
  [ORDER_STATES.OUT_FOR_DELIVERY]: [
    ORDER_STATES.RIDER_NEARBY,
    ORDER_STATES.DELIVERED,
    ORDER_STATES.FAILED_DELIVERY,
  ],
  [ORDER_STATES.RIDER_NEARBY]: [
    ORDER_STATES.DELIVERED,
    ORDER_STATES.FAILED_DELIVERY,
  ],
  [ORDER_STATES.DELIVERED]: [ORDER_STATES.REFUNDED], // In case of issues
  [ORDER_STATES.FAILED_DELIVERY]: [
    ORDER_STATES.PACKED,
    ORDER_STATES.REFUNDED,
    ORDER_STATES.CANCELLED,
  ],
  [ORDER_STATES.CANCELLED]: [ORDER_STATES.REFUNDED],
  [ORDER_STATES.REFUNDED]: [],
};

// Define who can trigger each state transition
const TRANSITION_ACTORS = {
  [ORDER_STATES.PLACED]: ['customer', 'system'],
  [ORDER_STATES.PAYMENT_PENDING]: ['system'],
  [ORDER_STATES.PAYMENT_VERIFIED]: ['admin', 'system'],
  [ORDER_STATES.CONFIRMED]: ['admin', 'staff'],
  [ORDER_STATES.PACKING_STARTED]: ['admin', 'staff'],
  [ORDER_STATES.PACKED]: ['admin', 'staff'],
  [ORDER_STATES.RIDER_ASSIGNED]: ['admin', 'system'],
  [ORDER_STATES.RIDER_ACCEPTED]: ['rider'],
  [ORDER_STATES.RIDER_REJECTED]: ['rider'],
  [ORDER_STATES.OUT_FOR_DELIVERY]: ['rider', 'admin', 'staff'],
  [ORDER_STATES.RIDER_NEARBY]: ['system', 'admin'],
  [ORDER_STATES.DELIVERED]: ['rider', 'admin', 'staff'],
  [ORDER_STATES.FAILED_DELIVERY]: ['rider', 'admin'],
  [ORDER_STATES.CANCELLED]: ['customer', 'admin', 'staff'],
  [ORDER_STATES.REFUNDED]: ['admin'],
};

// Define notifications for each state
const STATE_NOTIFICATIONS = {
  [ORDER_STATES.PLACED]: {
    customer: {
      title: 'Order Placed Successfully',
      body: 'Your order #{orderId} has been placed successfully',
      priority: 'normal',
    },
    admin: {
      title: 'New Order Received',
      body: 'New order #{orderId} from {customerPhone}',
      priority: 'high',
    },
  },
  [ORDER_STATES.PAYMENT_PENDING]: {
    customer: {
      title: 'Payment Verification',
      body: 'Your payment is being verified',
      priority: 'normal',
    },
    admin: {
      title: 'Verify Payment',
      body: 'Verify payment for order #{orderId}',
      priority: 'high',
    },
  },
  [ORDER_STATES.PAYMENT_VERIFIED]: {
    customer: {
      title: 'Payment Confirmed',
      body: 'Your payment has been verified',
      priority: 'normal',
    },
    admin: {
      title: 'Payment Verified',
      body: 'Payment verified for order #{orderId}',
      priority: 'normal',
    },
  },
  [ORDER_STATES.CONFIRMED]: {
    customer: {
      title: 'Order Confirmed',
      body: 'Your order has been confirmed and will be prepared soon',
      priority: 'high',
    },
    admin: {
      title: 'Order Confirmed',
      body: 'Order #{orderId} confirmed, ready for packing',
      priority: 'normal',
    },
    staff: {
      title: 'New Kitchen Order',
      body: 'Order #{orderId} is ready to prepare',
      priority: 'high',
    },
  },
  [ORDER_STATES.PACKING_STARTED]: {
    customer: {
      title: 'Preparing Your Order',
      body: 'Your order is being prepared',
      priority: 'normal',
    },
  },
  [ORDER_STATES.PACKED]: {
    customer: {
      title: 'Preparing Your Order',
      body: 'Your order is being prepared',
      priority: 'normal',
    },
    admin: {
      title: 'Order Packed',
      body: 'Order #{orderId} packed, assign rider',
      priority: 'normal',
    },
  },
  [ORDER_STATES.RIDER_ASSIGNED]: {
    customer: {
      title: 'Preparing Your Order',
      body: 'Your order is being prepared',
      priority: 'high',
    },
    rider: {
      title: 'New Order Assigned',
      body: 'New order for delivery to {customerAddress}',
      priority: 'high',
    },
    admin: {
      title: 'Rider Assigned',
      body: '{riderName} assigned to order #{orderId}',
      priority: 'normal',
    },
  },
  [ORDER_STATES.RIDER_ACCEPTED]: {
    customer: {
      title: 'Preparing Your Order',
      body: 'Your order is being prepared',
      priority: 'high',
    },
    admin: {
      title: 'Rider Accepted',
      body: '{riderName} accepted order #{orderId}',
      priority: 'normal',
    },
  },
  [ORDER_STATES.RIDER_REJECTED]: {
    admin: {
      title: 'Rider Rejected',
      body: '{riderName} rejected order #{orderId}',
      priority: 'high',
    },
  },
  [ORDER_STATES.OUT_FOR_DELIVERY]: {
    customer: {
      title: 'Out for Delivery',
      body: 'Your order is on the way',
      priority: 'high',
    },
    admin: {
      title: 'Order In Transit',
      body: 'Order #{orderId} out for delivery',
      priority: 'normal',
    },
  },
  [ORDER_STATES.RIDER_NEARBY]: {
    customer: {
      title: 'Out for Delivery',
      body: 'Your order is almost there',
      priority: 'urgent',
    },
  },
  [ORDER_STATES.DELIVERED]: {
    customer: {
      title: 'Order Delivered',
      body: 'Your order has been delivered successfully. Rate your experience!',
      priority: 'high',
    },
    rider: {
      title: 'Delivery Completed',
      body: 'Order #{orderId} delivered successfully. Earnings updated.',
      priority: 'normal',
    },
    admin: {
      title: 'Order Completed',
      body: 'Order #{orderId} delivered by {riderName}',
      priority: 'normal',
    },
  },
  [ORDER_STATES.CANCELLED]: {
    customer: {
      title: 'Order Cancelled',
      body: 'Your order has been cancelled',
      priority: 'normal',
    },
    rider: {
      title: 'Order Cancelled',
      body: 'Order #{orderId} has been cancelled',
      priority: 'normal',
    },
    admin: {
      title: 'Order Cancelled',
      body: 'Order #{orderId} cancelled',
      priority: 'normal',
    },
  },
};

// Define available actions for each role at each state
const STATE_ACTIONS = {
  [ORDER_STATES.PLACED]: {
    customer: ['cancel_order'],
    admin: ['verify_payment', 'confirm_order', 'cancel_order'],
    rider: [],
  },
  [ORDER_STATES.PAYMENT_PENDING]: {
    customer: [],
    admin: ['verify_payment', 'cancel_order'],
    rider: [],
  },
  [ORDER_STATES.CONFIRMED]: {
    customer: ['cancel_order'],
    admin: ['start_packing', 'cancel_order'],
    staff: ['start_packing'],
    rider: [],
  },
  [ORDER_STATES.PACKING_STARTED]: {
    customer: [],
    admin: ['mark_packed', 'cancel_order'],
    staff: ['mark_packed'],
    rider: [],
  },
  [ORDER_STATES.PACKED]: {
    customer: [],
    admin: ['assign_rider', 'auto_assign', 'cancel_order'],
    rider: [],
  },
  [ORDER_STATES.RIDER_ASSIGNED]: {
    customer: ['call_rider', 'track_rider'],
    admin: ['reassign_rider', 'cancel_assignment'],
    rider: ['accept_order', 'reject_order'],
  },
  [ORDER_STATES.RIDER_ACCEPTED]: {
    customer: ['call_rider', 'track_rider'],
    admin: ['monitor'],
    rider: ['start_delivery', 'reject_order'],
  },
  [ORDER_STATES.OUT_FOR_DELIVERY]: {
    customer: ['track_live', 'call_rider'],
    admin: ['monitor'],
    rider: ['update_location', 'mark_nearby', 'mark_delivered'],
  },
  [ORDER_STATES.RIDER_NEARBY]: {
    customer: ['call_rider', 'track_live'],
    admin: ['monitor'],
    rider: ['mark_delivered'],
  },
  [ORDER_STATES.DELIVERED]: {
    customer: ['rate_order', 'report_issue'],
    admin: ['view_details'],
    rider: ['next_order'],
  },
  [ORDER_STATES.FAILED_DELIVERY]: {
    customer: [],
    admin: ['resolve_failed_delivery', 'redeliver', 'refund', 'discard'],
    rider: ['confirm_return_to_store'],
  },
  [ORDER_STATES.CANCELLED]: {
    customer: [],
    admin: ['process_refund'],
    rider: [],
  },
};

// Check if transition is valid
function canTransition(fromState, toState) {
  if (!fromState || !toState) return false;
  if (fromState === toState) return true;
  
  const validTransitions = STATE_TRANSITIONS[fromState];
  return validTransitions ? validTransitions.includes(toState) : false;
}

// Get valid transitions from a state
function getValidTransitions(fromState) {
  return STATE_TRANSITIONS[fromState] || [];
}

// Check if actor can trigger a state
function canActorTriggerState(state, actor) {
  const validActors = TRANSITION_ACTORS[state];
  return validActors ? validActors.includes(actor) : false;
}

// Get notifications for a state
function getStateNotifications(state, context = {}) {
  const notifications = STATE_NOTIFICATIONS[state];
  if (!notifications) return {};
  
  const result = {};
  for (const [role, notification] of Object.entries(notifications)) {
    result[role] = {
      ...notification,
      title: interpolate(notification.title, context),
      body: interpolate(notification.body, context),
    };
  }
  return result;
}

// Get available actions for a role at a state
function getAvailableActions(state, role) {
  return STATE_ACTIONS[state]?.[role] || [];
}

// Helper to interpolate variables in strings
function interpolate(str, context) {
  return str.replace(/\{(\w+)\}/g, (match, key) => context[key] || match);
}

// Get display info for a state
function getStateDisplayInfo(state) {
  const displayMap = {
    [ORDER_STATES.PLACED]: { label: 'Placed', color: 'blue', icon: 'shopping-cart' },
    [ORDER_STATES.PAYMENT_PENDING]: { label: 'Payment Pending', color: 'orange', icon: 'clock' },
    [ORDER_STATES.PAYMENT_VERIFIED]: { label: 'Payment Verified', color: 'green', icon: 'check-circle' },
    [ORDER_STATES.CONFIRMED]: { label: 'Confirmed', color: 'green', icon: 'check' },
    [ORDER_STATES.PACKING_STARTED]: { label: 'Preparing', color: 'blue', icon: 'box' },
    [ORDER_STATES.PACKED]: { label: 'Packed', color: 'blue', icon: 'package' },
    [ORDER_STATES.RIDER_ASSIGNED]: { label: 'Rider Assigned', color: 'purple', icon: 'user' },
    [ORDER_STATES.RIDER_ACCEPTED]: { label: 'Rider Accepted', color: 'purple', icon: 'user-check' },
    [ORDER_STATES.OUT_FOR_DELIVERY]: { label: 'Out for Delivery', color: 'indigo', icon: 'truck' },
    [ORDER_STATES.RIDER_NEARBY]: { label: 'Arriving Soon', color: 'yellow', icon: 'map-pin' },
    [ORDER_STATES.DELIVERED]: { label: 'Delivered', color: 'green', icon: 'check-circle' },
    [ORDER_STATES.FAILED_DELIVERY]: {
      label: 'Failed Delivery',
      color: 'orange',
      icon: 'alert-triangle',
    },
    [ORDER_STATES.CANCELLED]: { label: 'Cancelled', color: 'red', icon: 'x-circle' },
    [ORDER_STATES.REFUNDED]: { label: 'Refunded', color: 'gray', icon: 'dollar-sign' },
  };
  return displayMap[state] || { label: state, color: 'gray', icon: 'circle' };
}

module.exports = {
  ORDER_STATES,
  STATE_TRANSITIONS,
  TRANSITION_ACTORS,
  STATE_NOTIFICATIONS,
  STATE_ACTIONS,
  canTransition,
  getValidTransitions,
  canActorTriggerState,
  getStateNotifications,
  getAvailableActions,
  getStateDisplayInfo,
};
