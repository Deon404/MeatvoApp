const { PRICING } = require('../config/businessRules');

const DEFAULT_DELIVERY_FEE = PRICING.defaultDeliveryFee;
const DEFAULT_FREE_DELIVERY_THRESHOLD = PRICING.freeDeliveryThreshold;

/**
 * Delivery charge for checkout — free when subtotal meets threshold.
 */
const resolveDeliveryCharge = (subtotal, settings = {}) => {
  const safeSubtotal = Number(subtotal) || 0;
  const fee = Number(
    settings.delivery_fee ??
      settings.deliveryFee ??
      settings.delivery_charge ??
      settings.deliveryCharge ??
      DEFAULT_DELIVERY_FEE
  );
  const threshold = Number(
    settings.free_delivery_threshold ??
      settings.freeDeliveryThreshold ??
      DEFAULT_FREE_DELIVERY_THRESHOLD
  );

  if (safeSubtotal >= threshold) return 0;
  return fee >= 0 ? fee : DEFAULT_DELIVERY_FEE;
};

module.exports = {
  DEFAULT_DELIVERY_FEE,
  DEFAULT_FREE_DELIVERY_THRESHOLD,
  resolveDeliveryCharge,
};
