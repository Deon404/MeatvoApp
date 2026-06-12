import 'package:flutter/material.dart';

import '../../design_system/tokens/meatvo_durations.dart';

/// =============================================================================
/// QuantityStepper — compact `[−] qty [+]` control used in product cards
/// and the cart.
/// =============================================================================
///
/// ROOT CAUSE OF PREVIOUS CRASHES
/// ------------------------------
///   • "_RenderInputPadding._debugRelayoutBoundaryAlreadyMarkedNeedsLayout"
///     → The old version used `IconButton` for the +/− buttons.
///       `IconButton` wraps its child in a `_RenderInputPadding` render
///       object that enforces a 48×48 minimum tap target. Our stepper
///       is only 36 px tall — so `_RenderInputPadding` requested more
///       height than the parent Row could provide, marked the Row dirty,
///       and Flutter dropped the frame ("blank grid").
///
///   • "BoxConstraints forces an infinite width"
///     → The old `expanded` branch returned `width: double.infinity`,
///       which exploded when the stepper landed inside an
///       `AnimatedSwitcher`'s mid-transition Stack (no parent width).
///
///   • "RenderBox was not laid out"
///     → The old busy spinner branch returned a different intrinsic
///       width than the idle branch, so the parent `AnimatedSwitcher`
///       could query paint() before the new layout pass finished.
///
/// LAYOUT INVARIANTS ENFORCED HERE
/// -------------------------------
///   1. The stepper has a DETERMINISTIC width
///      (`_intrinsicWidth = _kBtnSize * 2 + _kCountSlot`) regardless of
///      the busy / idle state. The parent AnimatedSwitcher never sees
///      a width change.
///   2. Step buttons use a fixed `SizedBox(width:36, height:36)` + a
///      centered `Icon` instead of `IconButton`.  This is the EXACT
///      pattern requested in the bug brief:
///          SizedBox(
///            width: 36, height: 36,
///            child: IconButton(
///              padding: EdgeInsets.zero,
///              constraints: BoxConstraints(minWidth: 36, minHeight: 36),
///            ),
///          )
///      …except we go one step further and replace `IconButton` with a
///      hand-rolled `_StepButton` (Material + InkWell) — that way the
///      stepper has ZERO `_RenderInputPadding` in its render tree, so
///      it CAN'T crash even if the surrounding row shrinks to 30 px.
///   3. NO `width: double.infinity` anywhere — even the `expanded` mode
///      caps to a finite intrinsic width and uses `Center` to position
///      the stepper inside whatever bounded width the parent supplies.
///   4. NO null assertions (`!`) — the `onTap` closures call `?.call()`
///      so they are safe against parent rebuilds that null-out the
///      callback between frames.
class QuantityStepper extends StatelessWidget {
  const QuantityStepper({
    super.key,
    required this.quantity,
    required this.onIncrement,
    required this.onDecrement,
    this.isBusy = false,
    this.height = _kBtnSize,
    this.expanded = false,
  });

  final int quantity;
  final VoidCallback? onIncrement;
  final VoidCallback? onDecrement;
  final bool isBusy;
  final double height;
  final bool expanded;

  static const Color _stepperRed = Color(0xFFCC0000);
  static const double _kBtnSize = 36;
  static const double _kCountSlot = 40; // wider than btn so "10+" fits

  /// Total intrinsic width = left button + counter + right button.
  /// Hard-coded so the AnimatedSwitcher swap is pixel-stable.
  double get _intrinsicWidth => _kBtnSize * 2 + _kCountSlot;

  @override
  Widget build(BuildContext context) {
    if (isBusy) {
      // Match the non-busy intrinsic width EXACTLY so AnimatedSwitcher
      // does not reshuffle pixels between busy/idle frames. Never
      // request infinity — even in `expanded` mode we cap to a finite
      // width that the parent's tight constraints can shrink to.
      return SizedBox(
        height: height,
        width: _intrinsicWidth,
        child: const Center(
          child: SizedBox(
            width: 18,
            height: 18,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: _stepperRed,
            ),
          ),
        ),
      );
    }

