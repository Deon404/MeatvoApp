const { parseWeightVariants, defaultWeightGrams } = require('./productPricing.util');

const PIECE_UNITS = new Set(['piece', 'pieces', 'pcs', 'pack', 'unit', 'dozen']);

/**
 * Weight-based SKUs are priced/sold by gram weight (meat cuts).
 * Piece/unit SKUs skip packing weight capture.
 */
const isWeightBasedProduct = (product) => {
  if (!product) return false;
  const unit = String(product.unit || '').trim().toLowerCase();
  if (unit && PIECE_UNITS.has(unit)) return false;

  const variants = parseWeightVariants(product.weight_variants);
  if (variants.length > 0 && Number(variants[0]) > 0) return true;

  return Number(product.base_price_per_kg) > 0;
};

const orderedWeightGramsForLine = (product, quantity) => {
  const perUnit = defaultWeightGrams(product?.weight_variants);
  return perUnit * Math.max(1, Number(quantity) || 1);
};

const nextCutAvailableGrams = (product) => {
  const defaultGrams = defaultWeightGrams(product?.weight_variants);
  const stockUnits = Math.max(0, Number(product?.stock) || 0);
  return stockUnits * defaultGrams;
};

const supplementStockDeductionUnits = (supplementG, product) => {
  const defaultGrams = defaultWeightGrams(product?.weight_variants);
  if (defaultGrams <= 0 || supplementG <= 0) return 0;
  return Math.ceil(supplementG / defaultGrams);
};

module.exports = {
  isWeightBasedProduct,
  orderedWeightGramsForLine,
  nextCutAvailableGrams,
  supplementStockDeductionUnits,
};
