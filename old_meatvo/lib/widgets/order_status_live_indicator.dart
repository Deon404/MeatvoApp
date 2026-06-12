import 'package:flutter/material.dart';
import '../core/constants/app_constants.dart';

const _stepRed = AppColors.primary;
const _stepPending = Color(0xFFEEEEEE);
const _stepPendingIcon = Color(0xFF9CA3AF);

/// Live order status indicator with pulsing animation
class OrderStatusLiveIndicator extends StatefulWidget {
  final String status;
  final String? previousStatus;
  final bool showLiveBadge;

  const OrderStatusLiveIndicator({
    super.key,
    required this.status,
    this.previousStatus,
    this.showLiveBadge = true,
  });

  @override
  State<OrderStatusLiveIndicator> createState() => _OrderStatusLiveIndicatorState();
}

class _OrderStatusLiveIndicatorState extends State<OrderStatusLiveIndicator>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 0.8, end: 1.0).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.previousStatus != null && widget.previousStatus != widget.status) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStatusChangeNotification();
      });
    }
  }

  @override
  void didUpdateWidget(OrderStatusLiveIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.status != widget.status) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _showStatusChangeNotification();
      });
    }
  }

  void _showStatusChangeNotification() {
    if (!mounted) return;

    final statusLabel = _getStatusLabel(widget.status);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.update, color: Colors.white),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Order status updated: $statusLabel',
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  String _getStatusLabel(String status) {
    switch (status.toLowerCase()) {
      case 'placed':
        return 'Order Placed';
      case 'confirmed':
      case 'accepted':
        return 'Order Confirmed';
      case 'preparing':
        return 'Preparing Your Order';
      case 'assigned':
        return 'Rider Assigned';
      case 'out_for_delivery':
      case 'on_way':
        return 'Out for Delivery';
      case 'delivered':
        return 'Delivered';
      case 'cancelled':
        return 'Cancelled';
      default:
        return status;
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (widget.showLiveBadge && _isActiveStatus(widget.status))
          AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Container(
                margin: const EdgeInsets.only(right: 8),
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.success.withValues(alpha: _pulseAnimation.value),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 6,
                      height: 6,
                      decoration: const BoxDecoration(
                        color: Colors.white,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Text(
                      'LIVE',
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
      ],
    );
  }

  bool _isActiveStatus(String status) {
    return !['delivered', 'cancelled'].contains(status.toLowerCase());
  }
}

class _TrackingStepCircle extends StatefulWidget {
  final bool isCompleted;
  final bool isActive;
  final String imageAsset;

  static const double size = 48;

  const _TrackingStepCircle({
    required this.isCompleted,
    required this.isActive,
    required this.imageAsset,
  });

  @override
  State<_TrackingStepCircle> createState() => _TrackingStepCircleState();
}

class _TrackingStepCircleState extends State<_TrackingStepCircle>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _initPulse();
  }

  @override
  void didUpdateWidget(_TrackingStepCircle oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isActive != widget.isActive) {
      _disposePulse();
      _initPulse();
    }
  }

  void _initPulse() {
    if (!widget.isActive) return;
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);
  }

  void _disposePulse() {
    _pulseController?.dispose();
    _pulseController = null;
  }

  @override
  void dispose() {
    _disposePulse();
    super.dispose();
  }

  Widget _buildStepImage({required bool isEnabled}) {
    Widget image = Image.asset(
      widget.imageAsset,
      width: _TrackingStepCircle.size,
      height: _TrackingStepCircle.size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stackTrace) => Container(
        width: _TrackingStepCircle.size,
        height: _TrackingStepCircle.size,
        color: _stepPending,
        child: Icon(
          Icons.image_not_supported_outlined,
          size: _TrackingStepCircle.size * 0.4,
          color: _stepPendingIcon,
        ),
      ),
    );

    if (!isEnabled) {
      image = Opacity(opacity: 0.42, child: image);
    }

    return ClipOval(child: image);
  }

  Widget _buildCircle({
    required bool isEnabled,
    required double borderOpacity,
    double scale = 1.0,
  }) {
    return Transform.scale(
      scale: scale,
      child: Container(
        width: _TrackingStepCircle.size,
        height: _TrackingStepCircle.size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: widget.isActive
                ? _stepRed.withValues(alpha: borderOpacity)
                : widget.isCompleted
                    ? _stepRed.withValues(alpha: 0.45)
                    : const Color(0xFFE0E0E0),
            width: widget.isActive ? 2.5 : 1.5,
          ),
          boxShadow: widget.isActive
              ? [
                  BoxShadow(
                    color: _stepRed.withValues(alpha: 0.18 + (borderOpacity * 0.2)),
                    blurRadius: 10,
                    spreadRadius: 1,
                  ),
                ]
              : null,
        ),
        child: _buildStepImage(isEnabled: isEnabled),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isEnabled = widget.isCompleted || widget.isActive;

    if (!widget.isActive || _pulseController == null) {
      return _buildCircle(isEnabled: isEnabled, borderOpacity: 1.0);
    }

    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        final borderOpacity = 0.35 + (_pulseController!.value * 0.65);
        return _buildCircle(
          isEnabled: isEnabled,
          borderOpacity: borderOpacity,
          scale: 1.0 + (_pulseController!.value * 0.06),
        );
      },
    );
  }
}

