import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'app_button.dart';

class ErrorStateWidget extends StatelessWidget {
  final String title;
  final String? message;
  final String buttonLabel;
  final VoidCallback onRetry;
  final bool fullScreen;
  final IconData icon;
  final Color? iconColor;

  const ErrorStateWidget({
    super.key,
    required this.title,
    this.message,
    this.buttonLabel = 'Try Again',
    required this.onRetry,
    this.fullScreen = true,
    this.icon = Icons.wifi_off_rounded,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    final content = Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: const BoxDecoration(
                color: AppThemeColors.surface2,
                shape: BoxShape.circle,
              ),
              child: Icon(
                icon,
                size: 36,
                color: iconColor ?? AppThemeColors.warning,
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              title,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    color: AppThemeColors.textPrimary,
                  ),
            ),
            // Local capture removes the two `message!` bangs. The
            // surrounding spread (`...[]`) is a closure boundary in
            // disguise, so Dart cannot smart-cast a nullable instance
            // field across it — making the bang unsafe.
            ...(() {
              final localMessage = message;
              if (localMessage == null || localMessage.trim().isEmpty) {
                return const <Widget>[];
              }
              return <Widget>[
                const SizedBox(height: AppSpacing.sm),
                Text(
                  localMessage,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppThemeColors.textSecondary,
                      ),
                ),
              ];
            }()),
            const SizedBox(height: AppSpacing.lg),
            AppButton.primary(
              buttonLabel,
              onRetry,
            ),
          ],
        ),
      ),
    );

    if (fullScreen) {
      return SizedBox.expand(child: content);
    }

    return content;
  }
}
