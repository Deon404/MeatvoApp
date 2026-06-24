import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Shared landing target for fly-to-cart animations.
///
/// Each visible [FloatingCartBar] registers its own thumbnail key so multiple
/// bars in the tree never share one [GlobalKey].
abstract final class CartPillAnchor {
  static GlobalKey? _activeThumbnailKey;

  static final ValueNotifier<int> punchTick = ValueNotifier<int>(0);

  static void register(GlobalKey key) {
    _activeThumbnailKey = key;
  }

  static void unregister(GlobalKey key) {
    if (_activeThumbnailKey == key) {
      _activeThumbnailKey = null;
    }
  }

  static Rect? get targetRect {
    final context = _activeThumbnailKey?.currentContext;
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
