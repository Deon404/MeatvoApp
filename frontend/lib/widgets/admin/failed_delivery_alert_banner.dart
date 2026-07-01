import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Payload for failed-delivery admin tasks requiring manager resolution.
class FailedDeliveryAlertData {
  const FailedDeliveryAlertData({
    required this.orderId,
    required this.reason,
    required this.reasonLabel,
    this.returnedAt,
    this.returnCondition,
    this.awaitingReturn = true,
    this.taskId,
  });

  final int orderId;
  final String reason;
  final String reasonLabel;
  final String? returnedAt;
  final String? returnCondition;
  final bool awaitingReturn;
  final int? taskId;

  String get displayText {
    if (awaitingReturn) {
      return 'Order #$orderId — failed delivery ($reasonLabel). Awaiting rider return.';
    }
    final condition =
        returnCondition?.replaceAll('_', ' ').toLowerCase() ?? 'unknown';
    return 'Order #$orderId — returned ($condition). Choose Redeliver, Refund, or Discard.';
  }

  factory FailedDeliveryAlertData.fromSocket(dynamic data) {
    final map =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    return FailedDeliveryAlertData(
      orderId: _parseInt(map['orderId'] ?? map['order_id'] ?? map['id']),
      reason: map['reason']?.toString() ?? '',
      reasonLabel: map['reasonLabel']?.toString() ?? 'Failed delivery',
      returnedAt: map['returnedAt']?.toString(),
      returnCondition: map['returnCondition']?.toString(),
      awaitingReturn:
          map['awaitingReturn'] != false && map['returnedAt'] == null,
      taskId: _parseIntOrNull(map['taskId']),
    );
  }

  factory FailedDeliveryAlertData.fromTask(Map<String, dynamic> task) {
    final payload = task['payload'] is Map
        ? Map<String, dynamic>.from(task['payload'] as Map)
        : <String, dynamic>{};
    final orderId = _parseInt(task['order_id'] ?? task['orderId']);
    final returnedAt =
        task['returned_at']?.toString() ?? payload['returnedAt']?.toString();
    return FailedDeliveryAlertData(
      orderId: orderId,
      reason: task['failed_delivery_reason']?.toString() ??
          payload['reason']?.toString() ??
          '',
      reasonLabel: payload['reasonLabel']?.toString() ?? 'Failed delivery',
      returnedAt: returnedAt,
      returnCondition: task['return_condition']?.toString() ??
          payload['returnCondition']?.toString(),
      awaitingReturn: returnedAt == null || returnedAt.isEmpty,
      taskId: _parseIntOrNull(task['id']),
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static int? _parseIntOrNull(dynamic value) {
    final parsed = _parseInt(value);
    return parsed == 0 ? null : parsed;
  }
}

/// Single inline banner — no overlay stack on every screen open.
class FailedDeliveryPendingBanner extends StatelessWidget {
  const FailedDeliveryPendingBanner({
    super.key,
    required this.count,
    required this.onTap,
  });

  final int count;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: const Color(0xFFC0392B),
        borderRadius: BorderRadius.circular(10),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(10),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                const Icon(Icons.delivery_dining, color: Colors.white, size: 22),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    count == 1
                        ? '1 returned order needs action — tap to resolve'
                        : '$count returned orders need action — tap to review',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                const Icon(Icons.chevron_right, color: Colors.white, size: 22),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
