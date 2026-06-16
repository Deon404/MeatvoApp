import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../core/constants/app_constants.dart';
import '../../navigation/app_destinations.dart';
import '../../services/auth_service.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    this.prefilledOtp,
  });

  final String phone;
  final String? prefilledOtp;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with CodeAutoFill {
  static const _otpLength = 4;

  static const _bgColor = Color(0xFFFFF5F5);
  static const _brandRed = Color(0xFFC8102E);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _textMuted = Color(0xFF6B6B6B);
  static const _buttonDisabled = Color(0xFFE0E0E0);
  static const _buttonDisabledText = Color(0xFF9E9E9E);

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());
  final AuthService _authService = AuthService();

  Timer? _resendTimer;
  bool _isLoading = false;
  bool _canResend = false;
  int _secondsLeft = 30;
  String? _errorText;

  String get _otpValue =>
      _controllers.map((c) => c.text).join().replaceAll(RegExp(r'\D'), '');

  bool get _isOtpComplete => _otpValue.length == _otpLength;

  String get _maskedPhone {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final local = digits.substring(digits.length - 10);
      return '+91 ${local.substring(0, 2)}****${local.substring(6)}';
    }
    return widget.phone;
  }

  @override
  void initState() {
    super.initState();
    listenForCode();
    _startResendTimer();
    _applyPrefill();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes.first.requestFocus();
    });
  }

  @override
  void codeUpdated() {
    final digits = code?.replaceAll(RegExp(r'\D'), '');
    if (digits == null || digits.length < _otpLength || !mounted) return;
    _applyOtpDigits(digits.substring(0, _otpLength), autoVerify: true);
  }

  void _applyPrefill() {
    final raw = widget.prefilledOtp?.replaceAll(RegExp(r'\D'), '');
    if (raw == null || raw.length < _otpLength) return;
    _applyOtpDigits(raw.substring(0, _otpLength));
  }

  void _applyOtpDigits(String otp, {bool autoVerify = false}) {
    for (var i = 0; i < _otpLength; i++) {
      _controllers[i].text = otp[i];
    }
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
    if (autoVerify && !_isLoading) {
      _verifyOtp();
    }
  }

  @override
  void dispose() {
    cancel();
    unregisterListener();
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
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
      if (_secondsLeft <= 1) {
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

  void _clearOtp() {
    for (final c in _controllers) {
      c.clear();
    }
    _focusNodes.first.requestFocus();
  }

  void _onOtpChanged(int index, String value) {
    if (_errorText != null) {
      setState(() => _errorText = null);
    }

    final digits = value.replaceAll(RegExp(r'\D'), '');

    if (digits.length > 1) {
      _handlePaste(digits, startIndex: index);
      return;
    }

    if (digits.length == 1) {
      _controllers[index].text = digits;
      _controllers[index].selection = const TextSelection.collapsed(offset: 1);
      if (index < _otpLength - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else if (value.isEmpty && index > 0) {
      _focusNodes[index - 1].requestFocus();
    }

    if (_otpValue.length == _otpLength && !_isLoading) {
      _verifyOtp();
    }
  }

  void _handlePaste(String digits, {required int startIndex}) {
    var cursor = startIndex;
    for (var i = 0; i < digits.length; i++) {
      final d = digits[i];
      if (cursor >= _otpLength) break;
      if (!RegExp(r'\d').hasMatch(d)) continue;
      _controllers[cursor].text = d;
      cursor++;
    }
    if (cursor < _otpLength) {
      _focusNodes[cursor].requestFocus();
    } else {
      _focusNodes.last.unfocus();
      if (_otpValue.length == _otpLength && !_isLoading) {
        _verifyOtp();
      }
    }
  }

  KeyEventResult _onKeyEvent(int index, KeyEvent event) {
    if (event is! KeyDownEvent ||
        event.logicalKey != LogicalKeyboardKey.backspace) {
      return KeyEventResult.ignored;
    }
    if (_controllers[index].text.isEmpty && index > 0) {
      _controllers[index - 1].clear();
      _focusNodes[index - 1].requestFocus();
      return KeyEventResult.handled;
    }
    return KeyEventResult.ignored;
  }

  Future<void> _verifyOtp() async {
    final rawOtp = _otpValue.padLeft(_otpLength, '0');
    if (!RegExp(r'^\d{4}$').hasMatch(rawOtp)) {
      setState(() => _errorText = 'Please enter the 4-digit OTP.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorText = null;
    });

    try {
      final user = await _authService.verifyOtp(widget.phone, rawOtp);
      if (!mounted) return;

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
        () => _errorText =
            message.isEmpty ? 'Invalid OTP. Please try again.' : message,
      );
      _clearOtp();
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
      await _authService.sendOtp(widget.phone, resend: true);
      if (!mounted) return;
      _clearOtp();
      listenForCode();
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('OTP sent successfully!'),
          backgroundColor: AppColors.success,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      final message = error.toString().replaceFirst('Exception:', '').trim();
      setState(
        () => _errorText =
            message.isEmpty ? 'Failed to resend OTP.' : message,
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String get _timerLabel {
    final minutes = _secondsLeft ~/ 60;
    final seconds = _secondsLeft % 60;
    return 'Resend in $minutes:${seconds.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final buttonColor = _isOtpComplete ? _brandRed : _buttonDisabled;
    final buttonTextColor =
        _isOtpComplete ? Colors.white : _buttonDisabledText;

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
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                const Text(
                                  'Verify OTP',
                                  style: TextStyle(
                                    fontFamily: 'Poppins',
                                    fontSize: 22,
                                    fontWeight: FontWeight.w600,
                                    color: _textPrimary,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      'Sent to $_maskedPhone',
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: _textMuted,
                                      ),
                                    ),
                                    TextButton(
                                      onPressed: _isLoading
                                          ? null
                                          : () => Navigator.of(context).pop(),
                                      style: TextButton.styleFrom(
                                        padding:
                                            const EdgeInsets.symmetric(horizontal: 4),
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Change',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 13,
                                          fontWeight: FontWeight.w600,
                                          color: _brandRed,
                                          decoration: TextDecoration.underline,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 32),
                                AutofillGroup(
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: List.generate(_otpLength, (index) {
                                      return Padding(
                                        padding: EdgeInsets.only(
                                          right: index < _otpLength - 1 ? 8 : 0,
                                        ),
                                        child: _OtpBox(
                                          controller: _controllers[index],
                                          focusNode: _focusNodes[index],
                                          onChanged: (value) =>
                                              _onOtpChanged(index, value),
                                          onKeyEvent: (_, event) =>
                                              _onKeyEvent(index, event),
                                          enabled: !_isLoading,
                                          hasError: _errorText != null,
                                          autofillHints: index == 0
                                              ? const [AutofillHints.oneTimeCode]
                                              : null,
                                        ),
                                      );
                                    }),
                                  ),
                                ),
                                if (_errorText != null) ...[
                                  const SizedBox(height: 16),
                                  Text(
                                    _errorText!,
                                    style: const TextStyle(
                                      fontFamily: 'Poppins',
                                      fontSize: 13,
                                      color: Colors.red,
                                      fontWeight: FontWeight.w500,
                                    ),
                                    textAlign: TextAlign.center,
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                        SizedBox(height: keyboardVisible ? 20 : 40),
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 24),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: double.infinity,
                                height: 56,
                                child: ElevatedButton(
                                  onPressed: _isLoading || !_isOtpComplete
                                      ? null
                                      : _verifyOtp,
                                  style: ElevatedButton.styleFrom(
                                    backgroundColor: buttonColor,
                                    foregroundColor: buttonTextColor,
                                    disabledBackgroundColor: buttonColor,
                                    disabledForegroundColor: buttonTextColor,
                                    elevation: _isOtpComplete ? 8 : 0,
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
                                          'Verify & Continue',
                                          style: TextStyle(
                                            fontFamily: 'Poppins',
                                            fontSize: 16,
                                            fontWeight: FontWeight.w600,
                                            letterSpacing: 0.5,
                                          ),
                                        ),
                                ),
                              ),
                              const SizedBox(height: 16),
                              _canResend
                                  ? TextButton(
                                      onPressed: _isLoading ? null : _resendOtp,
                                      style: TextButton.styleFrom(
                                        padding: EdgeInsets.zero,
                                        minimumSize: Size.zero,
                                        tapTargetSize:
                                            MaterialTapTargetSize.shrinkWrap,
                                      ),
                                      child: const Text(
                                        'Resend OTP',
                                        style: TextStyle(
                                          fontFamily: 'Poppins',
                                          fontSize: 14,
                                          fontWeight: FontWeight.w600,
                                          color: _brandRed,
                                        ),
                                      ),
                                    )
                                  : Text(
                                      _timerLabel,
                                      style: const TextStyle(
                                        fontFamily: 'Poppins',
                                        fontSize: 13,
                                        color: _textMuted,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                            ],
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

class _OtpBox extends StatefulWidget {
  const _OtpBox({
    required this.controller,
    required this.focusNode,
    required this.onChanged,
    required this.onKeyEvent,
    this.enabled = true,
    this.hasError = false,
    this.autofillHints,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;
  final bool enabled;
  final bool hasError;
  final Iterable<String>? autofillHints;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
  static const _brandRed = Color(0xFFC8102E);
  static const _textPrimary = Color(0xFF1A1A1A);
  static const _borderDefault = Color(0xFFE5E5E5);

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_rebuild);
    widget.focusNode.addListener(_rebuild);
  }

  @override
  void didUpdateWidget(covariant _OtpBox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_rebuild);
      widget.controller.addListener(_rebuild);
    }
    if (oldWidget.focusNode != widget.focusNode) {
      oldWidget.focusNode.removeListener(_rebuild);
      widget.focusNode.addListener(_rebuild);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_rebuild);
    widget.focusNode.removeListener(_rebuild);
    super.dispose();
  }

  void _rebuild() => setState(() {});

  @override
  Widget build(BuildContext context) {
    final focused = widget.focusNode.hasFocus;
    final filled = widget.controller.text.isNotEmpty;

    Color borderColor;
    double borderWidth = 1.5;
    if (widget.hasError) {
      borderColor = Colors.red;
      borderWidth = 2;
    } else if (focused) {
      borderColor = _brandRed;
      borderWidth = 2;
    } else if (filled) {
      borderColor = _brandRed;
    } else {
      borderColor = _borderDefault;
    }

    return SizedBox(
      width: 56,
      height: 60,
      child: Focus(
        onKeyEvent: (node, event) => widget.onKeyEvent(node, event),
        child: Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: focused || filled
                ? [
                    BoxShadow(
                      color: (widget.hasError ? Colors.red : _brandRed)
                          .withOpacity(0.15),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ]
                : null,
          ),
          alignment: Alignment.center,
          child: TextField(
            controller: widget.controller,
            focusNode: widget.focusNode,
            enabled: widget.enabled,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 1,
            autofillHints: widget.autofillHints,
            style: const TextStyle(
              fontFamily: 'Poppins',
              fontSize: 24,
              fontWeight: FontWeight.w700,
              color: _textPrimary,
            ),
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: const InputDecoration(
              counterText: '',
              border: InputBorder.none,
              enabledBorder: InputBorder.none,
              focusedBorder: InputBorder.none,
              errorBorder: InputBorder.none,
              focusedErrorBorder: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              isDense: true,
            ),
            onChanged: widget.onChanged,
          ),
        ),
      ),
    );
  }
}
