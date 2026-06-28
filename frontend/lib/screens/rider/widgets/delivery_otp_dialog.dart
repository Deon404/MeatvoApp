import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../core/constants/app_constants.dart';

const _otpLength = 6;

/// Shows a 6-digit delivery OTP dialog. Returns the OTP on verify, or `null` on cancel.
Future<String?> showDeliveryOtpDialog(BuildContext context) {
  return showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const DeliveryOtpDialog(),
  );
}

class DeliveryOtpDialog extends StatefulWidget {
  const DeliveryOtpDialog({super.key});

  @override
  State<DeliveryOtpDialog> createState() => _DeliveryOtpDialogState();
}

class _DeliveryOtpDialogState extends State<DeliveryOtpDialog> {
  final List<TextEditingController> _controllers =
      List.generate(_otpLength, (_) => TextEditingController());
  final List<FocusNode> _focusNodes =
      List.generate(_otpLength, (_) => FocusNode());

  String? _errorText;

  String get _otpValue =>
      _controllers.map((c) => c.text).join().replaceAll(RegExp(r'\D'), '');

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focusNodes.first.requestFocus();
    });
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _onOtpChanged(int index, String value) {
    final digits = value.replaceAll(RegExp(r'\D'), '');
    if (digits.length > 1) {
      _applyDigits(digits);
      return;
    }

    if (digits.isEmpty) return;

    _controllers[index].text = digits;
    _controllers[index].selection = const TextSelection.collapsed(offset: 1);

    if (index < _otpLength - 1) {
      _focusNodes[index + 1].requestFocus();
    } else {
      _focusNodes[index].unfocus();
    }

    if (_errorText != null) {
      setState(() => _errorText = null);
    }
  }

  void _applyDigits(String raw) {
    final digits = raw.replaceAll(RegExp(r'\D'), '');
    var cursor = 0;
    for (final d in digits.split('')) {
      if (cursor >= _otpLength) break;
      _controllers[cursor].text = d;
      _controllers[cursor].selection = const TextSelection.collapsed(offset: 1);
      cursor++;
    }
    if (cursor < _otpLength) {
      _focusNodes[cursor].requestFocus();
    } else {
      _focusNodes.last.unfocus();
    }
    if (_errorText != null) {
      setState(() => _errorText = null);
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

  void _verify() {
    final otp = _otpValue;
    if (!RegExp(r'^\d{6}$').hasMatch(otp)) {
      setState(() => _errorText = 'Please enter the 6-digit OTP from the customer.');
      return;
    }
    Navigator.of(context).pop(otp);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      title: const Text('Delivery OTP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Text(
            'Ask the customer for their delivery OTP and enter it below.',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_otpLength, (index) {
              return Padding(
                padding: EdgeInsets.only(
                  right: index < _otpLength - 1 ? AppSpacing.xs : 0,
                ),
                child: SizedBox(
                  width: 40,
                  height: 48,
                  child: Focus(
                    onKeyEvent: (_, event) => _onKeyEvent(index, event),
                    child: TextField(
                      controller: _controllers[index],
                      focusNode: _focusNodes[index],
                      textAlign: TextAlign.center,
                      keyboardType: TextInputType.number,
                      maxLength: 1,
                      style: AppTextStyles.body.copyWith(
                        fontWeight: FontWeight.w600,
                        fontSize: 18,
                      ),
                      inputFormatters: [
                        FilteringTextInputFormatter.digitsOnly,
                      ],
                      decoration: InputDecoration(
                        counterText: '',
                        contentPadding: EdgeInsets.zero,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                        ),
                        focusedBorder: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(AppRadius.chip),
                          borderSide: const BorderSide(
                            color: AppColors.primary,
                            width: 2,
                          ),
                        ),
                      ),
                      onChanged: (value) => _onOtpChanged(index, value),
                    ),
                  ),
                ),
              );
            }),
          ),
          if (_errorText != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _errorText!,
              textAlign: TextAlign.center,
              style: AppTextStyles.caption.copyWith(color: Colors.red),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        ElevatedButton(
          onPressed: _verify,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
          ),
          child: const Text('Verify & Deliver'),
        ),
      ],
    );
  }
}
