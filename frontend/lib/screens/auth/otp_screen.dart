import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:sms_autofill/sms_autofill.dart';

import '../../config/backend_resolver.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../navigation/app_destinations.dart';
import '../../services/auth_service.dart';
import 'auth_login_widgets.dart';
import 'auth_screen_shell.dart';

class OtpScreen extends StatefulWidget {
  const OtpScreen({
    super.key,
    required this.phone,
    this.prefilledOtp,
    this.initialResendSeconds,
    this.otpAlreadySent = false,
  });

  final String phone;
  final String? prefilledOtp;
  final int? initialResendSeconds;
  final bool otpAlreadySent;

  @override
  State<OtpScreen> createState() => _OtpScreenState();
}

class _OtpScreenState extends State<OtpScreen> with CodeAutoFill {
  static const _otpLength = 4;

  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());
  final TextEditingController _autofillController = TextEditingController();
  final AuthService _authService = AuthService();

  Timer? _resendTimer;
  bool _isLoading = false;
  bool _canResend = false;
  bool _autoVerifyScheduled = false;
  int _secondsLeft = 30;
  String? _errorText;

  String get _otpValue =>
      _controllers.map((c) => c.text).join().replaceAll(RegExp(r'\D'), '');

  bool get _isOtpComplete => _otpValue.length == _otpLength;

  String get _maskedPhone {
    final digits = widget.phone.replaceAll(RegExp(r'\D'), '');
    if (digits.length >= 10) {
      final local = digits.substring(digits.length - 10);
      return 'XX ${local.substring(6)}';
    }
    return widget.phone;
  }

  @override
  void initState() {
    super.initState();
    listenForCode();
    for (final controller in _controllers) {
      controller.addListener(_scheduleAutoVerify);
    }
    _autofillController.addListener(_onAutofillControllerChanged);
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
    _applyOtpDigits(digits.substring(0, _otpLength));
  }

  void _applyPrefill() {
    final raw = widget.prefilledOtp?.replaceAll(RegExp(r'\D'), '');
    if (raw == null || raw.length < _otpLength) return;
    _applyOtpDigits(raw.substring(0, _otpLength));
  }

  void _applyOtpDigits(String otp) {
    for (var i = 0; i < _otpLength; i++) {
      _controllers[i].text = otp[i];
      _controllers[i].selection = const TextSelection.collapsed(offset: 1);
    }
    if (_errorText != null) {
      setState(() => _errorText = null);
    }
    _scheduleAutoVerify();
  }

  void _onAutofillControllerChanged() {
    final digits =
        _autofillController.text.replaceAll(RegExp(r'\D'), '');
    if (digits.length < _otpLength) return;
    _applyOtpDigits(digits.substring(0, _otpLength));
  }

  void _scheduleAutoVerify() {
    if (_autoVerifyScheduled || _isLoading || !_isOtpComplete) return;
    _autoVerifyScheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _autoVerifyScheduled = false;
      if (!mounted || _isLoading || !_isOtpComplete) return;
      _verifyOtp();
    });
  }

  @override
  void dispose() {
    cancel();
    unregisterListener();
    _resendTimer?.cancel();
    for (final c in _controllers) {
      c.removeListener(_scheduleAutoVerify);
      c.dispose();
    }
    _autofillController.removeListener(_onAutofillControllerChanged);
    _autofillController.dispose();
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startResendTimer({int? seconds}) {
    _resendTimer?.cancel();
    final start = (seconds ?? widget.initialResendSeconds ?? 30).clamp(0, 600);
    setState(() {
      _canResend = start <= 0;
      _secondsLeft = start;
    });
    if (start <= 0) return;

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
    _autofillController.clear();
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

    _scheduleAutoVerify();
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
      _scheduleAutoVerify();
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

      TextInput.finishAutofillContext(shouldSave: false);
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => destinationAfterAuth(role: user.role),
        ),
        (route) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorText = BackendResolver.toUserMessage(
          error,
          fallback: 'Invalid OTP. Please try again.',
        ),
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
        SnackBar(
          content: const Text('OTP sent successfully!'),
          backgroundColor: context.meatvo.freshBadge,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _errorText = BackendResolver.toUserMessage(
          error,
          fallback: 'Failed to resend OTP. Please try again.',
        ),
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
    final mv = context.meatvo;
    final theme = Theme.of(context);

    final linkStyle = theme.textTheme.bodySmall?.copyWith(
      color: mv.brandPrimary,
      fontWeight: FontWeight.w600,
      decoration: TextDecoration.underline,
      decorationColor: mv.brandPrimary,
    );

    return AuthScreenShell(
      bottomFooter: const AuthLegalFooter(),
      children: [
        const AuthLogoHeader(compact: true),
        SizedBox(height: mv.spacing.xl),
        Text(
          '4 digit OTP verification sent on $_maskedPhone',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodySmall?.copyWith(
            color: mv.textSecondary,
            height: 1.4,
          ),
        ),
        if (widget.otpAlreadySent) ...[
          SizedBox(height: mv.spacing.md),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(
              horizontal: mv.spacing.sm,
              vertical: mv.spacing.sm,
            ),
            decoration: BoxDecoration(
              color: mv.freshBadge.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(mv.radii.md),
              border: Border.all(
                color: mv.freshBadge.withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.info_outline_rounded,
                  size: 18,
                  color: mv.freshBadge,
                ),
                SizedBox(width: mv.spacing.xs),
                Expanded(
                  child: Text(
                    'An OTP was already sent to this number. '
                    'Please use the code from your previous SMS.',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mv.textPrimary,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        SizedBox(height: mv.spacing.xl),
        AutofillGroup(
          child: Column(
            children: [
              SizedBox(
                height: 0,
                width: 0,
                child: Opacity(
                  opacity: 0,
                  child: TextField(
                    controller: _autofillController,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    keyboardType: TextInputType.number,
                    maxLength: _otpLength,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                    ],
                    decoration: const InputDecoration(
                      counterText: '',
                      border: InputBorder.none,
                    ),
                  ),
                ),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: List.generate(_otpLength, (index) {
                  return Padding(
                    padding: EdgeInsets.only(
                      right: index < _otpLength - 1 ? mv.spacing.xs : 0,
                    ),
                    child: _OtpBox(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      onChanged: (value) => _onOtpChanged(index, value),
                      onKeyEvent: (_, event) => _onKeyEvent(index, event),
                      enabled: !_isLoading,
                      hasError: _errorText != null,
                    ),
                  );
                }),
              ),
            ],
          ),
        ),
        if (_errorText != null) ...[
          SizedBox(height: mv.spacing.md),
          Text(
            _errorText!,
            style: theme.textTheme.bodySmall?.copyWith(
              color: mv.error,
              fontWeight: FontWeight.w500,
            ),
            textAlign: TextAlign.center,
          ),
        ],
        SizedBox(height: mv.spacing.xl),
        AuthPrimaryButton(
          label: 'Continue',
          isLoading: _isLoading,
          enabled: _isOtpComplete,
          onPressed: _verifyOtp,
        ),
        SizedBox(height: mv.spacing.md),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _isLoading ? null : () => Navigator.of(context).pop(),
              style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: Size.zero,
                tapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
              child: Text('Change number', style: linkStyle),
            ),
            _canResend
                ? TextButton(
                    onPressed: _isLoading ? null : _resendOtp,
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: Text('Resend OTP', style: linkStyle),
                  )
                : Text(
                    _timerLabel,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: mv.textMuted,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
          ],
        ),
        SizedBox(height: mv.spacing.lg),
        const AuthOrderUpdatesToggle(),
      ],
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
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final ValueChanged<String> onChanged;
  final KeyEventResult Function(FocusNode, KeyEvent) onKeyEvent;
  final bool enabled;
  final bool hasError;

  @override
  State<_OtpBox> createState() => _OtpBoxState();
}

class _OtpBoxState extends State<_OtpBox> {
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
    final mv = context.meatvo;
    final theme = Theme.of(context);
    final focused = widget.focusNode.hasFocus;
    final filled = widget.controller.text.isNotEmpty;

    Color borderColor;
    double borderWidth = 1.5;
    if (widget.hasError) {
      borderColor = mv.error;
      borderWidth = 2;
    } else if (focused) {
      borderColor = mv.brandPrimary;
      borderWidth = 2;
    } else if (filled) {
      borderColor = mv.brandPrimary;
    } else {
      borderColor = mv.border;
    }

    return SizedBox(
      width: 56,
      height: 60,
      child: Focus(
        onKeyEvent: (node, event) => widget.onKeyEvent(node, event),
        child: Container(
          decoration: BoxDecoration(
            color: mv.surfaceCard,
            borderRadius: BorderRadius.circular(mv.radii.md),
            border: Border.all(color: borderColor, width: borderWidth),
            boxShadow: focused || filled
                ? [
                    BoxShadow(
                      color: (widget.hasError ? mv.error : mv.brandPrimary)
                          .withValues(alpha: 0.15),
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
            style: theme.textTheme.headlineSmall?.copyWith(
              color: mv.textPrimary,
              fontWeight: FontWeight.w700,
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
