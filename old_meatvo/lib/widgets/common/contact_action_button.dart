import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Reusable button for contact actions (call, SMS) with Material You design
class ContactActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onPressed;
  final bool isLoading;
  final ContactActionButtonVariant variant;
  final bool iconOnly;

  const ContactActionButton({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
    this.isLoading = false,
    this.variant = ContactActionButtonVariant.filled,
    this.iconOnly = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (isLoading) {
      return _buildLoadingButton(context);
    }

    switch (variant) {
      case ContactActionButtonVariant.filled:
        return FilledButton.icon(
          onPressed: _handlePress,
          icon: Icon(icon, size: iconOnly ? 24 : 20),
          label: iconOnly ? const SizedBox.shrink() : Text(label),
          style: FilledButton.styleFrom(
            padding: iconOnly
                ? const EdgeInsets.all(16)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            minimumSize: const Size(48, 48),
          ),
        );

      case ContactActionButtonVariant.outlined:
        return OutlinedButton.icon(
          onPressed: _handlePress,
          icon: Icon(icon, size: iconOnly ? 24 : 20),
          label: iconOnly ? const SizedBox.shrink() : Text(label),
          style: OutlinedButton.styleFrom(
            padding: iconOnly
                ? const EdgeInsets.all(16)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            minimumSize: const Size(48, 48),
            side: BorderSide(color: colorScheme.outline),
          ),
        );

      case ContactActionButtonVariant.text:
        return TextButton.icon(
          onPressed: _handlePress,
          icon: Icon(icon, size: iconOnly ? 24 : 20),
          label: iconOnly ? const SizedBox.shrink() : Text(label),
          style: TextButton.styleFrom(
            padding: iconOnly
                ? const EdgeInsets.all(16)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            minimumSize: const Size(48, 48),
          ),
        );

      case ContactActionButtonVariant.tonal:
        return FilledButton.tonalIcon(
          onPressed: _handlePress,
          icon: Icon(icon, size: iconOnly ? 24 : 20),
          label: iconOnly ? const SizedBox.shrink() : Text(label),
          style: FilledButton.styleFrom(
            padding: iconOnly
                ? const EdgeInsets.all(16)
                : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            minimumSize: const Size(48, 48),
          ),
        );
    }
  }

  void _handlePress() {
    HapticFeedback.lightImpact();
    onPressed();
  }

  Widget _buildLoadingButton(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return FilledButton.icon(
      onPressed: null,
      icon: SizedBox(
        width: 20,
        height: 20,
        child: CircularProgressIndicator(
          strokeWidth: 2,
          valueColor: AlwaysStoppedAnimation<Color>(
            colorScheme.onPrimary.withOpacity(0.7),
          ),
        ),
      ),
      label: iconOnly ? const SizedBox.shrink() : Text(label),
      style: FilledButton.styleFrom(
        padding: iconOnly
            ? const EdgeInsets.all(16)
            : const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        minimumSize: const Size(48, 48),
      ),
    );
  }
}

enum ContactActionButtonVariant {
  filled,
  outlined,
  text,
  tonal,
}
