import 'package:flutter/material.dart';
import '../../models/order_model.dart';
import '../../services/contact_action_service.dart';
import '../../utils/order_display_util.dart';
import '../common/contact_action_button.dart';

/// Material You styled card showing customer contact information for delivery partner
class CustomerContactCard extends StatefulWidget {
  final OrderModel order;
  final VoidCallback? onRefresh;

  const CustomerContactCard({
    super.key,
    required this.order,
    this.onRefresh,
  });

  @override
  State<CustomerContactCard> createState() => _CustomerContactCardState();
}

class _CustomerContactCardState extends State<CustomerContactCard> {
  final ContactActionService _contactService = ContactActionService();
  bool _isCallLoading = false;
  bool _isSmsLoading = false;

  String? get _customerName {
    try {
      if (widget.order.deliveryAddress != null) {
        final addressData = widget.order.deliveryAddress!;
        // Try parsing as JSON if it's a string representation
        if (addressData.contains('name')) {
          final nameMatch = RegExp(r'"name"\s*:\s*"([^"]+)"').firstMatch(addressData);
          if (nameMatch != null) {
            return nameMatch.group(1);
          }
        }
      }
    } catch (e) {
      // Fallback
    }
    return 'Customer';
  }

  String? get _customerPhone {
    try {
      if (widget.order.deliveryAddress != null) {
        final addressData = widget.order.deliveryAddress!;
        // Try parsing phone from address string
        if (addressData.contains('phone')) {
          final phoneMatch = RegExp(r'"phone"\s*:\s*"([^"]+)"').firstMatch(addressData);
          if (phoneMatch != null) {
            return phoneMatch.group(1);
          }
        }
      }
    } catch (e) {
      // Fallback
    }
    return null;
  }

  String get _deliveryAddress {
    if (widget.order.deliveryAddress != null) {
      final address = widget.order.deliveryAddress!;
      // Remove JSON formatting if present
      final cleanAddress = address
          .replaceAll(RegExp(r'\{[^}]*\}'), '')
          .replaceAll(RegExp(r'"'), '')
          .trim();
      return cleanAddress.isNotEmpty ? cleanAddress : address;
    }
    return 'Address not available';
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final textTheme = Theme.of(context).textTheme;

    return Container(
      margin: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            colorScheme.primaryContainer,
            colorScheme.tertiaryContainer,
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.2),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildAvatar(colorScheme),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deliver to',
                        style: textTheme.labelMedium?.copyWith(
                          color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        _customerName ?? 'Customer',
                        style: textTheme.titleLarge?.copyWith(
                          color: colorScheme.onPrimaryContainer,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ),
                _buildOrderBadge(colorScheme, textTheme),
              ],
            ),
            if (_customerPhone != null) ...[
              const SizedBox(height: 12),
              const Divider(height: 1),
              const SizedBox(height: 12),
              Row(
                children: [
                  Icon(
                    Icons.phone,
                    size: 16,
                    color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    _customerPhone!,
                    style: textTheme.bodyMedium?.copyWith(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.9),
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 12),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.location_on,
                  size: 16,
                  color: colorScheme.onPrimaryContainer.withOpacity(0.7),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _deliveryAddress,
                    style: textTheme.bodySmall?.copyWith(
                      color: colorScheme.onPrimaryContainer.withOpacity(0.8),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            if (_customerPhone != null) ...[
              const SizedBox(height: 16),
              const Divider(height: 1),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: ContactActionButton(
                      icon: Icons.phone,
                      label: 'Call Customer',
                      variant: ContactActionButtonVariant.filled,
                      isLoading: _isCallLoading,
                      onPressed: _handleCall,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ContactActionButton(
                      icon: Icons.message,
                      label: 'Message',
                      variant: ContactActionButtonVariant.tonal,
                      isLoading: _isSmsLoading,
                      onPressed: _handleSms,
                    ),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildAvatar(ColorScheme colorScheme) {
    final initial = _customerName?.isNotEmpty == true
        ? _customerName!.substring(0, 1).toUpperCase()
        : 'C';

    return Container(
      width: 56,
      height: 56,
      decoration: BoxDecoration(
        color: colorScheme.primary,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(
            color: colorScheme.primary.withOpacity(0.3),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Center(
        child: Text(
          initial,
          style: TextStyle(
            color: colorScheme.onPrimary,
            fontSize: 22,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildOrderBadge(ColorScheme colorScheme, TextTheme textTheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: colorScheme.secondary.withOpacity(0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: colorScheme.secondary.withOpacity(0.5),
          width: 1,
        ),
      ),
      child: Text(
        '#${formatOrderDisplayId(widget.order.id)}',
        style: textTheme.labelSmall?.copyWith(
          color: colorScheme.secondary,
          fontWeight: FontWeight.bold,
        ),
      ),
    );
  }

  Future<void> _handleCall() async {
    if (_customerPhone == null) return;

    setState(() => _isCallLoading = true);

    final success = await _contactService.makeCall(_customerPhone!);

    if (mounted) {
      setState(() => _isCallLoading = false);

      if (!success && context.mounted) {
        _contactService.showContactError(
          context,
          'call',
          _customerPhone!,
        );
      }
    }
  }

  Future<void> _handleSms() async {
    if (_customerPhone == null) return;

    setState(() => _isSmsLoading = true);

    final success = await _contactService.sendSMS(_customerPhone!);

    if (mounted) {
      setState(() => _isSmsLoading = false);

      if (!success && context.mounted) {
        _contactService.showContactError(
          context,
          'message',
          _customerPhone!,
        );
      }
    }
  }
}
