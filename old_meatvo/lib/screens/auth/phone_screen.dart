import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../config/backend_resolver.dart';
import '../../core/constants/app_constants.dart';
import '../../services/auth_service.dart';
import '../../utils/app_transitions.dart';
import 'otp_screen.dart';

class PhoneScreen extends StatefulWidget {
  const PhoneScreen({super.key});

  @override
  State<PhoneScreen> createState() => _PhoneScreenState();
}

class _PhoneScreenState extends State<PhoneScreen> {
  static const _bgColor = Color(0xFFFFF5F5);
  static const _brandRed = Color(0xFFC8102E);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textMuted = Color(0xFF6B6B6B);
  static const _borderDefault = Color(0xFFE5E5E5);
  static const _buttonDisabled = Color(0xFFE0E0E0);
  static const _buttonDisabledText = Color(0xFF9E9E9E);

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
    if (lower.contains('server tak') ||
        lower.contains('meatvo_api_root') ||
        lower.contains('cannot reach') ||
        lower.contains('connection') ||
        lower.contains('network')) {
      return BackendResolver.connectionHelpMessage();
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
      final devOtp = await _authService.sendOtp(phoneE164);
      if (!mounted) return;

      Navigator.of(context).push(
        AppTransitions.slideFade(
          OtpScreen(phone: phoneE164, prefilledOtp: devOtp),
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
    final phone = _phoneController.text.trim();
    final phoneFocused = _phoneFocusNode.hasFocus;

    final helperText = _feedbackText ??
        (phone.isEmpty
            ? ''
            : _isValidPhone(phone)
                ? 'OTP will be sent to +91 $phone'
                : 'Enter a valid 10-digit mobile number.');
    final helperColor = _feedbackText != null
        ? Colors.red
        : _isValidPhone(phone)
            ? AppColors.success
            : _textMuted;

    final buttonColor = _hasTenDigits ? _brandRed : _buttonDisabled;
    final buttonTextColor = _hasTenDigits ? Colors.white : _buttonDisabledText;

    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: _bgColor,
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset(
            'assets/images/login_background.png',
            fit: BoxFit.cover,
          ),
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.white.withOpacity(0.95),
                  Colors.white.withOpacity(0.90),
                  const Color(0xFFFFF5F5).withOpacity(0.85),
                ],
              ),
            ),
          ),
          SafeArea(
            child: LayoutBuilder(
              builder: (context, constraints) {
                final keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
                final keyboardVisible = keyboardHeight > 0;
                
                return SingleChildScrollView(
                  child: Container(
                    height: constraints.maxHeight,
                    padding: EdgeInsets.only(bottom: keyboardHeight > 0 ? 20 : 0),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Meatvo',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 32,
                            fontWeight: FontWeight.w700,
                            color: _textPrimary,
                            letterSpacing: -0.5,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Fresh • Hygienic • Reliable',
                          style: TextStyle(
                            fontFamily: 'Poppins',
                            fontSize: 13,
                            color: _textMuted,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        SizedBox(height: keyboardVisible ? 20 : 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Container(
                            padding: const EdgeInsets.all(28),
                            decoration: BoxDecoration(
                              color: Colors.white.withOpacity(0.8),
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: Colors.white.withOpacity(0.6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withOpacity(0.06),
                                  blurRadius: 30,
                                  offset: const Offset(0, 10),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Enter your mobile',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                const Text(
                                  "We'll send a 4-digit OTP to verify",
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 13,
                                    color: _textMuted,
                                  ),
                                ),
                                const SizedBox(height: 24),
                                Material(
                                  color: Colors.transparent,
                                  child: Container(
                                    height: 56,
                                    decoration: BoxDecoration(
                                      color: Colors.white,
                                      borderRadius: BorderRadius.circular(12),
                                      border: Border.all(
                                        color: phoneFocused ? _brandRed : _borderDefault,
                                        width: phoneFocused ? 2 : 1,
                                      ),
                                      boxShadow: phoneFocused
                                          ? [
                                              BoxShadow(
                                                color: _brandRed.withOpacity(0.1),
                                                blurRadius: 8,
                                                offset: const Offset(0, 2),
                                              ),
                                            ]
                                          : null,
                                    ),
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(11),
                                      child: Row(
                                        children: [
                                          Container(
                                            color: Colors.white,
                                            padding: const EdgeInsets.symmetric(horizontal: 16),
                                            child: const Text(
                                              '+91',
                                              style: TextStyle(
                                                fontFamily: 'Poppins',
                                                fontSize: 15,
                                                fontWeight: FontWeight.w600,
                                                color: _textPrimary,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            width: 1,
                                            height: 24,
                                            color: _borderDefault,
                                          ),
                                          Expanded(
                                            child: Container(
                                              color: Colors.white,
                                              child: TextField(
                                                controller: _phoneController,
                                                focusNode: _phoneFocusNode,
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
                                                style: const TextStyle(
                                                  fontFamily: 'Poppins',
                                                  fontSize: 15,
                                                  fontWeight: FontWeight.w500,
                                                  color: _textPrimary,
                                                ),
                                                decoration: const InputDecoration(
                                                  hintText: 'Enter mobile number',
                                                  hintStyle: TextStyle(
                                                    fontFamily: 'Poppins',
                                                    fontSize: 15,
                                                    color: _textMuted,
                                                  ),
                                                  border: InputBorder.none,
                                                  enabledBorder: InputBorder.none,
                                                  focusedBorder: InputBorder.none,
                                                  errorBorder: InputBorder.none,
                                                  focusedErrorBorder: InputBorder.none,
                                                  contentPadding: EdgeInsets.symmetric(
                                                    horizontal: 16,
                                                  ),
                                                  filled: true,
                                                  fillColor: Colors.white,
                                                ),
                                              ),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                                if (helperText.isNotEmpty) ...[
                                  const SizedBox(height: 8),
                                  Text(
                                    helperText,
                                    maxLines: 3,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 12,
                                      color: helperColor,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 16),
                                Row(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Icon(
                                      Icons.lock_outline,
                                      size: 16,
                                      color: _textMuted,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: RichText(
                                        text: const TextSpan(
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 11,
                                            color: _textMuted,
                                            height: 1.4,
                                          ),
                                          children: [
                                            TextSpan(
                                              text: 'By continuing, you agree to our ',
                                            ),
                                            TextSpan(
                                              text: 'Terms of Services',
                                              style: TextStyle(
                                                color: _brandRed,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                            TextSpan(
                                              text: ' and ',
                                            ),
                                            TextSpan(
                                              text: 'Privacy Policy',
                                              style: TextStyle(
                                                color: _brandRed,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: keyboardVisible ? 20 : 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: SizedBox(
                            width: double.infinity,
                            height: 56,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _sendOtp,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: buttonColor,
                                foregroundColor: buttonTextColor,
                                disabledBackgroundColor: buttonColor,
                                disabledForegroundColor: buttonTextColor,
                                elevation: _hasTenDigits ? 8 : 0,
                                shadowColor: _brandRed.withOpacity(0.4),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: _isLoading
                                  ? const SizedBox(
                                      width: 20,
                                      height: 20,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : const Text(
                                      'Continue',
                                      style: TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 16,
                                        fontWeight: FontWeight.w600,
                                        letterSpacing: 0.5,
                                      ),
                                    ),
                            ),
                          ),
                        ),
                      ],
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