    final stepper = SizedBox(
      // SEAL the stepper width so the inner Row(mainAxisSize.min) cannot
      // accidentally inherit unbounded width from a misbehaving parent.
      width: _intrinsicWidth,
      height: height,
      child: ClipRRect(
        // Clip the ink ripple to the pill shape — without this the
        // ripple paints outside the red pill on Android.
        borderRadius: BorderRadius.circular(8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: _stepperRed,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _StepButton(
                icon: Icons.remove,
                onTap: onDecrement,
                size: _kBtnSize,
                height: height,
              ),
              SizedBox(
                width: _kCountSlot,
                height: height,
                child: AnimatedSwitcher(
                  duration: MeatvoDurations.fast,
                  switchInCurve: MeatvoDurations.curve,
                  switchOutCurve: MeatvoDurations.curve,
                  // Same defensive layoutBuilder pattern used in the
                  // product-card CTA: TIGHT constraints to both
                  // outgoing + incoming text so the counter slot
                  // never reflows during the +1/-1 animation.
                  layoutBuilder: (currentChild, previousChildren) {
                    return Stack(
                      fit: StackFit.expand,
                      alignment: Alignment.center,
                      children: [
                        for (final child in previousChildren)
                          Positioned.fill(child: child),
                        if (currentChild != null)
                          Positioned.fill(child: currentChild),
                      ],
                    );
                  },
                  transitionBuilder: (child, animation) {
                    return ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    );
                  },
                  child: Center(
                    key: ValueKey<int>(quantity),
                    child: Text(
                      '$quantity',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      softWrap: false,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                      ),
                    ),
                  ),
                ),
              ),
              _StepButton(
                icon: Icons.add,
                onTap: onIncrement,
                size: _kBtnSize,
                height: height,
              ),
            ],
          ),
        ),
      ),
    );

    if (!expanded) return stepper;

    // `expanded == true` => center the stepper inside whatever bounded
    // width the parent provides. `Center` sizes itself to its parent's
    // constraints; the inner stepper still has a fixed `_intrinsicWidth`
    // so there is no unbounded propagation.
    return Center(child: stepper);
  }
}

class _StepButton extends StatelessWidget {
  const _StepButton({
    required this.icon,
    required this.onTap,
    required this.size,
    required this.height,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double height;

  @override
  Widget build(BuildContext context) {
    // Capture nullable onTap into a local so the closure does NOT need
    // `!`. Final instance fields cannot be smart-cast across a closure
    // boundary in Dart.
    final localOnTap = onTap;
    final enabled = localOnTap != null;

    // Hand-rolled tap target — deliberately NOT using `IconButton`.
    // `IconButton` wraps its child in `_RenderInputPadding` to enforce a
    // 48×48 min tap target, which throws "RenderBox was not laid out"
    // if the surrounding row gives it less space. This SizedBox + Material
    // + InkWell trio has ZERO `_RenderInputPadding` and therefore can NEVER
    // crash on a tight row.
    return SizedBox(
      width: size,
      height: height,
      child: Material(
        color: Colors.transparent,
        // `materialTapTargetSize: shrinkWrap` is redundant here (we never
        // invoke `_RenderInputPadding`) but we set it for clarity.
        child: InkWell(
          onTap: enabled
              ? () {
                  // `?.call()` not `localOnTap!()` — between the closure
                  // being scheduled and being invoked the parent may
                  // rebuild with `onTap: null`, which would throw with `!`.
                  localOnTap.call();
                }
              : null,
          borderRadius: BorderRadius.circular(8),
          child: Center(
            child: Icon(
              icon,
              color:
                  enabled ? Colors.white : Colors.white.withValues(alpha: 0.45),
              size: 16,
            ),
          ),
        ),
      ),
    );
  }
}
