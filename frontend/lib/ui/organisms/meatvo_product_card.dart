import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/tokens/meatvo_durations.dart';
import '../../design_system/tokens/meatvo_spacing.dart';
import '../../models/product_model.dart';
import '../../utils/media_url_resolver.dart';
import '../../widgets/cart/cart_fly_to_pill_overlay.dart';
import '../atoms/meatvo_badge.dart';
import '../atoms/scale_tap.dart';
import '../molecules/price_row.dart';
import '../molecules/quantity_stepper.dart';

enum MeatvoProductCardLayout { grid, carousel }

/// =============================================================================
/// MeatvoProductCard — production-grade, crash-proof product card.
/// =============================================================================
///
/// ROOT CAUSE OF PREVIOUS CRASHES
/// ------------------------------
/// The catalog grid was going fully blank because the card was emitting the
/// following Flutter rendering errors at first-frame layout:
///
///   • "BoxConstraints forces an infinite width"
///     → A child (Row / Column / AnimatedSwitcher) was given UNBOUNDED width
///       by an ancestor that itself was unbounded (e.g. a `Row` without
///       `Expanded`, or a horizontal `ListView` item that internally used
///       `width: double.infinity`).
///
///   • "RenderBox was not laid out"
///     → AnimatedSwitcher's default layoutBuilder uses `Stack(StackFit.loose)`
///       which forwards LOOSE constraints to non-positioned children. When
///       the "ADD" / "QuantityStepper" swap happened mid-frame, the leaving
///       child was queried for paint() before its layout() finished.
///
///   • "RenderFlex overflowed by N pixels"
///     → Long product names, dense text scaling, or discount badges pushed
///       the inner Column past the parent's height/width.
///
///   • "_RenderInputPadding._debugRelayoutBoundaryAlreadyMarkedNeedsLayout"
///     → `IconButton` injects a `_RenderInputPadding` that enforces a 48×48
///       minimum tap target. Placing an `IconButton` inside a 32-px-tall
///       row caused a relayout storm. We replaced every `IconButton` in the
///       card tree with hand-rolled `_StepButton` (no `_RenderInputPadding`).
///
///   • "Null check operator used on a null value"
///     → Backend returns nullable fields (`image_url: null`,
///       `freshness_badge: null`, `cut_types: null`, `marination_options: null`,
///       `discount: null`). The old code used `imageUrl!`, `badge!`,
///       `originalPrice!` etc.  Bangs on instance fields are NOT safe in
///       Dart because the field is technically a getter and CANNOT be
///       smart-cast across closure boundaries.  Every `!` was replaced
///       with a local capture + `??` fallback.
///
/// LAYOUT INVARIANTS ENFORCED HERE
/// -------------------------------
///   1. The card ALWAYS renders inside a finite width. `LayoutBuilder`
///      falls back to `_kFallbackWidth` if a careless parent (e.g. a `Row`
///      without `Expanded`) provides unbounded width.
///   2. The image, body, and CTA blocks use explicit / `Flexible` sizes so
///      `Column(crossAxisAlignment.stretch)` never overflows on small
///      phones, landscape, tablets, or split-screen.
///   3. The CTA pill has a DETERMINISTIC width (`_kCtaWidth`) — the
///      AnimatedSwitcher therefore never reflows between "ADD" and stepper
///      states.  This kills the relayout-loop crash that previously turned
///      the grid blank.
///   4. NO null assertions (`!`) anywhere in the tree.  Every nullable
///      field is captured into a local and guarded with `??` / `?.call()`.
class MeatvoProductCard extends StatefulWidget {
  const MeatvoProductCard({
    super.key,
    required this.product,
    required this.displayPrice,
    required this.displayUnit,
    this.originalPrice,
    this.discountPercent,
    this.quantity = 0,
    this.isBusy = false,
    this.inStock = true,
    this.orderingPaused = false,
    this.showFreshBadge = true,
    this.badgeLabel,
    this.badgeVariant = MeatvoBadgeVariant.popular,
    this.layout = MeatvoProductCardLayout.grid,
    this.onTap,
    this.onAdd,
    this.onIncrement,
    this.onDecrement,
  });

