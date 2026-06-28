/** Fixed rider failure reasons — single-store MVP. */
const FAILED_DELIVERY_REASONS = Object.freeze({
  CUSTOMER_UNREACHABLE: 'CUSTOMER_UNREACHABLE',
  WRONG_ADDRESS: 'WRONG_ADDRESS',
  CUSTOMER_REFUSED: 'CUSTOMER_REFUSED',
});

const FAILED_DELIVERY_REASON_LABELS = Object.freeze({
  CUSTOMER_UNREACHABLE: 'Customer Unreachable',
  WRONG_ADDRESS: 'Wrong Address',
  CUSTOMER_REFUSED: 'Customer Refused',
});

/** Product condition when rider returns to store. */
const RETURN_CONDITIONS = Object.freeze({
  RESELLABLE: 'RESELLABLE',
  PARTIAL_SPOILAGE: 'PARTIAL_SPOILAGE',
  DISCARD: 'DISCARD',
});

const RETURN_CONDITION_LABELS = Object.freeze({
  RESELLABLE: 'Resellable',
  PARTIAL_SPOILAGE: 'Partial Spoilage',
  DISCARD: 'Discard',
});

/** Admin resolution — blocks reassignment while PENDING. */
const FAILED_DELIVERY_RESOLUTIONS = Object.freeze({
  PENDING: 'PENDING',
  REDELIVER: 'REDELIVER',
  REFUND: 'REFUND',
  DISCARD: 'DISCARD',
});

const ADMIN_TASK_TYPES = Object.freeze({
  FAILED_DELIVERY: 'failed_delivery',
  ASSIGNMENT_FAILED: 'assignment_failed',
});

const ADMIN_TASK_STATUS = Object.freeze({
  OPEN: 'open',
  RESOLVED: 'resolved',
});

/** Order statuses from which a rider may mark failed delivery. */
const RIDER_FAILABLE_ORDER_STATUSES = new Set([
  'OUT_FOR_DELIVERY',
  'PICKED_UP',
  'ON_THE_WAY',
  'RIDER_NEARBY',
]);

const isOrderBlockedFromAssignment = (order) => {
  if (!order) return false;
  const status = String(order.status || '').toUpperCase();
  const resolution = String(order.failed_delivery_resolution || '').toUpperCase();
  return status === 'FAILED_DELIVERY' && resolution === FAILED_DELIVERY_RESOLUTIONS.PENDING;
};

module.exports = {
  FAILED_DELIVERY_REASONS,
  FAILED_DELIVERY_REASON_LABELS,
  RETURN_CONDITIONS,
  RETURN_CONDITION_LABELS,
  FAILED_DELIVERY_RESOLUTIONS,
  ADMIN_TASK_TYPES,
  ADMIN_TASK_STATUS,
  RIDER_FAILABLE_ORDER_STATUSES,
  isOrderBlockedFromAssignment,
};
