import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design_system/tokens/meatvo_colors.dart';
import '../utils/order_status_util.dart';

const _stepRed = MeatvoColors.brandPrimary;
const _stepPending = MeatvoColors.surfaceMuted;
const _stepPendingIcon = MeatvoColors.textMuted;

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

    HapticFeedback.lightImpact();
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
        backgroundColor: MeatvoColors.success,
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
                  color: MeatvoColors.success.withValues(alpha: _pulseAnimation.value),
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
  final IconData icon;

  static const double _size = 32;

  const _TrackingStepCircle({
    required this.isCompleted,
    required this.isActive,
    required this.icon,
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
      duration: const Duration(milliseconds: 800),
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

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: _TrackingStepCircle._size,
      height: _TrackingStepCircle._size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: widget.isCompleted || widget.isActive
            ? _stepRed
            : _stepPending,
      ),
      child: Icon(
        widget.icon,
        size: _TrackingStepCircle._size * 0.5,
        color: widget.isCompleted || widget.isActive
            ? Colors.white
            : _stepPendingIcon,
      ),
    );

    if (!widget.isActive || _pulseController == null) {
      return circle;
    }

    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController!.value * 0.15);
        return Transform.scale(scale: scale, child: child);
      },
      child: circle,
    );
  }
}

/// Returns the order-tracking illustration asset for a given order status.
String orderTrackingImageForStatus(String status) {
  final index = resolveTrackingStepIndex(status);
  final step = _trackingSteps[index];
  final image = step['image'];
  if (image is String && image.isNotEmpty) return image;
  final stepStatus = step['status'];
  if (stepStatus is String) {
    return 'assets/images/order_tracking/order_$stepStatus.png';
  }
  return 'assets/images/order_tracking/order_placed.png';
}

/// Icon for the tracking header when illustration assets are unavailable.
IconData orderTrackingIconForStatus(String status) {
  final index = resolveTrackingStepIndex(status);
  final icon = _trackingSteps[index]['icon'];
  return icon is IconData ? icon : Icons.receipt;
}

/// Headline shown in the map-first tracking header.
String orderTrackingHeadlineForStatus(String status, {String? riderName}) {
  final s = normalizeOrderStatus(status);
  switch (s) {
    case 'delivered':
      return 'Delivered';
    case 'cancelled':
    case 'failed_delivery':
      return 'Order cancelled';
    case 'rider_nearby':
      return 'Rider is nearby';
    case 'out_for_delivery':
      return 'On the way to you';
    case 'assigned':
      return riderName != null ? '$riderName is assigned' : 'Rider assigned';
    case 'picked_up':
      return 'Order picked up';
    case 'preparing':
      return 'Preparing your order';
    case 'confirmed':
      return 'Order confirmed';
    case 'placed':
    case 'pending':
      return 'Order placed';
    default:
      return 'Tracking your order';
  }
}

/// Status chip label for the bottom sheet header row.
String orderTrackingChipLabelForStatus(String status) {
  final s = normalizeOrderStatus(status);
  if (s == 'delivered') return 'Delivered';
  if (s == 'cancelled' || s == 'failed_delivery') return 'Cancelled';
  return 'Active';
}