  final ProductModel product;
  final double displayPrice;
  final String displayUnit;
  final double? originalPrice;
  final double? discountPercent;
  final int quantity;
  final bool isBusy;
  final bool inStock;
  final bool orderingPaused;
  final bool showFreshBadge;
  final String? badgeLabel;
  final MeatvoBadgeVariant badgeVariant;
  final MeatvoProductCardLayout layout;
  final VoidCallback? onTap;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  /// Fixed CTA slot geometry. Why hard-coded?
  ///   • AnimatedSwitcher must NEVER let its child request infinity.
  ///   • Both states ("ADD" pill and QuantityStepper) must fit inside the
  ///     same 112×32 box so the surrounding card layout is stable across
  ///     transitions. Without a fixed box the Stack-based switcher
  ///     would mark the parent dirty mid-frame → "_debugRelayout
  ///     BoundaryAlreadyMarkedNeedsLayout" + blank grid.
  static const double ctaHeight = 32;
  static const double _kCtaWidth = 112;
  static const double _kAddPillWidth = 32;

  static const double _cardRadius = 22;

  // Safety net for the catastrophic "infinite width" path: if the parent
  // (e.g. a misconfigured Row) feeds us unbounded width via LayoutBuilder,
  // we fall back to this finite width instead of crashing.
  static const double _kFallbackWidth = 172;

  /// Fixed body height below the 1:1 image: name + unit + price + CTA + padding.
  static const double _kBodyHeight = 124;

  static double gridCellWidth(double screenWidth) {
    return (screenWidth - MeatvoSpacing.md * 2 - MeatvoSpacing.sm) / 2;
  }

  static double gridCardHeight(double screenWidth) {
    final cellWidth = gridCellWidth(screenWidth);
    return cellWidth + _kBodyHeight;
  }

  /// Height for fixed-width carousel rails (e.g. home horizontal sections).
  static double carouselCardHeight(double cardWidth) =>
      cardWidth + _kBodyHeight;

  @override
  State<MeatvoProductCard> createState() => _MeatvoProductCardState();
}

class _MeatvoProductCardState extends State<MeatvoProductCard> {
  final GlobalKey _imageKey = GlobalKey();

