import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';

/// Premium empty state widget with illustration, title, description, and action
class EmptyStateWidget extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;
  final String? actionLabel;
  final VoidCallback? onAction;
  final Color? iconColor;
  final double iconSize;

  const EmptyStateWidget({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    this.actionLabel,
    this.onAction,
    this.iconColor,
    this.iconSize = 80,
  });

  @override
  Widget build(BuildContext context) {
    // Smart-cast locals — `actionLabel!` and `onAction!` bangs removed.
    // Instance fields cannot be promoted across `if` boundaries; the
    // locals let Dart treat them as non-null inside the block.
    final label = actionLabel;
    final action = onAction;
    final showAction = label != null && action != null;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          mainAxisSize: MainAxisSize.min,
          children: [
            // Icon with gradient background
            Container(
              width: iconSize + 40,
              height: iconSize + 40,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    (iconColor ?? AppColors.primary).withValues(alpha: 0.1),
                    (iconColor ?? AppColors.primary).withValues(alpha: 0.05),
                  ],
                ),
              ),
              child: Icon(
                icon,
                size: iconSize,
                color: iconColor ?? AppColors.primary,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            Text(
              title,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: AppColors.textPrimary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 12),
            // Description
            Text(
              description,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (showAction) ...[
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: action,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: AppColors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 32,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 2,
                ),
                child: Text(
                  label,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Empty cart state
class EmptyCartWidget extends StatelessWidget {
  final VoidCallback? onStartShopping;

  const EmptyCartWidget({
    super.key,
    this.onStartShopping,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.shopping_cart_outlined,
      title: 'Your cart is empty',
      description: 'Add some delicious items to your cart and we\'ll deliver them fresh to your doorstep!',
      actionLabel: 'Start Shopping',
      onAction: onStartShopping,
      iconColor: AppColors.primary,
    );
  }
}

/// Empty orders state
class EmptyOrdersWidget extends StatelessWidget {
  const EmptyOrdersWidget({super.key});

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.receipt_long_outlined,
      title: 'No orders yet',
      description: 'Your order history will appear here once you place your first order.',
      iconColor: AppColors.bluePrimary,
    );
  }
}

/// Empty search results state
class EmptySearchWidget extends StatelessWidget {
  final String query;

  const EmptySearchWidget({
    super.key,
    required this.query,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.search_off,
      title: 'No results found',
      description: 'We couldn\'t find any products matching "$query". Try searching with different keywords.',
      iconColor: AppColors.surface,
    );
  }
}

/// Empty wishlist state
class EmptyWishlistWidget extends StatelessWidget {
  final VoidCallback? onStartShopping;

  const EmptyWishlistWidget({
    super.key,
    this.onStartShopping,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.favorite_border,
      title: 'Your wishlist is empty',
      description: 'Save your favorite products here for quick access later!',
      actionLabel: 'Browse Products',
      onAction: onStartShopping,
      iconColor: AppColors.primary,
    );
  }
}

/// No internet state
class NoInternetWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NoInternetWidget({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return EmptyStateWidget(
      icon: Icons.wifi_off,
      title: 'No Internet Connection',
      description: 'Please check your internet connection and try again.',
      actionLabel: 'Retry',
      onAction: onRetry,
      iconColor: AppColors.warning,
    );
  }
}

