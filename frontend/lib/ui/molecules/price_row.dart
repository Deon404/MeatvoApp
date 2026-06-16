import 'package:flutter/material.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';

/// =============================================================================
/// PriceRow — current price (bold) + strikethrough MRP + optional discount %.
/// =============================================================================
///
/// ROOT CAUSE OF PREVIOUS CRASHES
/// ------------------------------
///   • "Null check operator used on a null value"
///     → Backend returns `discount: null` (and `original_price: null`) for
///       many SKUs. The old code did `originalPrice! > price` and
///       `discountPercent! > 0`. Bangs on instance fields are NOT safe in
///       Dart — the field is technically a getter and a subclass could
///       override it to return null. Bang in a closure / between frames =
///       random NoSuchMethodError on `null`.
///
///   • "RenderFlex overflowed by N pixels"
///     → Long combos like "₹9,999  ₹12,999  25% off" overflowed narrow
///       cards on small phones / split-screen. We now wrap the whole Row
///       in `FittedBox(BoxFit.scaleDown)` so the row shrinks to fit.
///
/// SAFETY GUARANTEES
/// -----------------
///   1. Every nullable field is captured into a local before use → smart
///      cast → zero `!` operators in this file.
///   2. The row never overflows the parent width (FittedBox).
///   3. All Text widgets cap to `maxLines: 1` + `TextOverflow.ellipsis`
///      so even with system font-scaling at 200 % the line clips cleanly.
class PriceRow extends StatelessWidget {
  const PriceRow({
    super.key,
    required this.price,
    this.originalPrice,
    this.discountPercent,
    this.unit,
    this.compact = false,
  });

  final double price;
  final double? originalPrice;
  final double? discountPercent;
  final String? unit;
  final bool compact;

  /// Returns the % discount label to render, or `null` when there is no
  /// meaningful discount. Always uses LOCAL captures of the nullable
  /// fields → safe across closures.
  double? _resolvedDiscountFrom({required double? strikePrice}) {
    final explicit = discountPercent;
    if (explicit != null && explicit > 0) return explicit;
    if (strikePrice == null) return null;
    final diff = ((strikePrice - price) / strikePrice * 100).clamp(1, 99);
    return diff.toDouble();
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    // Capture nullable instance fields into LOCALS so Dart's null-promotion
    // kicks in. Public final fields on a StatelessWidget cannot be promoted
    // (they are technically getters and a subclass could override), so the
    // old `originalPrice!` could compile but throw at runtime. Local copies
    // sidestep the entire problem.
    final orig = originalPrice;
    final double? strikePrice =
        (orig != null && orig.isFinite && orig > price + 0.01) ? orig : null;

    final unitLabel = unit;
    final hasUnit = unitLabel != null && unitLabel.trim().isNotEmpty;
    final resolvedDiscount = _resolvedDiscountFrom(strikePrice: strikePrice);

    final priceStyle = compact
        ? Theme.of(context).textTheme.titleSmall
        : Theme.of(context).textTheme.titleMedium;

    // FittedBox(scaleDown) shrinks the whole row when the parent is
    // narrower than the intrinsic width, preventing "RenderFlex
    // overflowed by N pixels" warnings on tightly packed cards. Every
    // Row child below has bounded width because we use
    // `mainAxisSize: MainAxisSize.min` (no Expanded/Spacer/Flexible).
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text(
            '₹${price.toStringAsFixed(0)}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: priceStyle?.copyWith(
              color: mv.textPrimary,
              fontWeight: FontWeight.w800,
              letterSpacing: -0.3,
            ),
          ),
          if (hasUnit) ...[
            SizedBox(width: mv.spacing.xxs),
            Text(
              '/$unitLabel',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mv.textMuted,
                    fontWeight: FontWeight.w500,
                  ),
            ),
          ],
          if (strikePrice != null) ...[
            SizedBox(width: mv.spacing.xs),
            Text(
              '₹${strikePrice.toStringAsFixed(0)}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: mv.textMuted,
                    decoration: TextDecoration.lineThrough,
                    decorationColor: mv.textMuted,
                  ),
            ),
          ],
          if (resolvedDiscount != null) ...[
            SizedBox(width: mv.spacing.xs),
            Text(
              '${resolvedDiscount.round()}% off',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: mv.brandPrimary,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ],
      ),
    );
  }
}
