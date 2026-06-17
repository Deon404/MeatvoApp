import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/backend_resolver.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../core/constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../utils/app_transitions.dart';
import '../../utils/responsive_helper.dart';
import 'otp_verification_screen.dart';

/// LEGACY: This screen is no longer used in the app flow.
/// The active auth path uses [PhoneScreen] → [OtpScreen] instead.
/// This implementation remains as a reference for the modern card-based design pattern.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final TextEditingController _phoneController = TextEditingController();
  final AuthService _authService = AuthService();
  bool _acceptedTerms = true;
  bool _isLoading = false;
  String? _feedbackText;

  @override
  void dispose() {
    _phoneController.dispose();
    super.dispose();
  }

  bool _isValidPhone(String value) =>
      RegExp(r'^[6-9]\d{9}$').hasMatch(value.trim());

  String? _validatePhone(String value) {
    final phone = value.trim();
    if (phone.isEmpty) return 'Please enter your phone number.';
    if (!RegExp(r'^\d{10}$').hasMatch(phone)) {
      return 'Enter a valid 10-digit mobile number.';
    }
    if (!_isValidPhone(phone)) return 'Enter a valid Indian mobile number.';
    if (!_acceptedTerms) return 'Please accept Terms & Privacy Policy.';
    return null;
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

  Future<void> _sendOtp() async {
    final validation = _validatePhone(_phoneController.text);
    if (validation != null) {
      setState(() => _feedbackText = validation);
      return;
    }
    final phone = _phoneController.text.trim();
    final phoneE164 = AuthService.formatPhoneE164(phone);
    setState(() {
      _isLoading = true;
      _feedbackText = null;
    });
    try {
      final result = await _authService.sendOTP(phoneE164);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'OTP sent successfully! Use the code from your latest SMS.',
          ),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).push(
        AppTransitions.slideFade(
          OTPVerificationScreen(
            phoneNumber: phoneE164,
            prefilledOtp: result,
          ),
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = _errorMessage(error);
      setState(() => _feedbackText = message);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message),
          backgroundColor: Colors.red,
        ),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final keyboardOpen = media.viewInsets.bottom > 0;
    final compact = keyboardOpen || media.size.height < 700;
    final phone = _phoneController.text.trim();
    final helperText = _feedbackText ??
        (phone.isEmpty
            ? ''
            : _isValidPhone(phone)
                ? ''
                : 'Enter a valid 10-digit mobile number.');
    final helperColor = _feedbackText != null
        ? Colors.red
        : _isValidPhone(phone)
            ? AppColors.success
            : mv.textSecondary;

    final horizontal = media.size.width > 480
        ? ((media.size.width - 420) / 2).clamp(24.0, 56.0).toDouble()
        : mv.spacing.xl;
    final topPadding = compact ? mv.spacing.md : mv.spacing.xl;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: mv.surfaceWarm,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_background.png',
            fit: BoxFit.cover,
          ),
          Container(
            color: Colors.white.withOpacity(0.85),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                return SingleChildScrollView(
                  padding: EdgeInsets.fromLTRB(
                    horizontal,
                    topPadding,
                    horizontal,
                    keyboardInset(context) + mv.spacing.xl,
                  ),
                  child: ConstrainedBox(
                    constraints: BoxConstraints(minHeight: constraints.maxHeight - 48),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 420),
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Center(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Image.asset(
                                    'assets/icons/logo.png',
                                    width: compact ? 76 : 92,
                                    height: compact ? 76 : 92,
                                    fit: BoxFit.contain,
                                    errorBuilder: (_, __, ___) => Container(
                                      width: compact ? 76 : 92,
                                      height: compact ? 76 : 92,
                                      decoration: BoxDecoration(
                                        color: AppColors.primaryLight,
                                        borderRadius:
                                            BorderRadius.circular(mv.radii.xl),
                                      ),
                                      child: Icon(
                                        Icons.kebab_dining_outlined,
                                        color: mv.brandPrimary,
                                        size: 40,
                                      ),
                                    ),
                                  ),
                                  SizedBox(height: mv.spacing.sm),
                                  Text(
                                    'Meatvo',
                                    style: theme.textTheme.headlineSmall?.copyWith(
                                      color: mv.brandPrimary,
                                      fontWeight: FontWeight.w800,
                                    ),
                                  ),
                                  SizedBox(height: mv.spacing.xxs),
                                  Text(
                                    'Premium cuts, delivered in 30 minutes',
                                    textAlign: TextAlign.center,
                                    style: theme.textTheme.bodyMedium?.copyWith(
                                      color: mv.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: compact ? mv.spacing.xl : mv.spacing.xxl),
                            Container(
                              padding: EdgeInsets.all(
                                compact ? mv.spacing.lg : mv.spacing.xl,
                              ),
                              decoration: BoxDecoration(
                                color: mv.surfaceCard,
                                borderRadius: BorderRadius.circular(mv.radii.xl),
                                border: Border.all(color: mv.border),
                                boxShadow: mv.shadowMd,
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.stretch,
                                children: [
                                  Text(
                                    'Sign in with phone',
                                    style: theme.textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: mv.textPrimary,
                                    ),
                                  ),
                                  SizedBox(height: mv.spacing.xxs),
                                  Text(
                                    'We\'ll send a 4-digit OTP to verify you',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: mv.textMuted,
                                    ),
                                  ),
                                  SizedBox(height: mv.spacing.md),
                                  TextField(
                                    controller: _phoneController,
                                    keyboardType: TextInputType.phone,
                                    textInputAction: TextInputAction.done,
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                      LengthLimitingTextInputFormatter(10),
                                    ],
                                    onChanged: (_) =>
                                        setState(() => _feedbackText = null),
                                    onSubmitted: (_) {
                                      if (!_isLoading) _sendOtp();
                                    },
                                    style: theme.textTheme.bodyLarge?.copyWith(
                                      color: mv.textPrimary,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'Enter mobile number',
                                      prefixIcon: Padding(
                                        padding: EdgeInsets.only(
                                          left: mv.spacing.md,
                                          right: mv.spacing.xs,
                                        ),
                                        child: Text(
                                          '+91',
                                          style: theme.textTheme.titleSmall?.copyWith(
                                            fontWeight: FontWeight.w700,
                                            color: mv.textPrimary,
                                          ),
                                        ),
                                      ),
                                      prefixIconConstraints:
                                          const BoxConstraints(minWidth: 0),
                                    ),
                                  ),
                                  if (helperText.isNotEmpty) ...[
                                    SizedBox(height: mv.spacing.xs),
                                    Text(
                                      helperText,
                                      maxLines: 3,
                                      overflow: TextOverflow.ellipsis,
                                      style: theme.textTheme.bodySmall?.copyWith(
                                        color: helperColor,
                                      ),
                                    ),
                                  ],
                                  SizedBox(height: mv.spacing.xs),
                                  Row(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Checkbox(
                                        value: _acceptedTerms,
                                        activeColor: mv.brandPrimary,
                                        visualDensity: VisualDensity.compact,
                                        onChanged: _isLoading
                                            ? null
                                            : (value) => setState(
                                                  () => _acceptedTerms = value ?? false,
                                                ),
                                      ),
                                      Expanded(
                                        child: Padding(
                                          padding: EdgeInsets.only(top: mv.spacing.sm),
                                          child: Text(
                                            'I agree to the Terms & Privacy Policy',
                                            style: theme.textTheme.bodySmall?.copyWith(
                                              color: mv.textSecondary,
                                              height: 1.4,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  SizedBox(height: mv.spacing.lg),
                                  SizedBox(
                                    height: 52,
                                    child: ElevatedButton(
                                      onPressed: _isLoading ? null : _sendOtp,
                                      child: _isLoading
                                          ? const SizedBox(
                                              width: 20,
                                              height: 20,
                                              child: CircularProgressIndicator(
                                                strokeWidth: 2,
                                                color: Colors.white,
                                              ),
                                            )
                                          : const Text('Send OTP'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(height: mv.spacing.lg),
                            Text(
                              'New here? We\'ll create your account automatically',
                              textAlign: TextAlign.center,
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: mv.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}
