import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../settings/privacy_policy_screen.dart';
import '../settings/refunds_policy_screen.dart';
import '../settings/terms_of_service_screen.dart';

/// Gray-filled phone input with +91 prefix for auth screens.
class AuthPhoneField extends StatelessWidget {
  const AuthPhoneField({
    super.key,
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onSubmitted,
    this.enabled = true,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final ValueChanged<String> onSubmitted;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);

    return TextField(
      controller: controller,
      focusNode: focusNode,
      enabled: enabled,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      style: theme.textTheme.bodyLarge?.copyWith(
        color: mv.textPrimary,
        fontWeight: FontWeight.w500,
      ),
      decoration: InputDecoration(
        hintText: 'Enter mobile number',
        hintStyle: theme.textTheme.bodyLarge?.copyWith(
          color: mv.textMuted,
        ),
        filled: true,
        fillColor: MeatvoColors.surfaceMuted,
        contentPadding: EdgeInsets.symmetric(
          vertical: AppSpacing.md + 2,
          horizontal: AppSpacing.md,
        ),
        prefixIcon: Padding(
          padding: EdgeInsets.only(left: mv.spacing.md),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '+91',
                style: theme.textTheme.titleSmall?.copyWith(
                  color: mv.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(width: mv.spacing.sm),
              Container(width: 1, height: 22, color: mv.border),
              SizedBox(width: mv.spacing.sm),
            ],
          ),
        ),
        prefixIconConstraints: const BoxConstraints(minWidth: 0, minHeight: 0),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: mv.brandPrimary, width: 2),
        ),
        errorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: mv.error),
        ),
        focusedErrorBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
          borderSide: BorderSide(color: mv.error, width: 2),
        ),
      ),
    );
  }
}

/// Full-width primary CTA for auth screens.
class AuthPrimaryButton extends StatelessWidget {
  const AuthPrimaryButton({
    super.key,
    required this.label,
    required this.isLoading,
    required this.enabled,
    required this.onPressed,
  });

  final String label;
  final bool isLoading;
  final bool enabled;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);

    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton(
        onPressed: enabled && !isLoading ? onPressed : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: mv.brandPrimary,
          foregroundColor: MeatvoColors.white,
          disabledBackgroundColor: MeatvoColors.surfaceMuted,
          disabledForegroundColor: mv.textMuted,
          elevation: enabled ? 0 : 0,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
          ),
        ),
        child: isLoading
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: MeatvoColors.white,
                ),
              )
            : Text(
                label,
                style: theme.textTheme.titleSmall?.copyWith(
                  color: enabled ? MeatvoColors.white : mv.textMuted,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
      ),
    );
  }
}

/// Order-updates opt-in toggle persisted via SharedPreferences.
class AuthOrderUpdatesToggle extends StatefulWidget {
  const AuthOrderUpdatesToggle({super.key});

  @override
  State<AuthOrderUpdatesToggle> createState() => _AuthOrderUpdatesToggleState();
}

class _AuthOrderUpdatesToggleState extends State<AuthOrderUpdatesToggle> {
  bool _enabled = true;
  bool _loaded = false;

  @override
  void initState() {
    super.initState();
    _loadPreference();
  }

  Future<void> _loadPreference() async {
    final prefs = await SharedPreferences.getInstance();
    if (!mounted) return;
    setState(() {
      _enabled = prefs.getBool('order_updates') ?? true;
      _loaded = true;
    });
  }

  Future<void> _onChanged(bool value) async {
    setState(() => _enabled = value);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('order_updates', value);
    await prefs.setBool('sms_notifications', value);
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);

    if (!_loaded) {
      return SizedBox(height: mv.spacing.xl);
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        Switch(
          value: _enabled,
          onChanged: _onChanged,
          activeThumbColor: MeatvoColors.white,
          activeTrackColor: mv.brandPrimary,
          inactiveTrackColor: MeatvoColors.surfaceMuted,
          materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
        ),
        SizedBox(width: mv.spacing.xs),
        Expanded(
          child: Text(
            'Get order updates via messages and calls',
            style: theme.textTheme.bodySmall?.copyWith(
              color: mv.textSecondary,
              height: 1.35,
            ),
          ),
        ),
      ],
    );
  }
}

/// Required consent checkbox for auth with legal-policy links.
class AuthConsentCheckbox extends StatelessWidget {
  const AuthConsentCheckbox({
    super.key,
    required this.value,
    required this.onChanged,
    this.enabled = true,
  });

  final bool value;
  final ValueChanged<bool?> onChanged;
  final bool enabled;

  void _openLegalScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);

    final linkStyle = theme.textTheme.labelSmall!.copyWith(
      color: mv.brandPrimary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: mv.brandPrimary,
      height: 1.4,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(top: mv.spacing.xxs),
          child: Checkbox(
            value: value,
            onChanged: enabled ? onChanged : null,
            activeColor: mv.brandPrimary,
            visualDensity: VisualDensity.compact,
            materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
          ),
        ),
        SizedBox(width: mv.spacing.xs),
        Expanded(
          child: Padding(
            padding: EdgeInsets.only(top: mv.spacing.xs),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'I agree to the following:',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: mv.textSecondary,
                    height: 1.35,
                  ),
                ),
                SizedBox(height: mv.spacing.xxs),
                Wrap(
                  spacing: mv.spacing.sm,
                  runSpacing: mv.spacing.xxs,
                  children: [
                    GestureDetector(
                      onTap: () => _openLegalScreen(
                        context,
                        const TermsOfServiceScreen(),
                      ),
                      child: Text('T&C', style: linkStyle),
                    ),
                    GestureDetector(
                      onTap: () => _openLegalScreen(
                        context,
                        const RefundsPolicyScreen(),
                      ),
                      child: Text('Refunds Policy', style: linkStyle),
                    ),
                    GestureDetector(
                      onTap: () => _openLegalScreen(
                        context,
                        const PrivacyPolicyScreen(),
                      ),
                      child: Text('Privacy Policy', style: linkStyle),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Bottom legal footer with T&C, Refunds Policy, and Privacy Policy links.
class AuthLegalFooter extends StatelessWidget {
  const AuthLegalFooter({super.key});

  void _openLegalScreen(BuildContext context, Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);

    TextStyle linkStyle = theme.textTheme.labelSmall!.copyWith(
      color: mv.brandPrimary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: mv.brandPrimary,
      height: 1.4,
    );

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          'By continuing, you agree to our',
          textAlign: TextAlign.center,
          style: theme.textTheme.labelSmall?.copyWith(
            color: mv.textMuted,
            height: 1.4,
          ),
        ),
        SizedBox(height: mv.spacing.xxs),
        Wrap(
          alignment: WrapAlignment.center,
          crossAxisAlignment: WrapCrossAlignment.center,
          spacing: mv.spacing.sm,
          runSpacing: mv.spacing.xxs,
          children: [
            GestureDetector(
              onTap: () => _openLegalScreen(
                context,
                const TermsOfServiceScreen(),
              ),
              child: Text('T&C', style: linkStyle),
            ),
            GestureDetector(
              onTap: () => _openLegalScreen(
                context,
                const RefundsPolicyScreen(),
              ),
              child: Text('Refunds Policy', style: linkStyle),
            ),
            GestureDetector(
              onTap: () => _openLegalScreen(
                context,
                const PrivacyPolicyScreen(),
              ),
              child: Text('Privacy Policy', style: linkStyle),
            ),
          ],
        ),
      ],
    );
  }
}