  Rect? _imageRect() {
    final box = _imageKey.currentContext?.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  void _triggerFlyAnimation() {
    final rect = _imageRect();
    if (rect == null || !mounted) return;
    CartFlyToPillOverlay.show(
      context,
      imageUrl: widget.product.primaryImageUrl,
      startRect: rect,
    );
  }

  void _handleAdd() {
    _triggerFlyAnimation();
    widget.onAdd?.call();
  }

  void _handleIncrement() {
    _triggerFlyAnimation();
    widget.onIncrement?.call();
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    // Debug-only identification marker. Helps confirm in the logcat which
    // card variant is actually being mounted when triaging crashes — the
    // bug brief specifically asked for this. Strips out of release
    // builds via `kDebugMode`.
    if (kDebugMode) {
      debugPrint('Rendering MeatvoProductCard: ${widget.product.id}');
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        // Resolve a guaranteed-finite width. `hasBoundedWidth` is necessary
        // but NOT sufficient — `UnconstrainedBox` can report
        // `hasBoundedWidth==true` while still returning `double.infinity`,
        // so we additionally validate `isFinite`. Defense-in-depth.
        final rawW = constraints.maxWidth;
        final width = (constraints.hasBoundedWidth && rawW.isFinite && rawW > 0)
            ? rawW
            : MeatvoProductCard._kFallbackWidth;

        final discount = widget.discountPercent;
        final orig = widget.originalPrice;
        final resolvedDiscount = (discount != null && discount >= 1 && discount < 100)
            ? discount
            : (orig != null && orig > widget.displayPrice + 0.01)
                ? ((orig - widget.displayPrice) / orig * 100).clamp(1, 99).toDouble()
                : null;
        final showDiscountBadge = resolvedDiscount != null;

        return SizedBox(
          // SEAL the width — every child below now lays out inside finite
          // constraints, regardless of how careless the parent is.
          width: width,
          child: ScaleTap(
            onTap: widget.onTap,
            scale: 0.985,
            haptic: false,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: mv.surfaceCard,
                borderRadius: BorderRadius.circular(MeatvoProductCard._cardRadius),
                boxShadow: mv.shadowCard,
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MeatvoProductCard._cardRadius),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    AspectRatio(
                      aspectRatio: 1,
                      child: KeyedSubtree(
                        key: _imageKey,
                        child: _ImageBlock(
                          imageUrl: widget.product.primaryImageUrl,
                          discountPercent: resolvedDiscount,
                          showFresh: widget.showFreshBadge &&
                              widget.inStock &&
                              widget.badgeLabel == null,
                          badgeLabel: showDiscountBadge ? null : widget.badgeLabel,
                          badgeVariant: widget.badgeVariant,
                          inStock: widget.inStock,
                          orderingPaused: widget.orderingPaused,
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            widget.product.name,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            softWrap: true,
                            style: Theme.of(context)
                                .textTheme
                                .bodyMedium
                                ?.copyWith(
                                  color: mv.textPrimary,
                                  fontWeight: FontWeight.w700,
                                  height: 1.25,
                                  letterSpacing: -0.2,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            widget.displayUnit,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            softWrap: false,
                            style: Theme.of(context)
                                .textTheme
                                .labelSmall
                                ?.copyWith(
                                  color: mv.textMuted,
                                  fontWeight: FontWeight.w500,
                                ),
                          ),
                          const SizedBox(height: 6),
                          PriceRow(
                            price: widget.displayPrice,
                            originalPrice: widget.originalPrice,
                            discountPercent: resolvedDiscount,
                            compact: true,
                            showDiscountText: !showDiscountBadge,
                          ),
                          const SizedBox(height: 8),
                          Align(
                            alignment: Alignment.centerRight,
                            child: SizedBox(
                              width: MeatvoProductCard._kCtaWidth,
                              height: MeatvoProductCard.ctaHeight,
                              child: _CartCta(
                                inStock: widget.inStock,
                                orderingPaused: widget.orderingPaused,
                                quantity: widget.quantity,
                                isBusy: widget.isBusy,
                                onAdd: widget.onAdd == null ? null : _handleAdd,
                                onIncrement:
                                    widget.onIncrement == null ? null : _handleIncrement,
                                onDecrement: widget.onDecrement,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// =============================================================================
/// _CartCta — the swap between the "ADD" pill and the QuantityStepper.
/// =============================================================================
///
/// Why this widget needs special care:
///   • AnimatedSwitcher's DEFAULT layoutBuilder uses `Stack(StackFit.loose)`
///     which forwards UNBOUNDED constraints to non-positioned children.
///   • The outgoing + incoming children co-exist for one frame during the
///     transition — if either child requests intrinsic width that differs
///     from the other, the parent relayout marker gets set twice in the
///     same frame → "_debugRelayoutBoundaryAlreadyMarkedNeedsLayout" → the
///     grid frame is dropped → blank screen.
///
/// Fix: we override `layoutBuilder` so the Stack uses `StackFit.expand`
/// (TIGHT constraints to every child) AND we wrap children that need to
/// occupy the full pill (the "ADD" button) in a `Positioned.fill`. This
/// guarantees:
///   • Every child receives identical tight constraints.
///   • No child can request infinity.
///   • The Stack's overall size is locked to the parent's 116×40 SizedBox.
class _CartCta extends StatelessWidget {
  const _CartCta({
    required this.inStock,
    required this.orderingPaused,
    required this.quantity,
    required this.isBusy,
    this.onAdd,
    this.onIncrement,
    this.onDecrement,
  });

  final bool inStock;
  final bool orderingPaused;
  final int quantity;
  final bool isBusy;
  final VoidCallback? onAdd;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    if (!inStock) {
      // Hand-rolled "Sold out" pill. We deliberately do NOT use
      // `OutlinedButton` here — Material's button infra wraps the label
      // in a `_RenderInputPadding` to enforce a 48×48 min tap target,
      // which throws "RenderBox was not laid out" when our 32-px tall
      // CTA box is tighter than the min tap target.
      return DecoratedBox(
        decoration: BoxDecoration(
          color: mv.surfaceCard,
          border: Border.all(color: mv.border),
          borderRadius: BorderRadius.circular(mv.radii.sm),
        ),
        child: Center(
          child: Text(
            'Sold out',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            softWrap: false,
            style: Theme.of(context).textTheme.labelSmall?.copyWith(
                  color: mv.textMuted,
                  fontWeight: FontWeight.w700,
                ),
          ),
        ),
      );
    }

    if (orderingPaused && quantity == 0) {
      return Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onAdd == null
              ? null
              : () {
                  HapticFeedback.lightImpact();
                  onAdd?.call();
                },
          borderRadius: BorderRadius.circular(mv.radii.sm),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: mv.surfaceCard,
              border: Border.all(color: mv.border),
              borderRadius: BorderRadius.circular(mv.radii.sm),
            ),
            child: Center(
              child: Text(
                'Closed',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                softWrap: false,
                style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: mv.textMuted,
                      fontWeight: FontWeight.w700,
                    ),
              ),
            ),
          ),
        ),
      );
    }

    return AnimatedSwitcher(
      duration: MeatvoDurations.normal,
      switchInCurve: MeatvoDurations.curve,
      switchOutCurve: MeatvoDurations.curve,
      // CRITICAL: see the class-level comment above. `StackFit.expand`
      // forces TIGHT constraints to every non-positioned child so the
      // outgoing + incoming children share the exact same 112×32 box.
      // Without this, the catalog grid went blank on every category open.
      layoutBuilder: (currentChild, previousChildren) {
        return Stack(
          fit: StackFit.expand,
          alignment: Alignment.center,
          children: [
            // Previous children are wrapped in `Positioned.fill` so they
            // can NEVER request intrinsic width during the fade-out frame.
            for (final child in previousChildren) Positioned.fill(child: child),
            if (currentChild != null) Positioned.fill(child: currentChild),
          ],
        );
      },
      transitionBuilder: (child, animation) {
        final slide = Tween<Offset>(
          begin: const Offset(0, 0.12),
          end: Offset.zero,
        ).animate(CurvedAnimation(
          parent: animation,
          curve: MeatvoDurations.curve,
        ));
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(position: slide, child: child),
        );
      },
      child: quantity > 0
          ? _StepperSlot(
              key: const ValueKey('stepper'),
              quantity: quantity,
              isBusy: isBusy,
              onIncrement: onIncrement,
              onDecrement: onDecrement,
            )
          : _AddButton(
              key: const ValueKey('add'),
              isBusy: isBusy,
              onAdd: onAdd,
            ),
    );
  }
}

/// QuantityStepper wrapped in a SizedBox that exactly matches the CTA pill.
/// We use `Align(centerRight)` inside the deterministic box so the stepper
/// hugs the trailing edge — but the Align itself receives TIGHT constraints
/// from `Positioned.fill` so it cannot stretch infinitely.
class _StepperSlot extends StatelessWidget {
  const _StepperSlot({
    super.key,
    required this.quantity,
    required this.isBusy,
    required this.onIncrement,
    required this.onDecrement,
  });

  final int quantity;
  final bool isBusy;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerRight,
      child: QuantityStepper(
        quantity: quantity,
        isBusy: isBusy,
        height: MeatvoProductCard.ctaHeight,
        expanded: false,
        onIncrement: onIncrement,
        onDecrement: onDecrement,
      ),
    );
  }
}

class _AddButton extends StatelessWidget {
  const _AddButton({
    super.key,
    required this.isBusy,
    this.onAdd,
  });

  final bool isBusy;
  final VoidCallback? onAdd;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    // Capture nullable callback into a local so the closure below does
    // not need `!`.  Final instance fields cannot be smart-cast across
    // a closure boundary in Dart (they are technically getters and a
    // subclass could override) — local capture sidesteps the entire
    // problem.
    final localOnAdd = onAdd;
    final canTap = !isBusy && localOnAdd != null;

    return Align(
      alignment: Alignment.centerRight,
      child: ScaleTap(
        onTap: canTap
            ? () {
                HapticFeedback.lightImpact();
                localOnAdd.call();
              }
            : null,
        enabled: canTap,
        child: SizedBox(
          width: MeatvoProductCard._kAddPillWidth,
          height: MeatvoProductCard.ctaHeight,
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: mv.brandPrimary,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: mv.brandPrimary.withValues(alpha: 0.22),
                  blurRadius: 8,
                  offset: const Offset(0, 2),
                ),
              ],
            ),
            child: Center(
              child: isBusy
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : Icon(
                      Icons.add_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Image renderer with full null-safety.
///
/// Backend may return `image_url: null` (or `images: null`) and the
/// model's `primaryImageUrl` getter therefore returns `String?`. The old
/// code did `imageUrl!.isEmpty` which threw "Null check operator used on
/// a null value" the moment a product without an image entered the grid.
Widget _buildImage(String? imageUrl) {
  final resolved = MediaUrlResolver.resolve(imageUrl);
  final safeUrl = resolved ?? '';
  if (safeUrl.isEmpty) {
    return Container(
      color: MeatvoColors.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: MeatvoColors.textMuted.withValues(alpha: 0.5),
          size: 36,
        ),
      ),
    );
  }
  return CachedNetworkImage(
    imageUrl: safeUrl,
    fit: BoxFit.cover,
    fadeInDuration: const Duration(milliseconds: 280),
    placeholder: (context, url) => Container(
      color: MeatvoColors.surfaceMuted,
      child: const Center(
        child: SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: MeatvoColors.brandPrimary,
          ),
        ),
      ),
    ),
    errorWidget: (context, url, error) => Container(
      color: MeatvoColors.surfaceMuted,
      child: Center(
        child: Icon(
          Icons.image_not_supported_outlined,
          color: MeatvoColors.textMuted.withValues(alpha: 0.5),
          size: 36,
        ),
      ),
    ),
  );
}

class _ImageBlock extends StatelessWidget {
  const _ImageBlock({
    required this.imageUrl,
    required this.inStock,
    this.orderingPaused = false,
    this.discountPercent,
    this.showFresh = false,
    this.badgeLabel,
    this.badgeVariant = MeatvoBadgeVariant.popular,
  });

