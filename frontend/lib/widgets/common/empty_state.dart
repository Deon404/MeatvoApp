import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_button.dart';

class EmptyStateWidget extends StatelessWidget {
  final String title;
  final String? message;
  final String? buttonLabel;
  final VoidCallback? onAction;
  final Widget? illustration;
  final bool fullScreen;

  const EmptyStateWidget({
    super.key,
    required this.title,
    this.message,
    this.buttonLabel,
    this.onAction,
    this.illustration,
    this.fullScreen = true,
  });

  factory EmptyStateWidget.cart({
    Key? key,
    String? buttonLabel,
    VoidCallback? onAction,
    bool fullScreen = true,
  }) {
    return EmptyStateWidget(
      key: key,
      title: 'Your cart is empty',
      message: 'Add fresh meats and essentials to get started.',
      buttonLabel: buttonLabel,
      onAction: onAction,
      fullScreen: fullScreen,
    );
  }

  factory EmptyStateWidget.orders({
    Key? key,
    String? buttonLabel,
    VoidCallback? onAction,
    bool fullScreen = true,
  }) {
    return EmptyStateWidget(
      key: key,
      title: 'No orders yet! Time to treat yourself 🍗',
      message: 'Your order history will appear here once you place your first order.',
      buttonLabel: buttonLabel,
      onAction: onAction,
      fullScreen: fullScreen,
    );
  }

  factory EmptyStateWidget.wishlist({
    Key? key,
    String? buttonLabel,
    VoidCallback? onAction,
    bool fullScreen = true,
  }) {
    return EmptyStateWidget(
      key: key,
      title: 'Your wishlist is empty',
      message: 'Save your favorite cuts here for quick reordering later.',
      buttonLabel: buttonLabel,
      onAction: onAction,
      fullScreen: fullScreen,
    );
  }

  factory EmptyStateWidget.search({
    Key? key,
    String? buttonLabel,
    VoidCallback? onAction,
    bool fullScreen = true,
  }) {
    return EmptyStateWidget(
      key: key,
      title: 'No products found',
      message: 'Try a different keyword or clear the active filters.',
      buttonLabel: buttonLabel,
      onAction: onAction,
      fullScreen: fullScreen,
    );
  }

  factory EmptyStateWidget.comingSoon({
    Key? key,
    required String categoryName,
    bool fullScreen = false,
  }) {
    return EmptyStateWidget(
      key: key,
      title: '$categoryName — Coming Soon',
      message:
          'Fresh $categoryName items are on the way. Swipe to browse other categories or check back soon.',
      fullScreen: fullScreen,
      illustration: Container(
        width: 88,
        height: 88,
        decoration: BoxDecoration(
          color: AppThemeColors.primary.withValues(alpha: 0.08),
          shape: BoxShape.circle,
        ),
        child: const Icon(
          Icons.schedule_rounded,
          size: 40,
          color: AppThemeColors.primary,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Local captures so the bangs (`message!`, `buttonLabel!`) disappear.
    // The originals were guarded by an `if (message != null)`, but Dart
    // CANNOT smart-cast across the spread (`...[]`) boundary because
    // `message` is a getter — so `message!` could still throw if the
    // parent rebuilt with null on the exact frame the spread was being
    // expanded.
    final localMessage = message;
    final localButtonLabel = buttonLabel;
    final localAction = onAction;
    final hasMessage = localMessage != null && localMessage.trim().isNotEmpty;
    final hasButton = localButtonLabel != null &&
        localButtonLabel.isNotEmpty &&
        localAction != null;

    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            illustration ?? _defaultIllustration(),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppThemeColors.textPrimary,
                  ),
            ),
            if (hasMessage) ...[
              const SizedBox(height: AppSpacing.sm),
              Text(
                localMessage,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppThemeColors.textSecondary,
                    ),
              ),
            ],
            if (hasButton) ...[
              const SizedBox(height: AppSpacing.lg),
              AppButton.primary(
                localButtonLabel,
                localAction,
              ),
            ],
          ],
        ),
      ),
    );

    if (fullScreen) {
      return SizedBox.expand(child: content);
    }

    return content;
  }

  Widget _defaultIllustration() {
    return Container(
      width: 80,
      height: 80,
      decoration: const BoxDecoration(
        color: AppThemeColors.surface2,
        shape: BoxShape.circle,
      ),
      child: const Icon(
        Icons.inventory_2_outlined,
        size: 36,
        color: AppThemeColors.primary,
      ),
    );
  }
}
