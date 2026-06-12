import 'package:flutter/material.dart';
import 'package:shimmer/shimmer.dart';

import '../../constants/home_strings.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';

/// Minimal centered offline state — no large error cards.
class OfflineStateView extends StatefulWidget {
  const OfflineStateView({
    super.key,
    required this.onRetry,
    this.isRetrying = false,
    this.compact = false,
  });

  final VoidCallback onRetry;
  final bool isRetrying;
  final bool compact;

  @override
  State<OfflineStateView> createState() => _OfflineStateViewState();
}

class _OfflineStateViewState extends State<OfflineStateView>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulse;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final iconSize = widget.compact ? 56.0 : 72.0;

    return Center(
      child: Padding(
        padding: EdgeInsets.all(mv.spacing.xl),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FadeTransition(
              opacity: Tween(begin: 0.85, end: 1.0).animate(_pulse),
              child: Icon(
                Icons.cloud_off_rounded,
                size: iconSize,
                color: mv.textMuted,
              ),
            ),
            SizedBox(height: mv.spacing.md),
            Text(
              HomeStrings.offlineTitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(
                    color: mv.textPrimary,
                    fontWeight: FontWeight.w600,
                  ),
            ),
            SizedBox(height: mv.spacing.xs),
            Text(
              HomeStrings.offlineSubtitle,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: mv.textSecondary,
                  ),
            ),
            SizedBox(height: mv.spacing.lg),
            _RetryButton(
              onRetry: widget.onRetry,
              isRetrying: widget.isRetrying,
            ),
          ],
        ),
      ),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({
    required this.onRetry,
    required this.isRetrying,
  });

  final VoidCallback onRetry;
  final bool isRetrying;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;

    final button = ElevatedButton.icon(
      onPressed: isRetrying ? null : onRetry,
      icon: const Icon(Icons.refresh_rounded, size: 20),
      label: Text(HomeStrings.retryLabel),
      style: ElevatedButton.styleFrom(
        backgroundColor: mv.brandPrimary,
        foregroundColor: Colors.white,
        minimumSize: const Size(160, 48),
      ),
    );

    if (!isRetrying) return button;

    return Shimmer.fromColors(
      baseColor: mv.brandPrimary.withValues(alpha: 0.4),
      highlightColor: mv.brandPrimary,
      child: button,
    );
  }
}
