import 'dart:async';
import 'dart:collection';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';

/// Payload for a single new-order alert shown in the admin overlay banner.
class NewOrderAlertData {
  const NewOrderAlertData({
    required this.orderId,
    required this.customerLabel,
    required this.totalAmount,
  });

  final int orderId;
  final String customerLabel;
  final double totalAmount;

  String get displayText =>
      'New Order #$orderId — ₹${_formatAmount(totalAmount)} — $customerLabel';

  static String _formatAmount(double amount) {
    if (amount == amount.roundToDouble()) {
      return amount.toStringAsFixed(0);
    }
    return amount.toStringAsFixed(2);
  }

  factory NewOrderAlertData.fromSocket(dynamic data) {
    final map = data is Map ? Map<String, dynamic>.from(data) : <String, dynamic>{};
    final orderId = _parseInt(map['orderId'] ?? map['order_id'] ?? map['id']);
    final totalAmount = _parseDouble(
      map['totalAmount'] ?? map['total_amount'] ?? map['amount'],
    );
    final customerLabel = _resolveCustomerLabel(map);
    return NewOrderAlertData(
      orderId: orderId,
      customerLabel: customerLabel,
      totalAmount: totalAmount,
    );
  }

  static int _parseInt(dynamic value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? 0;
  }

  static double _parseDouble(dynamic value) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? 0;
  }

  static String _resolveCustomerLabel(Map<String, dynamic> map) {
    final name = map['customerName'] ?? map['customer_name'];
    if (name != null && name.toString().trim().isNotEmpty) {
      return name.toString().trim();
    }

    final phone = map['customerPhone'] ?? map['customer_phone'];
    if (phone != null && phone.toString().trim().isNotEmpty) {
      return phone.toString().trim();
    }

    final customerId = map['customerId'] ?? map['customer_id'];
    if (customerId != null && customerId.toString().trim().isNotEmpty) {
      return 'Customer #${customerId.toString().trim()}';
    }

    return 'Customer';
  }
}

/// Manages queued new-order overlay banners above the admin dashboard.
class AdminNewOrderAlertController {
  AdminNewOrderAlertController({
    required this.overlayState,
    required this.onTap,
    this.onDismissed,
  });

  final OverlayState overlayState;
  final void Function(NewOrderAlertData alert) onTap;
  final VoidCallback? onDismissed;

  static const _bannerColor = Color(0xFFC8102E);
  static const _slideDuration = Duration(milliseconds: 300);
  static const _visibleDuration = Duration(seconds: 5);

  final Queue<NewOrderAlertData> _queue = Queue<NewOrderAlertData>();
  final AudioPlayer _audioPlayer = AudioPlayer();

  OverlayEntry? _entry;
  bool _showing = false;
  bool _disposed = false;

  void enqueue(NewOrderAlertData alert) {
    if (_disposed) return;
    _queue.add(alert);
    unawaited(_playNotificationSound());
    if (!_showing) {
      _showNext();
    }
  }

  Future<void> _playNotificationSound() async {
    try {
      await _audioPlayer.stop();
      await _audioPlayer.play(AssetSource('sounds/new_order.wav'));
    } catch (_) {
      // Sound is best-effort; banner still shows without it.
    }
  }

  void _showNext() {
    if (_disposed || _showing || _queue.isEmpty) return;

    _showing = true;
    final alert = _queue.removeFirst();

    _entry?.remove();
    _entry = OverlayEntry(
      builder: (context) => _NewOrderAlertBannerOverlay(
        key: ValueKey('new_order_${alert.orderId}_${DateTime.now().millisecondsSinceEpoch}'),
        alert: alert,
        bannerColor: _bannerColor,
        slideDuration: _slideDuration,
        visibleDuration: _visibleDuration,
        onFinished: (tapped) => _handleBannerFinished(alert, tapped),
      ),
    );

    overlayState.insert(_entry!);
  }

  void _handleBannerFinished(NewOrderAlertData alert, bool tapped) {
    if (_disposed) return;

    _entry?.remove();
    _entry = null;
    _showing = false;
    onDismissed?.call();

    if (tapped) {
      onTap(alert);
    }

    if (_queue.isNotEmpty) {
      _showNext();
    }
  }

  void dispose() {
    _disposed = true;
    _queue.clear();
    _entry?.remove();
    _entry = null;
    unawaited(_audioPlayer.dispose());
  }
}

class _NewOrderAlertBannerOverlay extends StatefulWidget {
  const _NewOrderAlertBannerOverlay({
    super.key,
    required this.alert,
    required this.bannerColor,
    required this.slideDuration,
    required this.visibleDuration,
    required this.onFinished,
  });

  final NewOrderAlertData alert;
  final Color bannerColor;
  final Duration slideDuration;
  final Duration visibleDuration;
  final void Function(bool tapped) onFinished;

  @override
  State<_NewOrderAlertBannerOverlay> createState() =>
      _NewOrderAlertBannerOverlayState();
}

class _NewOrderAlertBannerOverlayState extends State<_NewOrderAlertBannerOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  Timer? _autoDismissTimer;
  bool _finished = false;

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
      reverseCurve: Curves.easeInCubic,
    ));

    _controller.forward();
    _autoDismissTimer = Timer(widget.visibleDuration, () {
      _finish(tapped: false);
    });
  }

  Future<void> _finish({required bool tapped}) async {
    if (_finished || !mounted) return;
    _finished = true;
    _autoDismissTimer?.cancel();

    if (_controller.status != AnimationStatus.dismissed) {
      await _controller.reverse();
    }

    if (mounted) {
      widget.onFinished(tapped);
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SlideTransition(
        position: _slideAnimation,
        child: Material(
          color: Colors.transparent,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 0),
              child: GestureDetector(
                onTap: () => _finish(tapped: true),
                child: Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
                      const Icon(Icons.notifications_active,
                          color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Expanded(
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
                      const Icon(Icons.chevron_right, color: Colors.white70),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
