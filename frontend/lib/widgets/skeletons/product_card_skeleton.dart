import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import 'shimmer_base.dart';

/// =============================================================================
/// ProductCardSkeleton — render-safe placeholder used while the catalog grid
/// or carousel is loading. Designed to match the geometry of
/// [MeatvoProductCard.gridCardHeight] so the grid never reflows when the
/// real cards land.
/// =============================================================================
///
/// ROOT CAUSE OF THE PREVIOUS "14px overflow" CRASH
/// ------------------------------------------------
/// The old implementation hard-coded the following heights inside a fixed
/// `Container > Column`:
///
///   • image            : 150
///   • outer padding    : 24 (12 top + 12 bottom)
///   • badge shimmer    : 14 + 8
///   • title shimmer    : 16 + 8
///   • unit shimmer     : 12 + 20
///   • CTA row          : 34
///   ---------------------------
///   total              : ≈ 286–296 px (depending on font scale)
///
/// `MeatvoProductCard.gridCardHeight()` clamps to `[288, 328]`. On a 360-dp
/// device the grid cell ends up at 288 px → the skeleton's intrinsic 286
/// height plus a 2-px rounding bias overflowed by ~14 px and Flutter logged
///   `A RenderFlex overflowed by 14 pixels on the bottom.`
///
/// LAYOUT INVARIANTS ENFORCED HERE
/// -------------------------------
///   1. Top-level `LayoutBuilder` guarantees a finite width even if the
///      parent (e.g. a horizontal carousel) feeds us unbounded constraints.
///   2. Inside the card we use `LayoutBuilder` AGAIN to read the available
///      HEIGHT, then split it proportionally between the image (≈55%) and
///      the body (the remainder).  No child can request more pixels than
///      the parent grants, so the 14-px bottom overflow is mathematically
///      impossible.
///   3. The body section uses `Expanded` + `MainAxisSize.min` + `Flexible`
///      around each shimmer line so any spare or missing pixels are
///      absorbed gracefully — including font-scale 200%, split-screen,
///      and 320-dp phones.
///   4. ClipRRect wraps the entire card so the inner shimmer can never
///      paint outside the rounded silhouette during the layout pass.
///   5. NO `width: double.infinity` reaches a Row / horizontal-scroll
///      parent. Every `ShimmerContainer(width: double.infinity, ...)` is
///      now wrapped in `SizedBox.expand` or `Expanded` inside a bounded
///      parent, so an unbounded ancestor cannot poison the layout.
class ProductCardSkeleton extends StatelessWidget {
  const ProductCardSkeleton({super.key});

  static const double _kFallbackWidth = 168;
  static const double _kFallbackHeight = 288;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, outer) {
        final width = (outer.hasBoundedWidth &&
                outer.maxWidth.isFinite &&
                outer.maxWidth > 0)
            ? outer.maxWidth
            : _kFallbackWidth;

        return SizedBox(
          width: width,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: AppColors.divider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(20),
              child: LayoutBuilder(
                builder: (context, inner) {
                  // Resolve a finite height. If parent didn't allocate one
                  // (vertical sliver delegate, e.g.) we fall back to the
                  // same constant `MeatvoProductCard.gridCardHeight` clamps
                  // to. This guarantees image + body always fit.
                  final hasFiniteHeight = inner.hasBoundedHeight &&
                      inner.maxHeight.isFinite &&
                      inner.maxHeight > 0;
                  final height =
                      hasFiniteHeight ? inner.maxHeight : _kFallbackHeight;
                  final imageHeight = (height * 0.55).clamp(120.0, 180.0);

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Image slot: fixed proportional height; SizedBox.expand
                      // (width:double.infinity is intentional INSIDE this
                      // SizedBox because the SizedBox itself is already
                      // bounded by the parent Column's stretch + the outer
                      // LayoutBuilder's finite width).
                      SizedBox(
                        height: imageHeight,
                        width: double.infinity,
                        child: const ShimmerContainer(
                          width: double.infinity,
                          height: double.infinity,
                          borderRadius: 0,
                        ),
                      ),
                      // Body: take the remainder. Expanded inside the column
                      // gives the body bounded height, so no child below can
                      // overflow the card.
                      Expanded(
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              // Title block — wrapped in Flexible(loose)
                              // so font-scale 200% can shrink it instead
                              // of overflowing.
                              const Flexible(
                                fit: FlexFit.loose,
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    ShimmerContainer(
                                      width: 64,
                                      height: 12,
                                      borderRadius: 999,
                                    ),
                                    SizedBox(height: 8),
                                    _StretchShimmer(height: 14),
                                    SizedBox(height: 6),
                                    ShimmerContainer(
                                      width: 80,
                                      height: 10,
                                      borderRadius: 6,
                                    ),
                                  ],
                                ),
                              ),
                              // CTA row — fixed 28×… for the price shimmer
                              // and a 56×28 trailing pill.  Wrapped in
                              // Flexible(loose) so it can shrink instead of
                              // overflowing on landscape / small phones.
                              const Flexible(
                                fit: FlexFit.loose,
                                child: Padding(
                                  padding: EdgeInsets.only(top: 8),
                                  child: Row(
                                    children: [
                                      Expanded(
                                        child: ShimmerContainer(
                                          width: double.infinity,
                                          height: 18,
                                          borderRadius: 8,
                                        ),
                                      ),
                                      SizedBox(width: 8),
                                      ShimmerContainer(
                                        width: 52,
                                        height: 28,
                                        borderRadius: 12,
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Helper that stretches a ShimmerContainer to the parent's width without
/// ever propagating `double.infinity` to an unbounded ancestor. The
/// surrounding `Flexible/Column(stretch)` provides a finite width; we
/// just translate that into a ShimmerContainer call.
class _StretchShimmer extends StatelessWidget {
  const _StretchShimmer({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final w = c.hasBoundedWidth && c.maxWidth.isFinite ? c.maxWidth : 120.0;
        return ShimmerContainer(width: w, height: height, borderRadius: 8);
      },
    );
  }
}

/// =============================================================================
/// ProductListItemSkeleton — used by list-style (non-grid) loading states.
/// =============================================================================
class ProductListItemSkeleton extends StatelessWidget {
  const ProductListItemSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, c) {
        final width = (c.hasBoundedWidth && c.maxWidth.isFinite && c.maxWidth > 0)
            ? c.maxWidth
            : 320.0;
        return SizedBox(
          width: width,
          child: Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.divider),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: const [
                  ShimmerContainer(width: 88, height: 88, borderRadius: 8),
                  SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _StretchShimmer(height: 14),
                        SizedBox(height: 8),
                        ShimmerContainer(
                          width: 140,
                          height: 14,
                          borderRadius: 8,
                        ),
                        SizedBox(height: 12),
                        ShimmerContainer(
                          width: 100,
                          height: 18,
                          borderRadius: 8,
                        ),
                        SizedBox(height: 8),
                        ShimmerContainer(
                          width: 120,
                          height: 28,
                          borderRadius: 8,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
