/**
 * Unified Order Status System
 * Consolidates legacy and enhanced status systems
 */

// Primary status enum (enhanced system)
const ORDER_STATUS = Object.freeze({
  // Creation & Payment
  PLACED: 'PLACED',
  PAYMENT_PENDING: 'PAYMENT_PENDING',
  PAYMENT_VERIFIED: 'PAYMENT_VERIFIED',
  CONFIRMED: 'CONFIRMED',
  
  // Preparation
  PACKING_STARTED: 'PACKING_STARTED',
  PACKED: 'PACKED',
  
  // Assignment & Acceptance
  RIDER_ASSIGNED: 'RIDER_ASSIGNED',
  RIDER_ACCEPTED: 'RIDER_ACCEPTED',
  RIDER_REJECTED: 'RIDER_REJECTED',
  
  // Delivery
  OUT_FOR_DELIVERY: 'OUT_FOR_DELIVERY',
  PICKED_UP: 'PICKED_UP',  // Legacy - maps to OUT_FOR_DELIVERY
  ON_THE_WAY: 'ON_THE_WAY', // Legacy - maps to OUT_FOR_DELIVERY
  RIDER_NEARBY: 'RIDER_NEARBY',
  
  // Completion
  DELIVERED: 'DELIVERED',
  
  // Failures
  CANCELLED: 'CANCELLED',
  REFUNDED: 'REFUNDED',
  FAILED: 'FAILED',
});

// Legacy status migration map (only collapse deprecated aliases)
const LEGACY_STATUS_MIGRATION = Object.freeze({
  ON_WAY: 'ON_THE_WAY',
});

// Normalize legacy statuses to new system
const normalizeStatus = (status) => {
  if (!status) return null;
  const normalized = String(status).trim().toUpperCase();
  return LEGACY_STATUS_MIGRATION[normalized] || normalized;
};

// Unified status transitions (using enhanced system)
const ORDER_STATUS_TRANSITIONS = Object.freeze({
  PLACED: new Set(['PAYMENT_PENDING', 'CONFIRMED', 'CANCELLED']),
  PAYMENT_PENDING: new Set(['PAYMENT_VERIFIED', 'CANCELLED']),
  PAYMENT_VERIFIED: new Set(['CONFIRMED']),
  CONFIRMED: new Set(['PACKING_STARTED', 'PACKED', 'CANCELLED']),
  PACKING_STARTED: new Set(['PACKED', 'CANCELLED']),
  PACKED: new Set(['RIDER_ASSIGNED', 'OUT_FOR_DELIVERY']),
  RIDER_ASSIGNED: new Set(['RIDER_ACCEPTED', 'RIDER_REJECTED', 'PACKED']),
  RIDER_REJECTED: new Set(['PACKED']),
  RIDER_ACCEPTED: new Set(['OUT_FOR_DELIVERY']),
  OUT_FOR_DELIVERY: new Set(['PICKED_UP', 'ON_THE_WAY', 'RIDER_NEARBY', 'DELIVERED']),
  PICKED_UP: new Set(['ON_THE_WAY', 'RIDER_NEARBY', 'DELIVERED']),
  ON_THE_WAY: new Set(['RIDER_NEARBY', 'DELIVERED']),
  RIDER_NEARBY: new Set(['DELIVERED']),
  DELIVERED: new Set(['REFUNDED']),
  CANCELLED: new Set(['REFUNDED']),
  REFUNDED: new Set([]),
  FAILED: new Set(['REFUNDED']),
});

// Legacy delivery status transitions (deprecated - use ORDER_STATUS_TRANSITIONS)
const DELIVERY_STATUS_TRANSITIONS = ORDER_STATUS_TRANSITIONS;

const canTransition = (transitions, fromStatus, toStatus) => {
  if (!fromStatus || !toStatus) return false;
  
  // Normalize statuses
  const normalizedFrom = normalizeStatus(fromStatus);
  const normalizedTo = normalizeStatus(toStatus);
  
  if (normalizedFrom === normalizedTo) return true;
  return transitions[normalizedFrom]?.has(normalizedTo) || false;
};

// Assignment status mapping (for order_assignments table)
const ORDER_TO_ASSIGNMENT_STATUS = Object.freeze({
  RIDER_ASSIGNED: 'ASSIGNED',
  RIDER_ACCEPTED: 'ACCEPTED',
  OUT_FOR_DELIVERY: 'ACCEPTED',
  PICKED_UP: 'PICKED',
  ON_THE_WAY: 'PICKED',
  RIDER_NEARBY: 'PICKED',
  DELIVERED: 'DELIVERED',
  CANCELLED: 'CANCELLED',
  RIDER_REJECTED: 'CANCELLED',
});

const getAssignmentStatus = (orderStatus) => {
  const normalized = normalizeStatus(orderStatus);
  return ORDER_TO_ASSIGNMENT_STATUS[normalized] || 'ASSIGNED';
};

module.exports = {
  ORDER_STATUS,
  ORDER_STATUS_TRANSITIONS,
  DELIVERY_STATUS_TRANSITIONS,
  LEGACY_STATUS_MIGRATION,
  normalizeStatus,
  canTransition,
  getAssignmentStatus,
  ORDER_TO_ASSIGNMENT_STATUS,
};
