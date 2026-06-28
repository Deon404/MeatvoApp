import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';
import '../../services/admin_service.dart';

class CapacitySuggestionCard extends StatelessWidget {
  const CapacitySuggestionCard({
    super.key,
    required this.suggestion,
    required this.onApply,
    required this.onDismiss,
    this.isApplying = false,
    this.isDismissing = false,
  });

  final CapacitySuggestion suggestion;
  final VoidCallback onApply;
  final VoidCallback onDismiss;
  final bool isApplying;
  final bool isDismissing;

  Color get _severityColor {
    switch (suggestion.severity.toUpperCase()) {
      case 'CRITICAL':
        return AppColors.primary;
      case 'WARNING':
        return AppColors.warning;
      default:
        return AppColors.success;
    }
  }

  @override
  Widget build(BuildContext context) {
    final bullets = suggestion.reasonBullets;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _severityColor.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: _severityColor.withValues(alpha: 0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.lightbulb_outline, color: _severityColor),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      suggestion.headline,
                      style: const TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Recommendation only — store mode will not change automatically.',
                      style: TextStyle(
                        color: AppColors.textSecondary.withValues(alpha: 0.9),
                        fontSize: 12,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          if (bullets.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              'Reasons:',
              style: TextStyle(
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary.withValues(alpha: 0.95),
                fontSize: 13,
              ),
            ),
            const SizedBox(height: 6),
            ...bullets.map(
              (line) => Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '• ',
                      style: TextStyle(
                        color: _severityColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Expanded(
                      child: Text(
                        line,
                        style: const TextStyle(fontSize: 13),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: isDismissing || isApplying ? null : onDismiss,
                  child: isDismissing
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('Dismiss 30 min'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: isApplying || isDismissing ? null : onApply,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: AppColors.white,
                  ),
                  child: isApplying
                      ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Apply',
                          style: TextStyle(color: AppColors.white),
                        ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
