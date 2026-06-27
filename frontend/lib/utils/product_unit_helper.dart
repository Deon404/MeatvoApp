/// Normalizes product units (piece vs weight) for display and variant parsing.
abstract final class ProductUnitHelper {
  static bool isPieceUnit(String? rawUnit) {
    final unit = (rawUnit ?? '').trim().toLowerCase();
    if (unit.isEmpty) return false;
    return unit.contains('piece') ||
        unit == 'pc' ||
        unit == 'pcs' ||
        unit.contains('pack') ||
        unit.contains('dozen');
  }

  static String normalizeDisplayUnit(String? rawUnit) {
    if (isPieceUnit(rawUnit)) return 'piece';
    final unit = (rawUnit ?? '').trim().toLowerCase();
    if (unit.contains('kg') || unit.contains('gm') || unit == 'g') {
      return 'kg';
    }
    return unit.isEmpty ? 'piece' : unit;
  }

  /// Default meat weight options — should not drive piece-based products (e.g. eggs).
  static bool isDefaultMeatWeightVariants(List<dynamic> weights) {
    final normalized = weights
        .map((w) => w is num ? w.toInt() : int.tryParse('$w') ?? 0)
        .toList()
      ..sort();
    return normalized.length == 3 &&
        normalized[0] == 250 &&
        normalized[1] == 500 &&
        normalized[2] == 1000;
  }

  static String pieceVariantLabel(int count) =>
      count == 1 ? '1 piece' : '$count pieces';
}
