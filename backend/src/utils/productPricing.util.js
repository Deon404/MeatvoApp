/**
 * Shared product unit-price logic — matches products.controller formatProduct().
 */

const parseWeightVariants = (wv) => {
  if (typeof wv === 'string') {
    try {
      return JSON.parse(wv);
    } catch {
      return [500];
    }
  }
  return Array.isArray(wv) && wv.length ? wv : [500];
};

const defaultWeightGrams = (wv) => parseWeightVariants(wv)[0] || 500;

/**
 * Sale price for one unit at the given weight (grams).
 * Uses base_price_per_kg when present, otherwise falls back to products.price as ₹/kg.
 */
const resolveUnitSalePrice = (product, weightGrams = null) => {
  if (!product) return 0;
  const basePrice = Number(product.base_price_per_kg || product.price || 0);
  const weight = weightGrams || defaultWeightGrams(product.weight_variants);
  return Math.round(basePrice * (weight / 1000) * 100) / 100;
};

module.exports = {
  parseWeightVariants,
  defaultWeightGrams,
  resolveUnitSalePrice,
};
