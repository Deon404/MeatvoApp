import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_durations.dart';
import '../../models/cart_model.dart';
import '../../providers/store_settings_provider.dart';
import '../../services/cart_service.dart';
import '../../widgets/store/store_closed_sheet.dart';
import 'cart_pill_anchor.dart';
import 'cart_pill_thumbnail_stack.dart';

/// Floating pill cart bar with Blinkit-style thumbnails and shared cart state.
class FloatingCartBar extends ConsumerStatefulWidget {
  const FloatingCartBar({
    super.key,
    required this.onViewCartTapped,
  });

  final VoidCallback onViewCartTapped;

  @override
  ConsumerState<FloatingCartBar> createState() => _FloatingCartBarState();
}

class _FloatingCartBarState extends ConsumerState<FloatingCartBar>
    with SingleTickerProviderStateMixin {
  late final AnimationController _punchController;
  late final Animation<double> _punchScale;

  @override
  void initState() {
    super.initState();
    _punchController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 220),
    );
    _punchScale = TweenSequence<double>([
      TweenSequenceItem(tween: Tween(begin: 1.0, end: 1.12), weight: 45),
      TweenSequenceItem(tween: Tween(begin: 1.12, end: 1.0), weight: 55),
    ]).animate(CurvedAnimation(
      parent: _punchController,
      curve: Curves.easeOutCubic,
    ));
    CartPillAnchor.punchTick.addListener(_onPunch);
  }

  void _onPunch() {
    if (!mounted) return;
    _punchController.forward(from: 0);
  }

  @override
  void dispose() {
    CartPillAnchor.punchTick.removeListener(_onPunch);
    _punchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final storeSettings = ref.watch(storeSettingsSyncProvider);

    return ValueListenableBuilder<CartModel>(
      valueListenable: CartService.cartNotifier,
      builder: (context, cart, _) {
        final visible = cart.isNotEmpty;
        final itemCount = cart.totalQuantity.toInt();
        final isOpen = storeSettings.isOpen;

        return AnimatedSlide(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          offset: visible ? Offset.zero : const Offset(0, 1.2),
          child: AnimatedOpacity(
            duration: MeatvoDurations.fast,
            opacity: visible ? 1 : 0,
            child: AnimatedScale(
              duration: const Duration(milliseconds: 280),
              curve: Curves.easeOutBack,
              scale: visible ? 1 : 0.92,
              child: IgnorePointer(
                ignoring: !visible,
                child: Container(
                  margin: EdgeInsets.symmetric(horizontal: mv.spacing.md),
                  child: Material(
                    elevation: 0,
                    borderRadius: BorderRadius.circular(mv.radii.navBar),
                    color: mv.brandPrimary,
                    shadowColor: mv.brandPrimary.withValues(alpha: 0.3),
                    child: InkWell(
                      onTap: () {
                        if (!isOpen) {
                          StoreClosedSheet.show(context, storeSettings);
                          return;
                        }
                        widget.onViewCartTapped();
                      },
                      borderRadius: BorderRadius.circular(mv.radii.navBar),
                      child: Ink(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(mv.radii.navBar),
                          boxShadow: [
                            BoxShadow(
                              color: mv.brandPrimary.withValues(alpha: 0.25),
                              blurRadius: 16,
                              offset: const Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: mv.spacing.md,
                            vertical: mv.spacing.sm,
                          ),
                          child: Row(
                            children: [
                              ScaleTransition(
                                scale: _punchScale,
                                child: CartPillThumbnailStack(items: cart.items),
                              ),
                              SizedBox(width: mv.spacing.sm),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Text(
                                      isOpen ? 'View Cart' : 'Store closed',
                                      style: Theme.of(context)
                                          .textTheme
                                          .labelLarge
                                          ?.copyWith(
                                            color: Colors.white,
                                            fontWeight: FontWeight.w700,
                                          ),
                                    ),
                                    AnimatedSwitcher(
                                      duration: MeatvoDurations.fast,
                                      switchInCurve: MeatvoDurations.curve,
                                      switchOutCurve: MeatvoDurations.curve,
                                      transitionBuilder: (child, animation) {
                                        final offset = Tween<Offset>(
                                          begin: const Offset(0, 0.35),
                                          end: Offset.zero,
                                        ).animate(CurvedAnimation(
                                          parent: animation,
                                          curve: MeatvoDurations.curve,
                                        ));
                                        return FadeTransition(
                                          opacity: animation,
                                          child: SlideTransition(
                                            position: offset,
                                            child: child,
                                          ),
                                        );
                                      },
                                      child: Text(
                                        '$itemCount ${itemCount == 1 ? 'Item' : 'Items'}',
                                        key: ValueKey<int>(itemCount),
                                        style: Theme.of(context)
                                            .textTheme
                                            .labelSmall
                                            ?.copyWith(
                                              color: Colors.white
                                                  .withValues(alpha: 0.85),
                                            ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              Container(
                                width: 28,
                                height: 28,
                                decoration: BoxDecoration(
                                  color: isOpen
                                      ? mv.brandPrimaryDark
                                      : Colors.white.withValues(alpha: 0.15),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.chevron_right_rounded,
                                  color: Colors.white.withValues(
                                    alpha: isOpen ? 1 : 0.7,
                                  ),
                                  size: 20,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
