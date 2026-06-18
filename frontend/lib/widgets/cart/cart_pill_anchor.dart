import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shared landing target for fly-to-cart animations.
///
/// [FloatingCartBar] mounts [thumbnailStackKey] on the thumbnail stack.
/// Only one bar is visible at a time (tab shell or pushed catalog).
abstract final class CartPillAnchor {
  static final GlobalKey thumbnailStackKey = GlobalKey();

  /// Bumped when a fly animation completes — pill thumbnails briefly scale up.
  static final ValueNotifier<int> punchTick = ValueNotifier<int>(0);

  static Rect? get targetRect {
    final context = thumbnailStackKey.currentContext;
    if (context == null) return null;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || !box.attached) return null;
    final topLeft = box.localToGlobal(Offset.zero);
    return topLeft & box.size;
  }

  static Offset? get targetCenter => targetRect?.center;

  static void punch() {
    punchTick.value++;
  }

  /// Resolves target after the next frame (pill may still be laying out).
  static Future<Offset?> resolveTargetCenter() async {
    await SchedulerBinding.instance.endOfFrame;
    return targetCenter;
  }
}
