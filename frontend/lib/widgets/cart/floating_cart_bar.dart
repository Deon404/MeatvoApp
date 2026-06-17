import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../domain/order_pricing.dart';
import '../../models/cart_model.dart';
import '../../providers/store_settings_provider.dart';
import '../../services/cart_service.dart';
import '../../widgets/store/store_closed_sheet.dart';

/// Floating pill cart bar with shared cart state.
class FloatingCartBar extends ConsumerWidget {
  const FloatingCartBar({
    super.key,
    required this.onViewCartTapped,
  });

  final VoidCallback onViewCartTapped;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final mv = context.meatvo;
    final storeSettings = ref.watch(storeSettingsSyncProvider);

    return ValueListenableBuilder<CartModel>(
      valueListenable: CartService.cartNotifier,
      builder: (context, cart, _) {
        final visible = cart.isNotEmpty;
        final itemCount = cart.totalQuantity.toInt();
        final subtotal = cart.subtotal;
        final pricing = OrderPricingCalculator.calculate(
          subtotal: subtotal,
          deliveryChargeAmount: storeSettings.deliveryFee,
        );
        final total = pricing.grandTotal;

        return AnimatedSlide(
          duration: const Duration(milliseconds: 280),
          curve: Curves.easeOutCubic,
          offset: visible ? Offset.zero : const Offset(0, 1.2),
          child: AnimatedOpacity(
            duration: const Duration(milliseconds: 200),
            opacity: visible ? 1 : 0,
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
                      if (!storeSettings.isOpen) {
                        StoreClosedSheet.show(context, storeSettings);
                        return;
                      }
                      onViewCartTapped();
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
                          horizontal: mv.spacing.lg,
                          vertical: mv.spacing.sm,
                        ),
                        child: Row(
                          children: [
                            Stack(
                              clipBehavior: Clip.none,
                              children: [
                                Container(
                                  padding: EdgeInsets.all(mv.spacing.xs),
                                  decoration: BoxDecoration(
                                    color: Colors.white.withValues(alpha: 0.2),
                                    borderRadius:
                                        BorderRadius.circular(mv.radii.sm),
                                  ),
                                  child: Icon(
                                    Icons.shopping_bag_outlined,
                                    color: Colors.white,
                                    size: 22,
                                  ),
                                ),
                                if (itemCount > 0)
                                  Positioned(
                                    right: -4,
                                    top: -4,
                                    child: Container(
                                      padding: const EdgeInsets.all(4),
                                      decoration: BoxDecoration(
                                        color: mv.freshBadge,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: mv.brandPrimary,
                                          width: 1.5,
                                        ),
                                      ),
                                      constraints: const BoxConstraints(
                                        minWidth: 18,
                                        minHeight: 18,
                                      ),
                                      child: Center(
                                        child: Text(
                                          itemCount > 99 ? '99+' : '$itemCount',
                                          style: Theme.of(context)
                                              .textTheme
                                              .labelSmall
                                              ?.copyWith(
                                                color: Colors.white,
                                                fontWeight: FontWeight.w700,
                                              ),
                                          textAlign: TextAlign.center,
                                        ),
                                      ),
                                    ),
                                  ),
                              ],
                            ),
                            SizedBox(width: mv.spacing.sm),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '$itemCount ${itemCount == 1 ? 'item' : 'items'}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .labelSmall
                                        ?.copyWith(
                                          color:
                                              Colors.white.withValues(alpha: 0.9),
                                        ),
                                  ),
                                  Text(
                                    '₹${total.toStringAsFixed(0)}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleSmall
                                        ?.copyWith(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w800,
                                        ),
                                  ),
                                ],
                              ),
                            ),
                            Text(
                              storeSettings.isOpen ? 'View Cart' : 'Store closed',
                              style:
                                  Theme.of(context).textTheme.labelLarge?.copyWith(
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                            ),
                            SizedBox(width: mv.spacing.xs),
                            Icon(
                              Icons.arrow_forward_rounded,
                              color: Colors.white,
                              size: 18,
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
        );
      },
    );
  }
}
