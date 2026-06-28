/**
 * Automatic weight reconciliation — no customer approval step.
 * Thresholds: backend/src/config/businessRules.js (WEIGHT)
 */

const { WEIGHT } = require('../config/businessRules');

const WEIGHT_TOLERANCE_G = WEIGHT.toleranceG;

const WEIGHT_ACTION = {
  ACCEPT: 'ACCEPT',
  SUPPLEMENT_FROM_NEXT_CUT: 'SUPPLEMENT_FROM_NEXT_CUT',
  AUTO_REFUND: 'AUTO_REFUND',
};

const WEIGHT_RECONCILIATION_STATUS = {
  PENDING: 'PENDING',
  COMPLETED: 'COMPLETED',
  NOT_REQUIRED: 'NOT_REQUIRED',
};

const PARTIAL_REFUND_REASON = 'weight_reconciliation';
const FAILED_DELIVERY_REFUND_REASON = 'failed_delivery';
const PARTIAL_REFUND_STATUS = {
  PENDING: 'PENDING',
  RECORDED: 'RECORDED',
  SUBMITTED: 'SUBMITTED',
  SUCCESS: 'SUCCESS',
  FAILED: 'FAILED',
};

module.exports = {
  WEIGHT_TOLERANCE_G,
  WEIGHT_ACTION,
  WEIGHT_RECONCILIATION_STATUS,
  PARTIAL_REFUND_REASON,
  FAILED_DELIVERY_REFUND_REASON,
  PARTIAL_REFUND_STATUS,
};
