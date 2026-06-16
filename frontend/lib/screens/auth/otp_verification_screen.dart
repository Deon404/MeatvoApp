import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../core/constants/app_constants.dart';
import '../../navigation/app_destinations.dart';
import '../../services/auth_service.dart';
import '../../utils/responsive_helper.dart';

/// LEGACY: This screen is no longer used in the app flow.
/// The active auth path uses [OtpScreen] (4-box OTP) instead.
/// This implementation uses a single centered OTP field with SMS autofill.
class OTPVerificationScreen extends StatefulWidget {
  const OTPVerificationScreen({
    super.key,
    required this.phoneNumber,
    this.prefilledOtp,
  });

  final String phoneNumber;
  final String? prefilledOtp;

  @override
  State<OTPVerificationScreen> createState() => _OTPVerificationScreenState();
}

class _OTPVerificationScreenState extends State<OTPVerificationScreen>
    with CodeAutoFill {
  final _otpController = TextEditingController();
  final _authService = AuthService();
  Timer? _resendTimer;
  bool _isLoading = false;
  bool _canResend = false;
  int _secondsLeft = 30;
  String? _errorText;

  String? _normalizeOtp(String? raw) {
    if (raw == null) return null;
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    if (digits.length < 4) return null;
    return digits.substring(0, 4);
  }

  void _applyOtp(String otp, {bool autoVerify = false}) {
    _otpController.text = otp;
    _otpController.selection = TextSelection.fromPosition(
      TextPosition(offset: otp.length),
    );
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
    if (autoVerify && !_isLoading) {
      _verifyOtp();
    }
  }

  @override
  void codeUpdated() {
    final otp = _normalizeOtp(code);
    if (otp == null || !mounted) return;
    _applyOtp(otp, autoVerify: true);
  }

  @override
  void initState() {
    super.initState();
    listenForCode();
    final prefill = _normalizeOtp(widget.prefilledOtp);
    if (prefill != null) {
      _applyOtp(prefill);
    }
    _startResendTimer();
  }

  @override
  void dispose() {
    cancel();
    unregisterListener();
    _resendTimer?.cancel();
    _otpController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() {
      _canResend = false;
      _secondsLeft = 30;
    });
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      if (_secondsLeft == 1) {
        timer.cancel();
        setState(() {
          _secondsLeft = 0;
          _canResend = true;
        });
        return;
      }
      setState(() => _secondsLeft--);
    });
  }

  String get _displayPhone {
    final digits = widget.phoneNumber.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      return '+91 ${digits.substring(digits.length - 10)}';
    }
    return widget.phoneNumber.isNotEmpty ? widget.phoneNumber : 'your number';
  }

  Future<void> _verifyOtp() async {
    final rawOtp = _otpController.text.trim().replaceAll(RegExp(r'\D'), '');
    final otp = rawOtp.padLeft(4, '0');
    if (!RegExp(r'^\d{4}$').hasMatch(otp)) {
      setState(() => _errorText = 'Please enter the 4-digit OTP.');
      return;
    }
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      final user = await _authService.verifyOTP(widget.phoneNumber, otp);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Welcome to Meatvo!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => destinationAfterAuth(role: user.role),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception:', '').trim();
      setState(
        () => _errorText = message.isEmpty ? 'Invalid OTP. Please try again.' : message,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _resendOtp() async {
    if (!_canResend || _isLoading) return;
    setState(() {
      _isLoading = true;
      _errorText = null;
    });
    try {
      await _authService.resendOTP(widget.phoneNumber);
      _otpController.clear();
      listenForCode();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
      _startResendTimer();
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception:', '').trim();
      setState(() => _errorText = message.isEmpty ? 'Failed to resend OTP.' : message);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mv = context.meatvo;
    final theme = Theme.of(context);
    final media = MediaQuery.of(context);
    final horizontal = media.size.width > 480
        ? ((media.size.width - 420) / 2).clamp(24.0, 56.0).toDouble()
        : mv.spacing.xl;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                horizontal,
                mv.spacing.xl,
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
                        Container(
                          padding: EdgeInsets.all(mv.spacing.xl),
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
                                'Verify OTP',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: mv.textPrimary,
                                ),
                              ),
                              SizedBox(height: mv.spacing.sm),
                              Text(
                                'Enter the 4-digit code sent to $_displayPhone',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: mv.textSecondary,
                                  height: 1.5,
                                ),
                              ),
                              TextButton(
                                onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
                                child: const Text('Change number'),
                              ),
                              SizedBox(height: mv.spacing.sm),
                              AutofillGroup(
                                child: TextField(
                                  controller: _otpController,
                                  autofocus: true,
                                  autofillHints: const [AutofillHints.oneTimeCode],
                                  keyboardType: TextInputType.number,
                                  textInputAction: TextInputAction.done,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.headlineSmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    letterSpacing: 12,
                                    color: mv.textPrimary,
                                  ),
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                    LengthLimitingTextInputFormatter(4),
                                  ],
                                  decoration: InputDecoration(
                                    hintText: '0000',
                                    counterText: '',
                                    filled: true,
                                    fillColor: AppColors.surfaceMuted,
                                    contentPadding: const EdgeInsets.symmetric(vertical: 18),
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(mv.radii.md),
                                      borderSide: BorderSide(color: mv.border),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(mv.radii.md),
                                      borderSide: BorderSide(
                                        color: mv.brandPrimary,
                                        width: 1.4,
                                      ),
                                    ),
                                  ),
                                  onChanged: (value) {
                                    if (_errorText != null) {
                                      setState(() => _errorText = null);
                                    }
                                    final digits = value.replaceAll(RegExp(r'\D'), '');
                                    if (digits.length == 4 && !_isLoading) {
                                      _verifyOtp();
                                    }
                                  },
                                  onSubmitted: (_) => _verifyOtp(),
                                ),
                              ),
                              SizedBox(height: mv.spacing.sm),
                              if (_errorText != null)
                                Text(
                                  _errorText!,
                                  textAlign: TextAlign.center,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: Colors.red,
                                  ),
                                ),
                              SizedBox(height: mv.spacing.sm),
                              TextButton(
                                onPressed: _canResend && !_isLoading ? _resendOtp : null,
                                child: Text(
                                  _canResend
                                      ? 'Resend OTP'
                                      : 'Resend OTP in $_secondsLeft seconds',
                                ),
                              ),
                              SizedBox(height: mv.spacing.md),
                              SizedBox(
                                height: 52,
                                child: ElevatedButton(
                                  onPressed: _isLoading ? null : _verifyOtp,
                                  child: _isLoading
                                      ? const SizedBox(
                                          height: 20,
                                          width: 20,
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2,
                                            valueColor: AlwaysStoppedAnimation<Color>(
                                              Colors.white,
                                            ),
                                          ),
                                        )
                                      : const Text(
                                          'Verify & Continue',
                                          style: TextStyle(fontWeight: FontWeight.w600),
                                        ),
                                ),
                              ),
                            ],
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
    );
  }
}
