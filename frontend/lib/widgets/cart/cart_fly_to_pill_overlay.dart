import 'dart:ui' show lerpDouble;

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';

import '../../app_navigator_key.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../utils/media_url_resolver.dart';
import 'cart_pill_anchor.dart';

/// Animates a product thumbnail from [startRect] into the cart pill.
abstract final class CartFlyToPillOverlay {
  static const Duration _duration = Duration(milliseconds: 450);
  static const double _flySize = 28;

  static Future<void> show(
    BuildContext context, {
    required String? imageUrl,
    required Rect startRect,
  }) async {
    final overlay = appNavigatorKey.currentState?.overlay ??
        Overlay.maybeOf(context, rootOverlay: true);
    if (overlay == null) return;

    final targetCenter = await CartPillAnchor.resolveTargetCenter();
    if (targetCenter == null) return;

    late OverlayEntry entry;
    entry = OverlayEntry(
      builder: (ctx) => _FlyLayer(
        imageUrl: imageUrl,
        startCenter: startRect.center,
        endCenter: targetCenter,
        onDone: () {
          entry.remove();
          CartPillAnchor.punch();
        },
      ),
    );

    overlay.insert(entry);
  }
}

class _FlyLayer extends StatefulWidget {
  const _FlyLayer({
    required this.imageUrl,
    required this.startCenter,
    required this.endCenter,
    required this.onDone,
  });

  final String? imageUrl;
  final Offset startCenter;
  final Offset endCenter;
  final VoidCallback onDone;

  @override
  State<_FlyLayer> createState() => _FlyLayerState();
}

class _FlyLayerState extends State<_FlyLayer> with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: CartFlyToPillOverlay._duration)
      ..forward().whenComplete(() {
        if (mounted) widget.onDone();
      });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Offset _bezierPoint(double t) {
    final start = widget.startCenter;
    final end = widget.endCenter;
    final control = Offset(
      (start.dx + end.dx) / 2,
      start.dy - 72,
    );
    final u = 1 - t;
    return Offset(
      u * u * start.dx + 2 * u * t * control.dx + t * t * end.dx,
      u * u * start.dy + 2 * u * t * control.dy + t * t * end.dy,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final t = Curves.easeInOutCubic.transform(_controller.value);
        final position = _bezierPoint(t);
        final scale = lerpDouble(1.0, 0.55, t)!;
        final opacity = t < 0.88 ? 1.0 : lerpDouble(1.0, 0.0, (t - 0.88) / 0.12)!;

        return IgnorePointer(
          child: Stack(
            children: [
              Positioned(
                left: position.dx - CartFlyToPillOverlay._flySize / 2,
                top: position.dy - CartFlyToPillOverlay._flySize / 2,
                child: Opacity(
                  opacity: opacity,
                  child: Transform.scale(
                    scale: scale,
                    child: _FlyThumb(imageUrl: widget.imageUrl),
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FlyThumb extends StatelessWidget {
  const _FlyThumb({required this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final resolved = MediaUrlResolver.resolve(imageUrl);
    final hasImage = resolved != null && resolved.isNotEmpty;

    return Container(
      width: CartFlyToPillOverlay._flySize,
      height: CartFlyToPillOverlay._flySize,
      decoration: BoxDecoration(
        color: Colors.white,
        shape: BoxShape.circle,
        border: Border.all(color: MeatvoColors.brandPrimary, width: 2),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.18),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      clipBehavior: Clip.antiAlias,
      child: hasImage
          ? CachedNetworkImage(
              imageUrl: resolved,
              fit: BoxFit.cover,
              placeholder: (_, __) => const _FlyPlaceholder(),
              errorWidget: (_, __, ___) => const _FlyPlaceholder(),
            )
          : const _FlyPlaceholder(),
    );
  }
}

class _FlyPlaceholder extends StatelessWidget {
  const _FlyPlaceholder();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Icon(
        Icons.image_outlined,
        size: 14,
        color: MeatvoColors.textMuted,
      ),
    );
  }
}
