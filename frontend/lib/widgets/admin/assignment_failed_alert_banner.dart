import 'package:flutter/material.dart';

import '../../core/constants/app_constants.dart';

/// Payload for rider assignment failure alerts shown to admin.
class AssignmentFailedAlertData {
  const AssignmentFailedAlertData({
    required this.orderId,
    required this.attempts,
    this.taskId,
  });

  final int orderId;
  final int attempts;
  final int? taskId;

  String get displayText =>
      'Order #$orderId has no available rider after $attempts attempts';

  factory AssignmentFailedAlertData.fromSocket(dynamic data) {
    final map =
        data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    return AssignmentFailedAlertData(
      orderId: _parseInt(map['orderId'] ?? map['order_id'] ?? map['id']),
      attempts: _parseInt(map['attempts']) == 0 ? 3 : _parseInt(map['attempts']),
      taskId: _parseIntOrNull(map['taskId']),
    );
  }

  factory AssignmentFailedAlertData.fromTask(Map<String, dynamic> task) {
    final payload = task['payload'] is Map
        ? Map<String, dynamic>.from(task['payload'] as Map)
        : <String, dynamic>{};
    return AssignmentFailedAlertData(
      orderId: _parseInt(task['order_id'] ?? task['orderId']),
      attempts: _parseInt(payload['attempts']) == 0
          ? 3
          : _parseInt(payload['attempts']),
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

/// Manages persistent assignment-failure warning banners for admin screens.
///
/// Unlike [AdminNewOrderAlertController], these banners do not auto-dismiss and
/// use warning styling instead of the new-order red alert.
class AdminAssignmentFailedAlertController {
  AdminAssignmentFailedAlertController({
    required this.overlayState,
    required this.onTap,
    this.onResolve,
  });

  final OverlayState overlayState;
  final void Function(AssignmentFailedAlertData alert) onTap;
  final Future<void> Function(AssignmentFailedAlertData alert)? onResolve;

  static const _bannerColor = AppColors.warning;
  static const _slideDuration = Duration(milliseconds: 300);

  final Map<int, AssignmentFailedAlertData> _activeAlerts = {};
  OverlayEntry? _entry;
  bool _disposed = false;

  void show(AssignmentFailedAlertData alert) {
    if (_disposed || alert.orderId == 0) return;

    _activeAlerts[alert.orderId] = alert;
    _rebuildOverlay();
  }

  void syncFromTasks(List<AssignmentFailedAlertData> alerts) {
    if (_disposed) return;
    _activeAlerts
      ..clear()
      ..addEntries(alerts.map((a) => MapEntry(a.orderId, a)));
    _rebuildOverlay();
  }

  Future<void> resolve(AssignmentFailedAlertData alert) async {
    if (_disposed) return;
    await onResolve?.call(alert);
    _activeAlerts.remove(alert.orderId);
    _rebuildOverlay();
  }

  void dismiss(int orderId) {
    if (_disposed) return;
    if (!_activeAlerts.containsKey(orderId)) return;
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
      builder: (context) => _AssignmentFailedAlertStack(
        alerts: _activeAlerts.values.toList()
          ..sort((a, b) => b.orderId.compareTo(a.orderId)),
        bannerColor: _bannerColor,
        slideDuration: _slideDuration,
        onTap: onTap,
        onResolve: (alert) => resolve(alert),
      ),
    );

    overlayState.insert(_entry!);
  }
}

class _AssignmentFailedAlertStack extends StatelessWidget {
  const _AssignmentFailedAlertStack({
    required this.alerts,
    required this.bannerColor,
    required this.slideDuration,
    required this.onTap,
    required this.onResolve,
  });

  final List<AssignmentFailedAlertData> alerts;
  final Color bannerColor;
  final Duration slideDuration;
  final void Function(AssignmentFailedAlertData alert) onTap;
  final void Function(AssignmentFailedAlertData alert) onResolve;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
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
                  child: _AssignmentFailedAlertBanner(
                    key: ValueKey('assignment_failed_${alert.orderId}'),
                    alert: alert,
                    bannerColor: bannerColor,
                    slideDuration: slideDuration,
                    onTap: () => onTap(alert),
                    onDismiss: () => onResolve(alert),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AssignmentFailedAlertBanner extends StatefulWidget {
  const _AssignmentFailedAlertBanner({
    super.key,
    required this.alert,
    required this.bannerColor,
    required this.slideDuration,
    required this.onTap,
    required this.onDismiss,
  });

  final AssignmentFailedAlertData alert;
  final Color bannerColor;
  final Duration slideDuration;
  final VoidCallback onTap;
  final VoidCallback onDismiss;

  @override
  State<_AssignmentFailedAlertBanner> createState() =>
      _AssignmentFailedAlertBannerState();
}

class _AssignmentFailedAlertBannerState
    extends State<_AssignmentFailedAlertBanner>
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
            border: Border.all(color: const Color(0xFFD68910), width: 1),
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
              const Icon(
                Icons.warning_amber_rounded,
                color: Colors.white,
                size: 22,
              ),
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
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ),
              IconButton(
                onPressed: widget.onDismiss,
                icon: const Icon(Icons.close, color: Colors.white, size: 20),
                tooltip: 'Resolve',
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
