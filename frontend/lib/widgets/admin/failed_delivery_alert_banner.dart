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
    final condition = returnCondition?.replaceAll('_', ' ').toLowerCase() ?? 'unknown';
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
      awaitingReturn: map['awaitingReturn'] != false && map['returnedAt'] == null,
      taskId: _parseIntOrNull(map['taskId']),
    );
  }

  factory FailedDeliveryAlertData.fromTask(Map<String, dynamic> task) {
    final payload = task['payload'] is Map
        ? Map<String, dynamic>.from(task['payload'] as Map)
        : <String, dynamic>{};
    final orderId = _parseInt(task['order_id'] ?? task['orderId']);
    final returnedAt = task['returned_at']?.toString() ?? payload['returnedAt']?.toString();
    return FailedDeliveryAlertData(
      orderId: orderId,
      reason: task['failed_delivery_reason']?.toString() ?? payload['reason']?.toString() ?? '',
      reasonLabel: payload['reasonLabel']?.toString() ?? 'Failed delivery',
      returnedAt: returnedAt,
      returnCondition: task['return_condition']?.toString() ?? payload['returnCondition']?.toString(),
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

/// Persistent failed-delivery warning banners for admin screens.
class AdminFailedDeliveryAlertController {
  AdminFailedDeliveryAlertController({
    required this.overlayState,
    required this.onTap,
    this.onDismissed,
  });

  final OverlayState overlayState;
  final void Function(FailedDeliveryAlertData alert) onTap;
  final void Function(int orderId)? onDismissed;

  static const _bannerColor = Color(0xFFC0392B);
  static const _slideDuration = Duration(milliseconds: 300);

  final Map<int, FailedDeliveryAlertData> _activeAlerts = {};
  OverlayEntry? _entry;
  bool _disposed = false;

  void show(FailedDeliveryAlertData alert) {
    if (_disposed || alert.orderId == 0) return;
    _activeAlerts[alert.orderId] = alert;
    _rebuildOverlay();
  }

  void syncFromTasks(List<FailedDeliveryAlertData> alerts) {
    if (_disposed) return;
    _activeAlerts
      ..clear()
      ..addEntries(alerts.map((a) => MapEntry(a.orderId, a)));
    _rebuildOverlay();
  }

  void dismiss(int orderId) {
    if (_disposed) return;
    if (!_activeAlerts.containsKey(orderId)) return;
    _activeAlerts.remove(orderId);
    onDismissed?.call(orderId);
    _rebuildOverlay();
  }

  void remove(int orderId) {
    if (_disposed) return;
    _activeAlerts.remove(orderId);
    _rebuildOverlay();
  }

  void dispose() {
    _disposed = true;
    _activeAlerts.clear();
    _entry?.remove();
    _entry = null;
  }

  void _rebuildOverlay() {
    _entry?.remove();
    _entry = null;

    if (_activeAlerts.isEmpty || _disposed) return;

    _entry = OverlayEntry(
      builder: (context) => _FailedDeliveryAlertStack(
        alerts: _activeAlerts.values.toList()
          ..sort((a, b) => b.orderId.compareTo(a.orderId)),
        bannerColor: _bannerColor,
        slideDuration: _slideDuration,
        onTap: onTap,
        onDismiss: dismiss,
      ),
    );

    overlayState.insert(_entry!);
  }
}

class _FailedDeliveryAlertStack extends StatelessWidget {
  const _FailedDeliveryAlertStack({
    required this.alerts,
    required this.bannerColor,
    required this.slideDuration,
    required this.onTap,
    required this.onDismiss,
  });

  final List<FailedDeliveryAlertData> alerts;
  final Color bannerColor;
  final Duration slideDuration;
  final void Function(FailedDeliveryAlertData alert) onTap;
  final void Function(int orderId) onDismiss;

  @override
  Widget build(BuildContext context) {
    final topInset = MediaQuery.of(context).padding.top;
    final topOffset = topInset + kToolbarHeight;
    return Positioned(
      top: topOffset,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (final alert in alerts)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _FailedDeliveryAlertBanner(
                    key: ValueKey('failed_delivery_${alert.orderId}'),
                    alert: alert,
                    bannerColor: bannerColor,
                    slideDuration: slideDuration,
                    onTap: () => onTap(alert),
                    onDismiss: () => onDismiss(alert.orderId),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FailedDeliveryAlertBanner extends StatefulWidget {
  const _FailedDeliveryAlertBanner({
    super.key,
    required this.alert,
    required this.bannerColor,
    required this.slideDuration,
    required this.onTap,
    required this.onDismiss,
  });

  final FailedDeliveryAlertData alert;
  final Color bannerColor;
  final Duration slideDuration;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_FailedDeliveryAlertBanner> createState() =>
      _FailedDeliveryAlertBannerState();
}

class _FailedDeliveryAlertBannerState extends State<_FailedDeliveryAlertBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: widget.slideDuration,
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOutCubic,
    ));
    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Material(
        color: Colors.transparent,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: widget.bannerColor,
            borderRadius: BorderRadius.circular(10),
            boxShadow: const [
              BoxShadow(
                color: Color(0x40000000),
                blurRadius: 8,
                offset: Offset(0, 4),
              ),
            ],
          ),
          child: Row(
            children: [
              const Icon(Icons.delivery_dining, color: Colors.white, size: 22),
              const SizedBox(width: 10),
              Expanded(
                child: GestureDetector(
                  onTap: widget.onTap,
                  child: Text(
                    widget.alert.displayText,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              if (!widget.alert.awaitingReturn)
                IconButton(
                  onPressed: widget.onDismiss,
                  icon: const Icon(Icons.close, color: Colors.white, size: 20),
                  tooltip: 'Dismiss',
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
