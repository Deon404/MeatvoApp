import 'package:flutter/material.dart';

import '../../../design_system/tokens/meatvo_durations.dart';

/// Subtle fade + slide when a home section enters the tree.
class HomeSectionReveal extends StatefulWidget {
  const HomeSectionReveal({
    super.key,
    required this.child,
    this.delay = Duration.zero,
  });

  final Widget child;
  final Duration delay;

  @override
  State<HomeSectionReveal> createState() => _HomeSectionRevealState();
}

class _HomeSectionRevealState extends State<HomeSectionReveal>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<double> _opacity;
  late final Animation<Offset> _offset;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: MeatvoDurations.normal,
    );
    _opacity = CurvedAnimation(parent: _controller, curve: MeatvoDurations.curve);
    _offset = Tween<Offset>(
      begin: const Offset(0, 0.04),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: MeatvoDurations.curve));

    Future<void>.delayed(widget.delay, () {
      if (mounted) _controller.forward();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _opacity,
      child: SlideTransition(position: _offset, child: widget.child),
    );
  }
}
