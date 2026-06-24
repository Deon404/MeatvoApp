import 'package:flutter/material.dart';
import '../../core/constants/app_constants.dart';
import '../../models/order_model.dart';
import '../../services/contact_action_service.dart';

String formatRiderPhoneNumber(String phone) {
  final digits = phone.replaceAll(RegExp(r'\D'), '');
  if (digits.length == 10) {
    return '+91 ${digits.substring(0, 5)} ${digits.substring(5)}';
  }
  if (digits.length > 10) {
    final countryCode = digits.substring(0, digits.length - 10);
    final remaining = digits.substring(digits.length - 10);
    return '+$countryCode ${remaining.substring(0, 5)} ${remaining.substring(5)}';
  }
  return phone;
}

String riderInitials(String? name) {
  final trimmed = name?.trim() ?? '';
  if (trimmed.isEmpty) return 'D';
  return trimmed
      .split(RegExp(r'\s+'))
      .take(2)
      .map((part) => part.isNotEmpty ? part[0].toUpperCase() : '')
      .join();
}

/// Card showing delivery partner contact information.
class DeliveryPartnerContactCard extends StatefulWidget {
  final OrderModel order;
  final VoidCallback? onRefresh;
  final bool showAnimation;

  const DeliveryPartnerContactCard({
    super.key,
    required this.order,
    this.onRefresh,
    this.showAnimation = false,
  });

  @override
  State<DeliveryPartnerContactCard> createState() =>
      _DeliveryPartnerContactCardState();
}

