/**
 * Customer-facing order statuses — only four visible steps:
 *   Confirmed → Preparing → Out for Delivery → Delivered
 *
 * Internal states (QC, Ready, Dispatch Queue, Batch Ready, rider assignment, etc.)
 * are never exposed to customers.
 */

const CUSTOMER_ORDER_STATUS = {
  CONFIRMED: 'CONFIRMED',
  PREPARING: 'PREPARING',
  OUT_FOR_DELIVERY: 'OUT_FOR_DELIVERY',
  DELIVERED: 'DELIVERED',
  DELIVERY_ATTEMPTED: 'DELIVERY_ATTEMPTED',
  CANCELLED: 'CANCELLED',
};

const CUSTOMER_STATUS_LABELS = {
  [CUSTOMER_ORDER_STATUS.CONFIRMED]: 'Confirmed',
  [CUSTOMER_ORDER_STATUS.PREPARING]: 'Preparing',
  [CUSTOMER_ORDER_STATUS.OUT_FOR_DELIVERY]: 'Out for Delivery',
  [CUSTOMER_ORDER_STATUS.DELIVERED]: 'Delivered',
  [CUSTOMER_ORDER_STATUS.DELIVERY_ATTEMPTED]: 'Delivery Attempted',
  [CUSTOMER_ORDER_STATUS.CANCELLED]: 'Cancelled',
};

/** Internal statuses that collapse to "Preparing" for customers. */
const PREPARING_INTERNAL_STATUSES = new Set([
  'PACKING_STARTED',
  'PACKED',
  'QC',
  'READY',
  'DISPATCH_QUEUE',
  'BATCH_READY',
  'RIDER_ASSIGNED',
  'RIDER_ACCEPTED',
  'RIDER_REJECTED',
]);

/** Internal statuses that collapse to "Out for Delivery" for customers. */
const OUT_FOR_DELIVERY_INTERNAL_STATUSES = new Set([
  'OUT_FOR_DELIVERY',
  'PICKED_UP',
  'ON_THE_WAY',
  'ON_WAY',
  'RIDER_NEARBY',
]);

const toCustomerOrderStatus = (internalStatus) => {
  const raw = String(internalStatus || '').trim().toUpperCase();
  if (!raw) return CUSTOMER_ORDER_STATUS.CONFIRMED;

  if (raw === 'DELIVERED') return CUSTOMER_ORDER_STATUS.DELIVERED;
  if (raw === 'FAILED_DELIVERY') return CUSTOMER_ORDER_STATUS.DELIVERY_ATTEMPTED;
  if (raw === 'CANCELLED' || raw === 'REFUNDED') {
    return CUSTOMER_ORDER_STATUS.CANCELLED;
  }
  if (PREPARING_INTERNAL_STATUSES.has(raw)) {
    return CUSTOMER_ORDER_STATUS.PREPARING;
  }
  if (OUT_FOR_DELIVERY_INTERNAL_STATUSES.has(raw)) {
    return CUSTOMER_ORDER_STATUS.OUT_FOR_DELIVERY;
  }

  // PLACED, PAYMENT_PENDING, PAYMENT_VERIFIED, CONFIRMED, FAILED, etc.
  return CUSTOMER_ORDER_STATUS.CONFIRMED;
};

const getCustomerStatusLabel = (internalStatus) => {
  const customerStatus = toCustomerOrderStatus(internalStatus);
  return CUSTOMER_STATUS_LABELS[customerStatus] || 'Confirmed';
};

/**
 * Attach customerStatus + customerStatusLabel to an order object for API responses.
 */
const withCustomerStatus = (order) => {
  if (!order || typeof order !== 'object') return order;
  const customerStatus = toCustomerOrderStatus(order.status);
  return {
    ...order,
    customerStatus,
    customerStatusLabel: CUSTOMER_STATUS_LABELS[customerStatus],
  };
};

module.exports = {
  CUSTOMER_ORDER_STATUS,
  CUSTOMER_STATUS_LABELS,
  PREPARING_INTERNAL_STATUSES,
  OUT_FOR_DELIVERY_INTERNAL_STATUSES,
  toCustomerOrderStatus,
  getCustomerStatusLabel,
  withCustomerStatus,
};
