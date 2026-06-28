const {
  WEIGHT_TOLERANCE_G,
  WEIGHT_ACTION,
} = require('../constants/weightReconciliation.constants');

/**
 * Reconcile actual packed weight against the ordered weight for one line item.
 * Never blocks on customer approval — operations resolve automatically.
 *
 * @param {object} params
 * @param {number} params.orderedWeightG - Weight the customer ordered (grams)
 * @param {number} params.actualWeightG - Weight measured at packing (grams)
 * @param {number} params.unitPricePerKg - Sale price per kg for refund math
 * @param {number} [params.nextCutAvailableG=0] - Grams available from the next cut
 */
const reconcileLineItemWeight = ({
  orderedWeightG,
  actualWeightG,
  unitPricePerKg,
  nextCutAvailableG = 0,
}) => {
  const ordered = Number(orderedWeightG);
  const actual = Number(actualWeightG);
  const pricePerKg = Number(unitPricePerKg);

  if (!Number.isFinite(ordered) || ordered <= 0) {
    throw new Error('orderedWeightG must be a positive number');
  }
  if (!Number.isFinite(actual) || actual < 0) {
    throw new Error('actualWeightG must be a non-negative number');
  }

  const deltaG = actual - ordered;
  const absDelta = Math.abs(deltaG);

  if (absDelta <= WEIGHT_TOLERANCE_G) {
    return {
      action: WEIGHT_ACTION.ACCEPT,
      orderedWeightG: ordered,
      actualWeightG: actual,
      deltaG,
      supplementG: 0,
      refundAmount: 0,
      requiresCustomerApproval: false,
    };
  }

  // Heavier than ordered — accept at ordered price (premium experience).
  if (deltaG > WEIGHT_TOLERANCE_G) {
    return {
      action: WEIGHT_ACTION.ACCEPT,
      orderedWeightG: ordered,
      actualWeightG: actual,
      deltaG,
      supplementG: 0,
      refundAmount: 0,
      requiresCustomerApproval: false,
    };
  }

  const shortG = Math.abs(deltaG);
  const available = Math.max(0, Number(nextCutAvailableG) || 0);

  if (available >= shortG) {
    return {
      action: WEIGHT_ACTION.SUPPLEMENT_FROM_NEXT_CUT,
      orderedWeightG: ordered,
      actualWeightG: actual,
      deltaG,
      supplementG: shortG,
      refundAmount: 0,
      requiresCustomerApproval: false,
    };
  }

  const refundG = shortG - available;
  const refundAmount =
    Number.isFinite(pricePerKg) && pricePerKg > 0
      ? Math.round((refundG / 1000) * pricePerKg * 100) / 100
      : 0;

  return {
    action: WEIGHT_ACTION.AUTO_REFUND,
    orderedWeightG: ordered,
    actualWeightG: actual,
    deltaG,
    supplementG: available,
    refundAmount,
    requiresCustomerApproval: false,
  };
};

module.exports = {
  reconcileLineItemWeight,
};