class _DeliveryPartnerContactCardState
    extends State<DeliveryPartnerContactCard>
    with SingleTickerProviderStateMixin {
  final ContactActionService _contactService = ContactActionService();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  bool _isCallLoading = false;
  bool _isSmsLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    if (widget.showAnimation) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final hasRiderName =
        widget.order.riderName != null && widget.order.riderName!.trim().isNotEmpty;

    if (!hasRiderName) {
      return _buildSearchingState();
    }

    final status = widget.order.status.toLowerCase();
    final isLive = status == 'out_for_delivery' ||
        status == 'on_the_way' ||
        status == 'on_way' ||
        status == 'picked_up' ||
        status == 'rider_nearby';
    // Live backend keeps orders.status at PACKED until rider accepts
    // (POST /api/delivery/orders/:id/accept → OUT_FOR_DELIVERY).
    final isAssignedOnly = status == 'assigned' ||
        status == 'rider_assigned' ||
        status == 'rider_accepted' ||
        status == 'accepted' ||
        status == 'packed' ||
        status == 'preparing' ||
        status == 'packing_started' ||
        status == 'confirmed';

    return SlideTransition(
      position: _slideAnimation,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border, width: 1),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withValues(alpha: 0.08),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAvatar(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.order.riderName ?? 'Unknown',
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textDark,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 3,
                            ),
                            decoration: BoxDecoration(
                              color: (isLive ? AppColors.success : AppColors.warning)
                                  .withValues(alpha: 0.1),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  isLive
                                      ? Icons.delivery_dining
                                      : Icons.assignment_ind_outlined,
                                  size: 12,
                                  color: isLive
                                      ? AppColors.success
                                      : AppColors.warning,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  isLive
                                      ? 'On the way'
                                      : isAssignedOnly
                                          ? 'Assigned • pickup pending'
                                          : 'Delivery Partner',
                                  style: TextStyle(
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                    color: isLive
                                        ? AppColors.success
                                        : AppColors.warning,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            if (widget.order.riderPhone != null && 
                widget.order.riderPhone!.isNotEmpty) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.divider.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(6),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: const Icon(
                        Icons.phone,
                        size: 16,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Phone Number',
                            style: TextStyle(
                              fontSize: 11,
                              color: AppColors.textSecondary,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            _formatPhoneNumber(widget.order.riderPhone!),
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: AppColors.textDark,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 14),
            Row(
              children: [
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.message_outlined,
                    label: 'SMS',
                    onTap: _isSmsLoading ? null : _handleSms,
                    isPrimary: false,
                    isLoading: _isSmsLoading,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _buildActionButton(
                    icon: Icons.phone,
                    label: 'Call',
                    onTap: _isCallLoading ? null : _handleCall,
                    isPrimary: true,
                    isLoading: _isCallLoading,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar() {
    final initials = riderInitials(widget.order.riderName);

    return Container(
      width: 52,
      height: 52,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary,
            AppColors.primary.withValues(alpha: 0.8),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: AppColors.primary.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initials,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback? onTap,
    required bool isPrimary,
    bool isLoading = false,
  }) {
    return Material(
      color: isPrimary ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: isPrimary
                ? null
                : Border.all(
                    color: AppColors.primary.withValues(alpha: 0.3),
                    width: 1.5,
                  ),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (isLoading)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: isPrimary ? Colors.white : AppColors.primary,
                  ),
                )
              else
                Icon(
                  icon,
                  color: isPrimary ? Colors.white : AppColors.primary,
                  size: 20,
                ),
              const SizedBox(width: 8),
              Text(
                label,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: isPrimary ? Colors.white : AppColors.primary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _formatPhoneNumber(String phone) => formatRiderPhoneNumber(phone);

  Widget _buildSearchingState() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.3),
          width: 1,
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.warning.withValues(alpha: 0.08),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: AppColors.warning.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Stack(
              alignment: Alignment.center,
              children: [
                const Icon(
                  Icons.delivery_dining,
                  size: 24,
                  color: AppColors.warning,
                ),
                Positioned.fill(
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.warning.withValues(alpha: 0.6),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Finding delivery partner',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Name and call options will appear once a rider is assigned',
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary.withValues(alpha: 0.9),
                    fontWeight: FontWeight.w400,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleCall() async {
    if (widget.order.riderPhone == null) return;

    setState(() => _isCallLoading = true);

    final success = await _contactService.makeCall(widget.order.riderPhone!);

    if (mounted) {
      setState(() => _isCallLoading = false);

      if (!success && context.mounted) {
        _contactService.showContactError(
          context,
          'call',
          widget.order.riderPhone!,
        );
      }
    }
  }

  Future<void> _handleSms() async {
    if (widget.order.riderPhone == null) return;

    setState(() => _isSmsLoading = true);

    final success = await _contactService.sendSMS(widget.order.riderPhone!);

    if (mounted) {
      setState(() => _isSmsLoading = false);

      if (!success && context.mounted) {
        _contactService.showContactError(
          context,
          'message',
          widget.order.riderPhone!,
        );
      }
    }
  }

}

/// Compact Blinkit-style rider row for the pinned tracking sheet area.
class DeliveryPartnerSheetCard extends StatefulWidget {
  const DeliveryPartnerSheetCard({
    super.key,
    required this.order,
    this.showAnimation = false,
  });

  final OrderModel order;
  final bool showAnimation;

  @override
  State<DeliveryPartnerSheetCard> createState() =>
      _DeliveryPartnerSheetCardState();
}

class _DeliveryPartnerSheetCardState extends State<DeliveryPartnerSheetCard>
    with SingleTickerProviderStateMixin {
  final ContactActionService _contactService = ContactActionService();
  late AnimationController _animationController;
  late Animation<Offset> _slideAnimation;
  bool _isCallLoading = false;
  bool _isSmsLoading = false;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.15),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));

    if (widget.showAnimation) {
      _animationController.forward();
    } else {
      _animationController.value = 1.0;
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  bool get _hasRider =>
      widget.order.riderName != null &&
      widget.order.riderName!.trim().isNotEmpty;

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
        child: _hasRider ? _buildAssignedRow() : _buildSearchingRow(),
      ),
    );
  }

  Widget _buildSearchingRow() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.warning.withValues(alpha: 0.25),
        ),
      ),
      child: Row(
        children: [
          SizedBox(
            width: 40,
            height: 40,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Icon(
                  Icons.delivery_dining_rounded,
                  size: 22,
                  color: AppColors.warning.withValues(alpha: 0.9),
                ),
                Positioned.fill(
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.warning.withValues(alpha: 0.5),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Finding delivery partner',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  'Rider details will appear here once assigned',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAssignedRow() {
    final phone = widget.order.riderPhone?.trim();
    final formattedPhone =
        phone != null && phone.isNotEmpty ? formatRiderPhoneNumber(phone) : null;

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppColors.primary.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppColors.primary.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppColors.primary,
                  AppColors.primary.withValues(alpha: 0.85),
                ],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              shape: BoxShape.circle,
            ),
            alignment: Alignment.center,
            child: Text(
              riderInitials(widget.order.riderName),
              style: const TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Delivery partner',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textSecondary.withValues(alpha: 0.95),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  widget.order.riderName ?? 'Rider',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textDark,
                  ),
                ),
                if (formattedPhone != null) ...[
                  const SizedBox(height: 2),
                  Text(
                    formattedPhone,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                      letterSpacing: 0.3,
                    ),
                  ),
                ],
              ],
            ),
          ),
          const SizedBox(width: 8),
          _compactAction(
            icon: Icons.message_outlined,
            label: 'SMS',
            filled: false,
            onTap: _isSmsLoading || phone == null || phone.isEmpty
                ? null
                : _handleSms,
            loading: _isSmsLoading,
          ),
          const SizedBox(width: 6),
          _compactAction(
            icon: Icons.phone_rounded,
            label: 'Call',
            filled: true,
            onTap: _isCallLoading || phone == null || phone.isEmpty
                ? null
                : _handleCall,
            loading: _isCallLoading,
          ),
        ],
      ),
    );
  }

  Widget _compactAction({
    required IconData icon,
    required String label,
    required bool filled,
    required VoidCallback? onTap,
    bool loading = false,
  }) {
    return Material(
      color: filled ? AppColors.primary : Colors.white,
      borderRadius: BorderRadius.circular(10),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(10),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            border: filled
                ? null
                : Border.all(color: AppColors.primary.withValues(alpha: 0.35)),
          ),
          child: loading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: filled ? Colors.white : AppColors.primary,
                  ),
                )
              : Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      icon,
                      size: 18,
                      color: filled ? Colors.white : AppColors.primary,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      label,
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                        color: filled ? Colors.white : AppColors.primary,
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Future<void> _handleCall() async {
    final phone = widget.order.riderPhone;
    if (phone == null || phone.isEmpty) return;

    setState(() => _isCallLoading = true);
    final success = await _contactService.makeCall(phone);
    if (!mounted) return;
    setState(() => _isCallLoading = false);

    if (!success && context.mounted) {
      _contactService.showContactError(context, 'call', phone);
    }
  }

  Future<void> _handleSms() async {
    final phone = widget.order.riderPhone;
    if (phone == null || phone.isEmpty) return;

    setState(() => _isSmsLoading = true);
    final success = await _contactService.sendSMS(phone);
    if (!mounted) return;
    setState(() => _isSmsLoading = false);

    if (!success && context.mounted) {
      _contactService.showContactError(context, 'message', phone);
    }
  }

}
