import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../staff_theme.dart';

class StaffOrderCard extends StatelessWidget {
  const StaffOrderCard({
    super.key,
    required this.order,
    required this.isUpdating,
    required this.onStartPreparing,
    required this.onMarkReady,
  });

  final Map<String, dynamic> order;
  final bool isUpdating;
  final VoidCallback? onStartPreparing;
  final VoidCallback? onMarkReady;

  @override
  Widget build(BuildContext context) {
    final orderId = order['id']?.toString() ?? '';
    final status = (order['status'] ?? '').toString().toLowerCase();
    final items = (order['items'] as List<dynamic>? ?? const [])
        .whereType<Map<String, dynamic>>()
        .toList();
    final slot = order['deliverySlot']?.toString();
    final createdAt = _formatCreatedAt(order);

    return Container(
      margin: const EdgeInsets.only(bottom: StaffSpacing.md),
      decoration: BoxDecoration(
        color: StaffColors.surface,
        borderRadius: BorderRadius.circular(StaffRadius.card),
        border: Border.all(color: StaffColors.border),
      ),
      child: Padding(
        padding: const EdgeInsets.all(StaffSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text('Order #$orderId', style: StaffTextStyles.h2),
                ),
                _StatusChip(status: status),
              ],
            ),
            if (createdAt != null) ...[
              const SizedBox(height: StaffSpacing.xs),
              Text(createdAt, style: StaffTextStyles.caption),
            ],
            if (slot != null && slot.isNotEmpty) ...[
              const SizedBox(height: StaffSpacing.xs),
              Row(
                children: [
                  const Icon(
                    Icons.schedule,
                    size: 14,
                    color: StaffColors.textSecondary,
                  ),
                  const SizedBox(width: StaffSpacing.xs),
                  Expanded(
                    child: Text(slot, style: StaffTextStyles.caption),
                  ),
                ],
              ),
            ],
            const SizedBox(height: StaffSpacing.sm),
            ...items.map((item) {
              final name = item['name']?.toString() ?? 'Item';
              final qty = item['quantity']?.toString() ?? '0';
              return Padding(
                padding: const EdgeInsets.only(bottom: StaffSpacing.xs),
                child: Row(
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: StaffColors.accent,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: StaffSpacing.sm),
                    Expanded(
                      child: Text('$name x$qty', style: StaffTextStyles.body),
                    ),
                  ],
                ),
              );
            }),
            const SizedBox(height: StaffSpacing.md),
            if (status == 'confirmed')
              _StaffActionButton(
                label: 'Start Preparing',
                onPressed: isUpdating ? null : onStartPreparing,
                isLoading: isUpdating,
              )
            else if (status == 'packing_started')
              _StaffActionButton(
                label: 'Mark Ready',
                onPressed: isUpdating ? null : onMarkReady,
                isLoading: isUpdating,
                outlined: true,
              ),
          ],
        ),
      ),
    );
  }

  String? _formatCreatedAt(Map<String, dynamic> order) {
    final ms = order['createdAtMs'];
    if (ms is int && ms > 0) {
      return DateFormat('MMM d, h:mm a')
          .format(DateTime.fromMillisecondsSinceEpoch(ms));
    }
    final raw = order['createdAt'];
    if (raw is String && raw.isNotEmpty) {
      try {
        return DateFormat('MMM d, h:mm a').format(DateTime.parse(raw));
      } catch (_) {
        return raw;
      }
    }
    return null;
  }
}

class _StaffActionButton extends StatelessWidget {
  const _StaffActionButton({
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.outlined = false,
  });

  final String label;
  final VoidCallback? onPressed;
  final bool isLoading;
  final bool outlined;

  @override
  Widget build(BuildContext context) {
    final enabled = onPressed != null && !isLoading;
    return SizedBox(
      width: double.infinity,
      height: 48,
      child: Material(
        color: outlined ? Colors.transparent : StaffColors.accent,
        borderRadius: BorderRadius.circular(StaffRadius.button),
        child: InkWell(
          onTap: enabled ? onPressed : null,
          borderRadius: BorderRadius.circular(StaffRadius.button),
          child: Ink(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(StaffRadius.button),
              border: outlined
                  ? Border.all(color: StaffColors.accent, width: 1.5)
                  : null,
              color: outlined ? Colors.transparent : StaffColors.accent,
            ),
            child: Center(
              child: isLoading
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.5,
                        color: StaffColors.textPrimary,
                      ),
                    )
                  : Text(label, style: StaffTextStyles.button),
            ),
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.status});

  final String status;

  @override
  Widget build(BuildContext context) {
    final label = switch (status) {
      'confirmed' => 'New',
      'packing_started' => 'Preparing',
      _ => status,
    };

    final isPreparing = status == 'packing_started';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: isPreparing ? StaffColors.chipPreparingBg : Colors.transparent,
        borderRadius: BorderRadius.circular(StaffRadius.chip),
        border: Border.all(
          color: isPreparing ? StaffColors.accent : StaffColors.chipNewBorder,
        ),
      ),
      child: Text(
        label,
        style: StaffTextStyles.caption.copyWith(
          color: isPreparing ? StaffColors.accent : StaffColors.textPrimary,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
