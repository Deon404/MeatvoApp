import 'package:flutter/material.dart';

import '../../config/backend_resolver.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../services/auth_service.dart';
import '../../utils/app_transitions.dart';
import 'auth_login_widgets.dart';
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

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);
    final isConnectionFeedback = _feedbackText != null &&
        BackendResolver.isConnectionError(_feedbackText!);

    return AuthScreenShell(
      bottomFooter: const AuthLegalFooter(),
      children: [
        const AuthLogoHeader(),
        SizedBox(height: mv.spacing.xxl * 2),
        AuthPhoneField(
          controller: _phoneController,
          focusNode: _phoneFocusNode,
          enabled: !_isLoading,
          onChanged: (_) => setState(() => _feedbackText = null),
          onSubmitted: (_) {
            if (!_isLoading) _sendOtp();
          },
        ),
        if (_feedbackText != null) ...[
          SizedBox(height: mv.spacing.xs),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: EdgeInsets.only(top: 1, right: mv.spacing.xxs),
                child: Icon(
                  isConnectionFeedback
                      ? Icons.wifi_off_rounded
                      : Icons.info_outline_rounded,
                  size: 16,
                  color: mv.error,
                ),
              ),
              Expanded(
                child: Text(
                  _feedbackText!,
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: mv.error,
                    fontWeight: FontWeight.w500,
                    height: 1.35,
                  ),
                ),
              ),
            ],
          ),
        ],
        SizedBox(height: mv.spacing.lg),
        AuthPrimaryButton(
          label: 'Get OTP',
          isLoading: _isLoading,
          enabled: _hasTenDigits,
          onPressed: _sendOtp,
        ),
        SizedBox(height: mv.spacing.lg),
        const AuthOrderUpdatesToggle(),
      ],
    );
  }
}
