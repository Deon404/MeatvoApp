import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/constants/app_constants.dart';
import '../../core/widgets/shimmer_loader.dart';
import '../../models/notification_model.dart';
import '../../screens/orders/order_detail_screen.dart';
import '../../services/notification_service.dart';
import '../../utils/app_transitions.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/common/error_state.dart';

/// Notifications screen with local notification history
class NotificationsScreen extends StatefulWidget {
  const NotificationsScreen({super.key});

  @override
  State<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends State<NotificationsScreen> {
  final NotificationService _notificationService = NotificationService();
  List<NotificationModel> _notifications = [];
  List<NotificationModel> _filteredNotifications = [];
  bool _isLoading = true;
  String? _errorMessage;
  String _selectedFilter = 'all';

  static const _filters = [
    ('all', 'All'),
    ('orders', 'Orders'),
    ('promotions', 'Promotions'),
  ];

  @override
  void initState() {
    super.initState();
    _loadNotifications();
  }

  Future<void> _loadNotifications({bool isRefresh = false}) async {
    if (!isRefresh) {
      setState(() {
        _isLoading = _notifications.isEmpty && _errorMessage == null;
        _errorMessage = null;
      });
    } else {
      setState(() => _errorMessage = null);
    }

    try {
      final notifications = await _notificationService.getHistory();
      if (mounted) {
        setState(() {
          _notifications = notifications;
          _applyFilter();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _errorMessage = 'Failed to load notifications';
          _isLoading = false;
        });
      }
    }
  }

  void _selectFilter(String filter) {
    if (_selectedFilter == filter) return;
    setState(() {
      _selectedFilter = filter;
      _applyFilter();
    });
  }

  void _applyFilter() {
    List<NotificationModel> result;
    switch (_selectedFilter) {
      case 'orders':
        result = _notifications
            .where((n) =>
                n.type == 'order_status' ||
                n.type == 'payment' ||
                n.type == 'order')
            .toList();
        break;
      case 'promotions':
        result = _notifications
            .where((n) => n.type == 'promo' || n.type == 'promotion')
            .toList();
        break;
      default:
        result = List<NotificationModel>.from(_notifications);
    }
    _filteredNotifications = result;
  }

  Future<void> _markAllRead() async {
    await _notificationService.markAllRead();
    await _loadNotifications(isRefresh: true);
  }

  Future<void> _handleNotificationTap(NotificationModel notification) async {
    if (!notification.isRead) {
      await _notificationService.markAsRead(notification.id);
      await _loadNotifications(isRefresh: true);
    }

    final orderId = notification.data?['order_id']?.toString();
    if (orderId != null && mounted) {
      await context.pushSlideRight(
        OrderDetailScreen(orderId: orderId),
      );
    }
  }

  bool get _hasUnread => _notifications.any((n) => !n.isRead);

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.warmBg,
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: AppColors.cardBg,
        foregroundColor: AppColors.textDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        actions: [
          if (_hasUnread)
            TextButton(
              onPressed: _markAllRead,
              child: const Text(
                'Mark all read',
                style: TextStyle(
                  color: AppColors.primary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Poppins',
                ),
              ),
            ),
        ],
      ),
      body: SafeArea(
        top: false,
        bottom: true,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildFilterChips(),
            Expanded(
              child: _isLoading
                  ? _buildShimmerLoading()
                  : _errorMessage != null
                      ? ErrorStateWidget(
                          title: 'Unable to load notifications',
                          message: _errorMessage,
                          onRetry: () => _loadNotifications(),
                        )
                      : _filteredNotifications.isEmpty
                          ? _buildEmptyState()
                          : RefreshIndicator(
                              onRefresh: () =>
                                  _loadNotifications(isRefresh: true),
                              color: AppColors.primary,
                              child: ListView.builder(
                                physics: const AlwaysScrollableScrollPhysics(),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 8,
                                ),
                                itemCount: _filteredNotifications.length,
                                itemBuilder: (context, index) {
                                  final notification =
                                      _filteredNotifications[index];
                                  return _NotificationCard(
                                    notification: notification,
                                    onTap: () =>
                                        _handleNotificationTap(notification),
                                  );
                                },
                              ),
                            ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFilterChips() {
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      child: Row(
        children: [
          for (var i = 0; i < _filters.length; i++) ...[
            if (i > 0) const SizedBox(width: 8),
            _buildFilterChip(_filters[i].$1, _filters[i].$2),
          ],
        ],
      ),
    );
  }

  Widget _buildFilterChip(String value, String label) {
    final isSelected = _selectedFilter == value;

    return GestureDetector(
      onTap: () {
        HapticFeedback.selectionClick();
        _selectFilter(value);
      },
      child: Container(
        height: 36,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: isSelected ? AppColors.primary : AppColors.cardBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w500,
            color: isSelected ? AppColors.white : AppColors.textMedium,
            fontFamily: 'Poppins',
          ),
        ),
      ),
    );
  }

  Widget _buildShimmerLoading() {
    return ListView.separated(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      physics: const NeverScrollableScrollPhysics(),
      itemCount: 3,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (_, __) => const ShimmerLoader(
        width: double.infinity,
        height: 64,
        borderRadius: 12,
      ),
    );
  }

  Widget _buildEmptyState() {
    return RefreshIndicator(
      onRefresh: () => _loadNotifications(isRefresh: true),
      color: AppColors.primary,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        children: [
          SizedBox(height: MediaQuery.of(context).size.height * 0.22),
          const Icon(
            Icons.notifications_none,
            size: 56,
            color: AppColors.textMuted,
          ),
          const SizedBox(height: 16),
          const Text(
            'No notifications yet',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textDark,
              fontFamily: 'Poppins',
            ),
          ),
          const SizedBox(height: 8),
          Text(
            _selectedFilter == 'all'
                ? 'Your order updates will appear here'
                : 'Nothing in this category yet',
            textAlign: TextAlign.center,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textMedium,
              fontFamily: 'Poppins',
            ),
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.notification,
    required this.onTap,
  });

  final NotificationModel notification;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final isUnread = !notification.isRead;
    final backgroundColor =
        isUnread ? AppColors.surfaceWarm : AppColors.cardBg;

    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.black.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        notification.title,
                        style: const TextStyle(
                          fontSize: 13,
                          fontWeight: FontWeight.w600,
                          color: AppColors.textDark,
                          fontFamily: 'Poppins',
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        notification.body,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(
                          fontSize: 12,
                          color: AppColors.textMedium,
                          fontFamily: 'Poppins',
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _formatTimeAgo(notification.createdAt),
                        style: const TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                          fontFamily: 'Poppins',
                        ),
                      ),
                    ],
                  ),
                ),
                if (isUnread) ...[
                  const SizedBox(width: 8),
                  Container(
                    width: 8,
                    height: 8,
                    margin: const EdgeInsets.only(top: 4),
                    decoration: const BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildIcon() {
    late IconData iconData;
    late Color iconColor;
    late Color bgColor;

    switch (notification.type) {
      case 'order_status':
        iconData = Icons.shopping_bag;
        iconColor = const Color(0xFFE65100);
        bgColor = const Color(0xFFFFF3E0);
        break;
      case 'payment':
        iconData = Icons.payment;
        iconColor = const Color(0xFF2E7D32);
        bgColor = const Color(0xFFE8F5E9);
        break;
      case 'promo':
        iconData = Icons.local_offer;
        iconColor = const Color(0xFFF57F17);
        bgColor = const Color(0xFFFFF8E1);
        break;
      default:
        iconData = Icons.notifications;
        iconColor = const Color(0xFF7B1FA2);
        bgColor = const Color(0xFFF3E5F5);
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Icon(
        iconData,
        color: iconColor,
        size: 20,
      ),
    );
  }

  String _formatTimeAgo(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.inSeconds < 60) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else if (difference.inDays < 30) {
      final weeks = (difference.inDays / 7).floor();
      return '${weeks}w ago';
    } else if (difference.inDays < 365) {
      final months = (difference.inDays / 30).floor();
      return '${months}mo ago';
    } else {
      final years = (difference.inDays / 365).floor();
      return '${years}y ago';
    }
  }
}