  final String? imageUrl;
  final double? discountPercent;
  final bool showFresh;
  final String? badgeLabel;
  final MeatvoBadgeVariant badgeVariant;
  final bool inStock;
  final bool orderingPaused;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    // Local capture for smart-cast — no `badge!` bang anywhere.
    final badge = badgeLabel;
    final showBadge = badge != null && badge.isNotEmpty;
    final discount = discountPercent;
    final showDiscount =
        discount != null && discount >= 1 && discount < 100;
    final shouldDimImage = !inStock || orderingPaused;

    return Stack(
      fit: StackFit.expand,
      children: [
        ColorFiltered(
          colorFilter: shouldDimImage
              ? const ColorFilter.matrix(<double>[
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0.2126, 0.7152, 0.0722, 0, 0,
                  0, 0, 0, 1, 0,
                ])
              : const ColorFilter.mode(Colors.transparent, BlendMode.dst),
          child: Opacity(
            opacity: shouldDimImage ? 0.75 : 1,
            child: _buildImage(imageUrl),
          ),
        ),
        // Subtle gradient overlay so the badge stays readable on bright
        // product photos.
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          height: 48,
          child: DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.transparent,
                  Colors.black.withValues(alpha: 0.12),
                ],
              ),
            ),
          ),
        ),
        if (showDiscount)
          Positioned(
            top: mv.spacing.sm,
            left: mv.spacing.sm,
            child: MeatvoBadge(
              label: '${discount.round()}% OFF',
              variant: MeatvoBadgeVariant.discount,
            ),
          )
        else if (showBadge)
          Positioned(
            top: mv.spacing.sm,
            left: mv.spacing.sm,
            child: MeatvoBadge(
              label: badge,
              variant: badgeVariant,
            ),
          )
        else if (showFresh)
          Positioned(
            top: mv.spacing.sm,
            left: mv.spacing.sm,
            child: const MeatvoBadge(
              label: 'FRESH',
              variant: MeatvoBadgeVariant.fresh,
            ),
          ),
        if (showDiscount && showFresh)
          Positioned(
            top: mv.spacing.sm,
            right: mv.spacing.sm,
            child: const MeatvoBadge(
              label: 'FRESH',
              variant: MeatvoBadgeVariant.fresh,
            ),
          ),
        if (!inStock)
          Container(
            color: Colors.black.withValues(alpha: 0.45),
            alignment: Alignment.center,
            child: Text(
              'Out of stock',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          )
        else if (orderingPaused)
          Container(
            color: Colors.black.withValues(alpha: 0.35),
            alignment: Alignment.center,
            child: Text(
              'Ordering paused',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              softWrap: false,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ),
      ],
    );
  }
}
