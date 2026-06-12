import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../design_system/tokens/meatvo_durations.dart';

/// Subtle press scale for premium tactile feedback.
class ScaleTap extends StatefulWidget {
  const ScaleTap({
    super.key,
    required this.child,
    this.onTap,
    this.enabled = true,
    this.scale = 0.97,
    this.haptic = true,
  });

  final Widget child;
  final VoidCallback? onTap;
  final bool enabled;
  final double scale;
  final bool haptic;

  @override
  State<ScaleTap> createState() => _ScaleTapState();
}

class _ScaleTapState extends State<ScaleTap> {
  bool _pressed = false;

  void _setPressed(bool value) {
    if (!widget.enabled || widget.onTap == null) return;
    if (_pressed == value) return;
    setState(() => _pressed = value);
  }

  @override
  Widget build(BuildContext context) {
    // Capture nullable callback into a LOCAL so the closure below does
    // not need `!`. Final instance fields on a StatefulWidget cannot
    // be smart-cast across a closure boundary in Dart — so the previous
    // `widget.onTap!()` could throw "Null check operator used on a null
    // value" if the parent rebuilt with onTap=null between the closure
    // being scheduled and being invoked.
    final localOnTap = widget.onTap;
    final enabled = widget.enabled && localOnTap != null;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: enabled ? (_) => _setPressed(true) : null,
      onTapUp: enabled ? (_) => _setPressed(false) : null,
      onTapCancel: enabled ? () => _setPressed(false) : null,
      onTap: enabled
          ? () {
              if (widget.haptic) HapticFeedback.lightImpact();
              // `localOnTap` is captured when `enabled` is true (non-null).
              localOnTap();
            }
          : null,
      child: AnimatedScale(
        scale: _pressed ? widget.scale : 1,
        duration: MeatvoDurations.fast,
        curve: MeatvoDurations.curve,
        child: widget.child,
      ),
    );
  }
}