const _trackingSteps = [
  {
    'status': 'placed',
    'label': 'Placed',
    'icon': Icons.receipt,
    'image': 'assets/images/order_tracking/order_placed.png',
  },
  {
    'status': 'confirmed',
    'label': 'Confirmed',
    'icon': Icons.check_circle,
    'image': 'assets/images/order_tracking/order_confirmed.png',
  },
  {
    'status': 'preparing',
    'label': 'Preparing',
    'icon': Icons.restaurant,
    'image': 'assets/images/order_tracking/order_preparing.png',
  },
  {
    'status': 'assigned',
    'label': 'Assigned',
    'icon': Icons.person_pin_circle,
    'image': 'assets/images/order_tracking/order_assigned.png',
  },
  {
    'status': 'out_for_delivery',
    'label': 'On the\nway',
    'icon': Icons.delivery_dining,
    'image': 'assets/images/order_tracking/order_on_the_way.png',
  },
  {
    'status': 'delivered',
    'label': 'Delivered',
    'icon': Icons.home,
    'image': 'assets/images/order_tracking/order_delivered.png',
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
    final currentIndex = resolveTrackingStepIndex(currentStatus);
    final isFullyComplete = normalizeOrderStatus(currentStatus) == 'delivered';

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
                width: _TrackingStepCircle._size,
                child: Column(
                  children: [
                    _TrackingStepCircle(
                      isCompleted: isCompleted,
                      isActive: isActive,
                      icon: step['icon'] as IconData,
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
                              ? MeatvoColors.textPrimary
                              : MeatvoColors.textMuted,
                        ),
                      ),
                      if (timestamp != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          _formatTimestamp(timestamp),
                          style: const TextStyle(
                            fontSize: 12,
                            color: MeatvoColors.textSecondary,
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

class _TrackingStepImage extends StatefulWidget {
  const _TrackingStepImage({
    required this.imagePath,
    required this.fallbackIcon,
    required this.isCompleted,
    required this.isActive,
    this.size = 56,
  });

  final String imagePath;
  final IconData fallbackIcon;
  final bool isCompleted;
  final bool isActive;
  final double size;

  @override
  State<_TrackingStepImage> createState() => _TrackingStepImageState();
}

class _TrackingStepImageState extends State<_TrackingStepImage>
    with SingleTickerProviderStateMixin {
  AnimationController? _pulseController;

  @override
  void initState() {
    super.initState();
    _initPulse();
  }

  @override
  void didUpdateWidget(covariant _TrackingStepImage oldWidget) {
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
      duration: const Duration(milliseconds: 900),
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

  @override
  Widget build(BuildContext context) {
    final opacity = widget.isCompleted || widget.isActive ? 1.0 : 0.35;
    final iconSize = widget.size;
    final cachePx = (iconSize * 3).round();

    Widget image = Opacity(
      opacity: opacity,
      child: Image.asset(
        widget.imagePath,
        width: iconSize,
        height: iconSize,
        fit: BoxFit.contain,
        filterQuality: FilterQuality.medium,
        cacheWidth: cachePx,
        cacheHeight: cachePx,
        errorBuilder: (_, __, ___) => Container(
          width: iconSize,
          height: iconSize,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: widget.isCompleted || widget.isActive
                ? _stepRed.withValues(alpha: 0.12)
                : _stepPending,
          ),
          child: Icon(
            widget.fallbackIcon,
            size: iconSize * 0.4,
            color: widget.isCompleted || widget.isActive
                ? _stepRed
                : _stepPendingIcon,
          ),
        ),
      ),
    );

    if (widget.isActive) {
      image = Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: _stepRed.withValues(alpha: 0.28),
              blurRadius: 16,
              spreadRadius: 4,
            ),
          ],
        ),
        child: image,
      );
    }

    if (!widget.isActive || _pulseController == null) return image;

    return AnimatedBuilder(
      animation: _pulseController!,
      builder: (context, child) {
        final scale = 1.0 + (_pulseController!.value * 0.06);
        return Transform.scale(scale: scale, child: child);
      },
      child: image,
    );
  }
}

/// Horizontal PNG stepper for map-first order tracking.
class OrderTrackingStepper extends StatelessWidget {
  final String currentStatus;

  const OrderTrackingStepper({super.key, required this.currentStatus});

  static const double _iconSize = 44;

  @override
  Widget build(BuildContext context) {
    final currentIndex = resolveTrackingStepIndex(currentStatus);
    final isFullyComplete = normalizeOrderStatus(currentStatus) == 'delivered';
    final isCancelled = isOrderCancelled(currentStatus);
    final stepCount = _trackingSteps.length;

    return LayoutBuilder(
      builder: (context, constraints) {
        final stepWidth = constraints.maxWidth / stepCount;
        const connectorTop = _iconSize / 2 - 1;

        return SizedBox(
          width: constraints.maxWidth,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                top: connectorTop,
                left: stepWidth / 2,
                right: stepWidth / 2,
                child: Row(
                  children: [
                    for (int i = 0; i < stepCount - 1; i++)
                      Expanded(
                        child: Container(
                          height: 2,
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(1),
                            color: _connectorColor(
                              index: i + 1,
                              currentIndex: currentIndex,
                              isFullyComplete: isFullyComplete,
                              isCancelled: isCancelled,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (int index = 0; index < stepCount; index++)
                    SizedBox(
                      width: stepWidth,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Center(
                            child: _TrackingStepImage(
                              size: _iconSize,
                              imagePath:
                                  _trackingSteps[index]['image'] as String,
                              fallbackIcon:
                                  _trackingSteps[index]['icon'] as IconData,
                              isCompleted:
                                  isFullyComplete || index < currentIndex,
                              isActive: !isFullyComplete &&
                                  !isCancelled &&
                                  index == currentIndex,
                            ),
                          ),
                          const SizedBox(height: 6),
                          SizedBox(
                            width: stepWidth,
                            height: 28,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text(
                                _trackingSteps[index]['label'] as String,
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                style: TextStyle(
                                  fontSize: 10,
                                  height: 1.15,
                                  fontWeight: index == currentIndex &&
                                          !isFullyComplete
                                      ? FontWeight.w700
                                      : FontWeight.w500,
                                  color: _labelColor(
                                    index: index,
                                    currentIndex: currentIndex,
                                    isFullyComplete: isFullyComplete,
                                    isCancelled: isCancelled,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  Color _connectorColor({
    required int index,
    required int currentIndex,
    required bool isFullyComplete,
    required bool isCancelled,
  }) {
    if (isFullyComplete || index <= currentIndex) return _stepRed;
    if (isCancelled && index <= currentIndex + 1) return _stepPending;
    return _stepPending;
  }

  Color _labelColor({
    required int index,
    required int currentIndex,
    required bool isFullyComplete,
    required bool isCancelled,
  }) {
    if (isFullyComplete) return MeatvoColors.textPrimary;
    if (index == currentIndex && !isCancelled) return _stepRed;
    if (index < currentIndex) return MeatvoColors.textPrimary;
    return MeatvoColors.textMuted;
  }
}

/// @deprecated Use [OrderTrackingStepper] instead.
class CompactStatusTimeline extends OrderTrackingStepper {
  const CompactStatusTimeline({super.key, required super.currentStatus});
}
