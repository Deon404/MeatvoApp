const { WEIGHT_RECONCILIATION_STATUS } = require('../constants/weightReconciliation.constants');

const DISPATCH_ALLOWED_RECON_STATUSES = new Set([
  WEIGHT_RECONCILIATION_STATUS.COMPLETED,
  WEIGHT_RECONCILIATION_STATUS.NOT_REQUIRED,
]);

const DISPATCH_RECON_ERROR =
  'Weight reconciliation must complete before order can be dispatched';

function isWeightReconciliationCompleteForDispatch(reconStatus) {
  const normalized = String(reconStatus || '').toUpperCase();
  return DISPATCH_ALLOWED_RECON_STATUSES.has(normalized);
}

function assertWeightReconciliationForDispatch(reconStatus) {
  if (!isWeightReconciliationCompleteForDispatch(reconStatus)) {
    const err = new Error(DISPATCH_RECON_ERROR);
    err.statusCode = 400;
    throw err;
  }
}

module.exports = {
  DISPATCH_ALLOWED_RECON_STATUSES,
  DISPATCH_RECON_ERROR,
  isWeightReconciliationCompleteForDispatch,
  assertWeightReconciliationForDispatch,
};
