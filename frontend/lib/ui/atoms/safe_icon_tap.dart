import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// =============================================================================
/// SafeIconTap — a render-safe replacement for `IconButton` in tight rows.
/// =============================================================================
///
/// WHY THIS EXISTS
/// ---------------
/// `IconButton` wraps its child in a `_RenderInputPadding` render object
/// that enforces a 48×48 minimum tap target. Inside tight rows
/// (e.g. cart steppers, expanded search bars, coupon chips, product CTAs)
/// this min-size leaks upward and throws:
///
///   * `RenderBox was not laid out: _RenderInputPadding ...`
///   * `_debugRelayoutBoundaryAlreadyMarkedNeedsLayout`
///
/// `SafeIconTap` has ZERO `_RenderInputPadding` in its render tree. It is
/// a SizedBox + Material(transparent) + InkWell triple — therefore safe to
/// drop into any row regardless of how cramped it is.
///
/// USE CASES
/// ---------
///   * product cards
///   * quantity steppers
///   * cart quantity controls
///   * coupon "remove" chip
///   * category chip rows
///   * search bar suffix icons
///   * catalog header back / clear
///   * inline action icons inside `TextField` (`prefixIcon` / `suffixIcon`)
///
/// SIZE / SHAPE
/// ------------
/// Defaults to a 36×36 circular tap target with an 18-px icon. Override
/// `size` / `iconSize` for larger UI affordances (e.g. app bar overlay
/// buttons).  Border radius is a full circle (`999`) by default to match
/// the spec in the bug brief.
///
/// NULL SAFETY
/// -----------
/// The `onTap` is nullable. When null, the InkWell renders disabled and
/// no haptic fires. When non-null, the callback is captured to a local
/// before being invoked — so a parent rebuild that nulls the handler
/// between paint and tap silently swallows the tap instead of crashing
/// with `Null check operator used on a null value`.
class SafeIconTap extends StatelessWidget {
  const SafeIconTap({
    super.key,
    required this.icon,
    required this.onTap,
    this.size = 36,
    this.iconSize = 18,
    this.color,
    this.haptic = true,
    this.tooltip,
  });

  final IconData icon;
  final VoidCallback? onTap;
  final double size;
  final double iconSize;
  final Color? color;
  final bool haptic;
  final String? tooltip;

  @override
  Widget build(BuildContext context) {
    // Capture into a local — closures CANNOT smart-cast instance fields
    // across the boundary, so `widget.onTap!()` would still throw. The
    // local capture pattern is what makes this widget actually safe.
    final localOnTap = onTap;
    final enabled = localOnTap != null;

    final iconColor = color ??
        (enabled
            ? IconTheme.of(context).color ??
                Theme.of(context).iconTheme.color ??
                Theme.of(context).colorScheme.onSurface
            : Theme.of(context).disabledColor);

    final tap = SizedBox(
      width: size,
      height: size,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: enabled
              ? () {
                  if (haptic) HapticFeedback.lightImpact();
                  // `?.call()` not `localOnTap!()` — if a parallel rebuild
                  // nulls the handler between schedule and invoke, we
                  // silently swallow rather than throw.
                  localOnTap.call();
                }
              : null,
          borderRadius: BorderRadius.circular(999),
          child: Center(
            child: Icon(
              icon,
              size: iconSize,
              color: iconColor,
            ),
          ),
        ),
      ),
    );

    final label = tooltip;
    if (label != null && label.isNotEmpty) {
      return Tooltip(message: label, child: tap);
    }
    return tap;
  }
}
