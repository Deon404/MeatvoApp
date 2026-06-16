import 'package:flutter/material.dart';
import '../animations/animated_button.dart';
import '../../core/constants/app_constants.dart';
import '../../utils/haptic_feedback.dart';

/// Premium error state widget with retry option
class ErrorStateWidget extends StatelessWidget {
  final String message;
  final String? title;
  final VoidCallback? onRetry;
  final IconData? icon;
  final Color? iconColor;

  const ErrorStateWidget({
    super.key,
    required this.message,
    this.title,
    this.onRetry,
    this.icon,
    this.iconColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Error icon
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: (iconColor ?? Colors.red).withValues(alpha: 0.1),
              ),
              child: Icon(
                icon ?? Icons.error_outline,
                size: 50,
                color: iconColor ?? Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            // Title
            if (title != null) ...[
              Text(
                title!,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 12),
            ],
            // Error message
            Text(
              message,
              style: const TextStyle(
                fontSize: 16,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 32),
              // Retry button
              AnimatedButton(
                onPressed: () {
                  HapticUtils.mediumImpact();
                  onRetry?.call();
                },
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                height: 48,
                width: 200,
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.refresh, size: 20),
                    SizedBox(width: 8),
                    Text('Retry'),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// Network error widget
class NetworkErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const NetworkErrorWidget({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorStateWidget(
      title: 'Connection Error',
      message: 'Unable to connect to the server. Please check your internet connection and try again.',
      icon: Icons.wifi_off,
      iconColor: AppColors.warning,
      onRetry: onRetry,
    );
  }
}

/// Server error widget
class ServerErrorWidget extends StatelessWidget {
  final VoidCallback? onRetry;

  const ServerErrorWidget({
    super.key,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorStateWidget(
      title: 'Server Error',
      message: 'Something went wrong on our end. Please try again in a few moments.',
      icon: Icons.cloud_off,
      iconColor: Colors.red,
      onRetry: onRetry,
    );
  }
}

/// Generic error widget
class GenericErrorWidget extends StatelessWidget {
  final String message;
  final VoidCallback? onRetry;

  const GenericErrorWidget({
    super.key,
    required this.message,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return ErrorStateWidget(
      message: message,
      icon: Icons.error_outline,
      iconColor: Colors.red,
      onRetry: onRetry,
    );
  }
}

