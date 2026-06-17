import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/backend_resolver.dart';
import '../../design_system/tokens/meatvo_colors.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../services/auth_service.dart';
import '../../utils/app_transitions.dart';
import '../settings/privacy_policy_screen.dart';
import '../settings/terms_of_service_screen.dart';
import 'auth_screen_shell.dart';
import 'otp_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final FocusNode _phoneFocusNode = FocusNode();
  final AuthService _authService = AuthService();
  bool _isLoading = false;
  String? _feedbackText;

  bool _isValidPhone(String value) =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim());

  bool get _isValid =>
      RegExp(r'^\d{10}$').hasMatch(_phoneController.text.trim());

  bool get _hasTenDigits =>
      RegExp(r'^\d{10}$').hasMatch(_phoneController.text.trim());

  @override
  void initState() {
    super.initState();
    _phoneController.addListener(() => setState(() {}));
    _phoneFocusNode.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _phoneController.dispose();
    _phoneFocusNode.dispose();
    super.dispose();
  }

  String _errorMessage(Object error) {
    final raw = error.toString().replaceFirst('Exception:', '').trim();
    final lower = raw.toLowerCase();
    if (lower.contains('invalid phone')) {
      return 'Invalid phone number. Please check and try again.';
    }
    if (lower.contains('too many') || lower.contains('rate limit')) {
      return 'Too many requests. Please try again in a few minutes.';
    }
    if (BackendResolver.isConnectionError(raw)) {
      return BackendResolver.connectionUserMessage();
    }
    return raw.isEmpty ? 'Failed to send OTP. Please try again.' : raw;
  }

  String? _validatePhone(String value) {
    final phone = value.trim();
    if (phone.isEmpty) return null;
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      return 'Enter a valid 10-digit mobile number.';
    }
    if (!_isValidPhone(phone)) return 'Enter a valid Indian mobile number.';
    return null;
  }

  Future<void> _sendOtp() async {
    final validation = _validatePhone(_phoneController.text);
    if (validation != null) {
      setState(() => _feedbackText = validation);
      return;
    }
    if (!_isValid || _isLoading) return;

    final phone = _phoneController.text.trim();
    final phoneE164 = AuthService.formatPhoneE164(phone);

    setState(() {
      _isLoading = true;
      _feedbackText = null;
    });

    try {
      await BackendResolver.ensureReachable();
      final result = await _authService.sendOtp(phoneE164);
      if (!mounted) return;

      Navigator.of(context).push(
        AppTransitions.slideFade(
          OtpScreen(
            phone: phoneE164,
            prefilledOtp: result.devOtp,
            initialResendSeconds: result.remainingSeconds,
            otpAlreadySent: result.alreadySent,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(() => _feedbackText = _errorMessage(error));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _openLegalScreen(Widget screen) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(builder: (_) => screen),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);
    final phone = _phoneController.text.trim();
    final isConnectionFeedback = _feedbackText != null &&
        BackendResolver.isConnectionError(_feedbackText!);

    final helperText = _feedbackText ??
        (phone.isEmpty
            ? ''
            : _isValidPhone(phone)
                ? 'OTP will be sent to +91 $phone'
                : 'Enter a valid 10-digit mobile number.');
    final helperColor = _feedbackText != null
        ? mv.error
        : _isValidPhone(phone)
            ? mv.freshBadge
            : mv.textMuted;

    return AuthScreenShell(
      children: [
        const AuthBrandHeader(),
        SizedBox(height: mv.spacing.lg),
        AuthFormCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Enter your mobile',
                style: theme.textTheme.titleLarge?.copyWith(
                  color: mv.textPrimary,
                  fontWeight: FontWeight.w600,
                ),
              ),
              SizedBox(height: mv.spacing.xxs),
              Text(
                "We'll send a 4-digit OTP to verify",
                style: theme.textTheme.bodySmall?.copyWith(
                  color: mv.textSecondary,
                ),
              ),
              SizedBox(height: mv.spacing.lg),
              TextField(
                controller: _phoneController,
                focusNode: _phoneFocusNode,
                keyboardType: TextInputType.phone,
                textInputAction: TextInputAction.done,
                inputFormatters: [
                  FilteringTextInputFormatter.digitsOnly,
                  LengthLimitingTextInputFormatter(10),
                ],
                onChanged: (_) => setState(() => _feedbackText = null),
                onSubmitted: (_) {
                  if (!_isLoading) _sendOtp();
                },
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
                  fillColor: mv.surfaceCard,
                  contentPadding: EdgeInsets.symmetric(
                    vertical: mv.spacing.md,
                    horizontal: mv.spacing.md,
                  ),
                  // prefixIcon stays visible when unfocused; `prefix` is hidden
                  // by Material until the field has focus and text.
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
                  prefixIconConstraints:
                      const BoxConstraints(minWidth: 0, minHeight: 0),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(mv.radii.md),
                    borderSide: BorderSide(color: mv.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(mv.radii.md),
                    borderSide: BorderSide(color: mv.brandPrimary, width: 2),
                  ),
                  errorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(mv.radii.md),
                    borderSide: BorderSide(color: mv.error),
                  ),
                  focusedErrorBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(mv.radii.md),
                    borderSide: BorderSide(color: mv.error, width: 2),
                  ),
                ),
              ),
              if (helperText.isNotEmpty) ...[
                SizedBox(height: mv.spacing.xs),
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_feedbackText != null)
                      Padding(
                        padding: EdgeInsets.only(top: 1, right: mv.spacing.xxs),
                        child: Icon(
                          isConnectionFeedback
                              ? Icons.wifi_off_rounded
                              : Icons.info_outline_rounded,
                          size: 16,
                          color: helperColor,
                        ),
                      ),
                    Expanded(
                      child: Text(
                        helperText,
                        style: theme.textTheme.labelMedium?.copyWith(
                          color: helperColor,
                          fontWeight: FontWeight.w500,
                          height: 1.35,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              SizedBox(height: mv.spacing.md),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.lock_outline, size: 16, color: mv.textMuted),
                  SizedBox(width: mv.spacing.xs),
                  Expanded(
                    child: Wrap(
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        Text(
                          'By continuing, you agree to our ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: mv.textMuted,
                            height: 1.4,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openLegalScreen(
                            const TermsOfServiceScreen(),
                          ),
                          child: Text(
                            'Terms of Service',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: mv.brandPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
                            ),
                          ),
                        ),
                        Text(
                          ' and ',
                          style: theme.textTheme.labelSmall?.copyWith(
                            color: mv.textMuted,
                            height: 1.4,
                          ),
                        ),
                        GestureDetector(
                          onTap: () => _openLegalScreen(
                            const PrivacyPolicyScreen(),
                          ),
                          child: Text(
                            'Privacy Policy',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: mv.brandPrimary,
                              fontWeight: FontWeight.w600,
                              height: 1.4,
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
        ),
        SizedBox(height: mv.spacing.lg),
        SizedBox(
          width: double.infinity,
          height: 56,
          child: ElevatedButton(
            onPressed: _isLoading || !_hasTenDigits ? null : _sendOtp,
            style: ElevatedButton.styleFrom(
              backgroundColor: mv.brandPrimary,
              foregroundColor: MeatvoColors.white,
              disabledBackgroundColor: MeatvoColors.surfaceMuted,
              disabledForegroundColor: mv.textMuted,
              elevation: _hasTenDigits ? 4 : 0,
              shadowColor: mv.brandPrimary.withValues(alpha: 0.35),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(mv.radii.lg),
              ),
            ),
            child: _isLoading
                ? SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: MeatvoColors.white,
                    ),
                  )
                : Text(
                    'Continue',
                    style: theme.textTheme.titleSmall?.copyWith(
                      color: _hasTenDigits ? MeatvoColors.white : mv.textMuted,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.5,
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
