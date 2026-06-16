import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class PhoneInputField extends StatelessWidget {
  const PhoneInputField({
    super.key,
    required this.controller,
    required this.onChanged,
    required this.onSubmitted,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;

  OutlineInputBorder _border(Color color, [double width = 1]) => OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: color, width: width),
      );

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return TextField(
      controller: controller,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      style: theme.textTheme.titleMedium?.copyWith(
        fontWeight: FontWeight.w400,
        color: const Color(0xFF1F2933),
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      decoration: InputDecoration(
        hintText: 'Enter mobile number',
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(vertical: 18),
        enabledBorder: _border(const Color(0xFFE4E4E7)),
        focusedBorder: _border(const Color(0xFFE53935), 1.4),
        prefixIconConstraints: const BoxConstraints(minWidth: 118),
        prefixIcon: Padding(
          padding: const EdgeInsets.only(left: 14, right: 8),
          child: Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: const Color(0xFFF4F4F5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'IN +91',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: const Color(0xFF52525B),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ),
      ),
      onChanged: onChanged,
      onSubmitted: onSubmitted,
    );
  }
}

class LoginBrandHeader extends StatelessWidget {
  const LoginBrandHeader({super.key, required this.compact, required this.showTagline});

  final bool compact;
  final bool showTagline;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final size = compact ? 64.0 : 76.0;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Image.asset(
          'assets/icons/logo.png',
          height: size,
          width: size,
          errorBuilder: (_, __, ___) => Container(
            height: size,
            width: size,
            decoration: BoxDecoration(
              color: const Color(0xFFFFEBEE),
              borderRadius: BorderRadius.circular(20),
            ),
            child: const Icon(Icons.shopping_bag_rounded, color: Color(0xFFE53935)),
          ),
        ),
        if (showTagline) ...[
          const SizedBox(height: 12),
          Text(
            'Fresh meat, delivered fast',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              fontSize: 14,
              color: const Color(0xFF7A7A7A),
            ),
          ),
        ],
      ],
    );
  }
}

class GradientPrimaryButton extends StatelessWidget {
  const GradientPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      height: 56,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFE53935), Color(0xFFC62828)],
        ),
        borderRadius: BorderRadius.circular(16),
        boxShadow: const [
          BoxShadow(
            color: Color(0x29E53935),
            blurRadius: 18,
            offset: Offset(0, 10),
          ),
        ],
      ),
      child: ElevatedButton(
        onPressed: onPressed,
        style: ElevatedButton.styleFrom(
          backgroundColor: Colors.transparent,
          foregroundColor: Colors.white,
          shadowColor: Colors.transparent,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        ),
        child: isLoading
            ? const SizedBox(
                height: 20,
                width: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                ),
              )
            : Text(
                label,
                style: theme.textTheme.titleMedium?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.w600,
                ),
              ),
      ),
    );
  }
}

class TermsConsentRow extends StatelessWidget {
  const TermsConsentRow({
    super.key,
    required this.value,
    required this.enabled,
    required this.onChanged,
  });

  final bool value;
  final bool enabled;
  final ValueChanged<bool?> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Transform.scale(
          scale: 0.9,
          child: Checkbox(
            value: value,
            activeColor: const Color(0xFFE53935),
            visualDensity: VisualDensity.compact,
            onChanged: enabled ? onChanged : null,
          ),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(top: 10),
            child: Text.rich(
              TextSpan(
                style: theme.textTheme.bodySmall?.copyWith(
                  fontSize: 12,
                  height: 1.4,
                  color: const Color(0xFF7A7A7A),
                ),
                children: const [
                  TextSpan(text: 'I agree to the '),
                  TextSpan(
                    text: 'Terms',
                    style: TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  TextSpan(text: ' and '),
                  TextSpan(
                    text: 'Privacy Policy',
                    style: TextStyle(
                      color: Color(0xFFE53935),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class AuthFooterNote extends StatelessWidget {
  const AuthFooterNote({super.key});

  @override
  Widget build(BuildContext context) {
    return Text(
      'New here? We\'ll create your account automatically',
      textAlign: TextAlign.center,
      style: Theme.of(context).textTheme.bodySmall?.copyWith(
            fontSize: 12,
            color: const Color(0xFFB0B0B0),
          ),
    );
  }
}
