import 'package:flutter/material.dart';

import '../../services/admin_service.dart';
import 'failed_delivery_alert_banner.dart';

/// Shows admin resolution choices for a returned failed-delivery order.
Future<String?> showFailedDeliveryResolutionDialog(
  BuildContext context,
  FailedDeliveryAlertData alert,
) {
  return showDialog<String>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text('Resolve Order #${alert.orderId}'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Reason: ${alert.reasonLabel}'),
          if (alert.returnCondition != null) ...[
            const SizedBox(height: 8),
            Text(
              'Condition: ${alert.returnCondition!.replaceAll('_', ' ')}',
            ),
          ],
          const SizedBox(height: 16),
          const Text('Choose how to resolve this failed delivery:'),
        ],
      ),
        actions: [
          if (!alert.awaitingReturn) ...[
            TextButton(
              onPressed: () => Navigator.pop(context, 'REDELIVER'),
              child: const Text('Redeliver'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'REFUND'),
              child: const Text('Refund'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, 'DISCARD'),
              child: const Text('Discard'),
            ),
          ],
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
    ),
  );
}

/// Resolves a failed delivery task and shows feedback snackbars.
Future<bool> resolveFailedDeliveryAlert(
  BuildContext context, {
  required AdminService adminService,
  required FailedDeliveryAlertData alert,
  required String resolution,
  void Function(int orderId)? onResolved,
}) async {
  try {
    await adminService.resolveFailedDelivery(
      alert.orderId.toString(),
      resolution,
    );
    onResolved?.call(alert.orderId);
    if (!context.mounted) return true;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Order #${alert.orderId} resolved ($resolution)'),
      ),
    );
    return true;
  } catch (e) {
    if (!context.mounted) return false;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(adminService.formatResolveError(e))),
    );
    return false;
  }
}

FailedDeliveryAlertData failedDeliveryAlertFromOrder(
  Map<String, dynamic> order,
) {
  final orderId = int.tryParse(order['id']?.toString() ?? '') ?? 0;
  final returnedAt =
      order['returned_at']?.toString() ?? order['returnedAt']?.toString();
  return FailedDeliveryAlertData(
    orderId: orderId,
    reason: order['failed_delivery_reason']?.toString() ?? '',
    reasonLabel:
        order['failed_delivery_reason']?.toString().replaceAll('_', ' ') ??
            'Failed delivery',
    returnedAt: returnedAt,
    returnCondition: order['return_condition']?.toString() ??
        order['returnCondition']?.toString(),
    awaitingReturn: returnedAt == null || returnedAt.isEmpty,
  );
}