/// Returns the order-tracking illustration for a given order status.
String orderTrackingImageForStatus(String status) {
  final index = _resolveTrackingStepIndex(status);
  return _trackingSteps[index]['image'] as String;
}

int _resolveTrackingStepIndex(String status) {
  final s = status.toLowerCase();
  if (s == 'pending') return 0;
  if (s == 'placed') return 0;
  if (s == 'confirmed' || s == 'accepted') return 1;
  if (s == 'preparing' ||
      s == 'packed' ||
      s == 'assigned' ||
      s == 'picked_up') {
    return 2;
  }
  if (s == 'out_for_delivery' || s == 'on_way') return 3;
  if (s == 'delivered') return 4;
  return 0;
}

const _orderTrackingImageBase = 'assets/images/order_tracking';

const _trackingSteps = [
  {
    'status': 'placed',
    'label': 'Placed',
    'image': '$_orderTrackingImageBase/order_placed.png',
  },
  {
    'status': 'confirmed',
    'label': 'Confirmed',
    'image': '$_orderTrackingImageBase/order_confirmed.png',
  },
  {
    'status': 'preparing',
    'label': 'Preparing',
    'image': '$_orderTrackingImageBase/order_preparing.png',
  },
  {
    'status': 'out_for_delivery',
    'label': 'On the way',
    'image': '$_orderTrackingImageBase/order_on_the_way.png',
  },
  {
    'status': 'delivered',
    'label': 'Delivered',
    'image': '$_orderTrackingImageBase/order_delivered.png',
  },
];

/// Vertical status timeline for the standard (non-map) order detail view.
class StatusTimelineWidget extends StatelessWidget {
  final String currentStatus;
  final Map<String, DateTime?>? statusTimestamps;

  const StatusTimelineWidget({
    super.key,
    required this.currentStatus,
    this.statusTimestamps,
  });

  @override
  Widget build(BuildContext context) {
    final currentIndex = _resolveTrackingStepIndex(currentStatus);
    final isFullyComplete = currentStatus.toLowerCase() == 'delivered';

    return Column(
      children: List.generate(_trackingSteps.length, (index) {
        final step = _trackingSteps[index];
        final isCompleted = isFullyComplete || index < currentIndex;
        final isActive = !isFullyComplete && index == currentIndex;
        final statusKey = step['status'] as String;
        final timestamp = _resolveTimestamp(statusKey);

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: _TrackingStepCircle.size,
                child: Column(
                  children: [
                    _TrackingStepCircle(
                      isCompleted: isCompleted,
                      isActive: isActive,
                      imageAsset: step['image'] as String,
                    ),
                    if (index < _trackingSteps.length - 1)
                      Expanded(
                        child: Container(
                          width: 2,
                          margin: const EdgeInsets.symmetric(vertical: 4),
                          color: index < currentIndex ? _stepRed : _stepPending,
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Padding(
                  padding: EdgeInsets.only(
                    bottom: index < _trackingSteps.length - 1 ? 20 : 0,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        step['label'] as String,
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: isCompleted || isActive
                              ? AppColors.textDark
                              : AppColors.textMuted,
                        ),
                      ),
                      if (timestamp != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatTimestamp(timestamp),
                          style: const TextStyle(
                            fontSize: 12,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  DateTime? _resolveTimestamp(String statusKey) {
    return statusTimestamps?[statusKey];
  }

  String _formatTimestamp(DateTime timestamp) {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inHours < 1) {
      return '${difference.inMinutes} min ago';
    } else if (difference.inDays < 1) {
      return '${difference.inHours} hour${difference.inHours > 1 ? 's' : ''} ago';
    } else {
      return '${timestamp.day}/${timestamp.month}/${timestamp.year}';
    }
  }
}

/// Horizontal stepper for map-first order tracking.
class CompactStatusTimeline extends StatelessWidget {
  final String currentStatus;

  const CompactStatusTimeline({super.key, required this.currentStatus});

  @override
  Widget build(BuildContext context) {
    final currentIndex = _resolveTrackingStepIndex(currentStatus);
    final isFullyComplete = currentStatus.toLowerCase() == 'delivered';

    return Row(
      children: [
        for (int index = 0; index < _trackingSteps.length; index++) ...[
          if (index > 0)
            Expanded(
              child: Padding(
                padding: const EdgeInsets.only(bottom: 42),
                child: Container(
                  height: 2,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(1),
                    color: (isFullyComplete || index <= currentIndex)
                        ? _stepRed
                        : _stepPending,
                  ),
                ),
              ),
            ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _TrackingStepCircle(
                isCompleted: isFullyComplete || index < currentIndex,
                isActive: !isFullyComplete && index == currentIndex,
                imageAsset: _trackingSteps[index]['image'] as String,
              ),
              const SizedBox(height: 6),
              Text(
                _trackingSteps[index]['label'] as String,
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: index == currentIndex
                      ? FontWeight.w600
                      : FontWeight.w400,
                  color: index == currentIndex
                      ? _stepRed
                      : index < currentIndex || isFullyComplete
                          ? AppColors.textDark
                          : AppColors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }
}
