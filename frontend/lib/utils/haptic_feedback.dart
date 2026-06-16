import 'package:flutter/services.dart';

/// Premium haptic feedback utility
class HapticUtils {
  /// Light impact - for button taps, card taps
  static void lightImpact() {
    HapticFeedback.lightImpact();
  }

  /// Medium impact - for important actions
  static void mediumImpact() {
    HapticFeedback.mediumImpact();
  }

  /// Heavy impact - for errors, confirmations
  static void heavyImpact() {
    HapticFeedback.heavyImpact();
  }

  /// Selection feedback - for switches, toggles
  static void selectionClick() {
    HapticFeedback.selectionClick();
  }

  /// Vibrate - for notifications
  static void vibrate() {
    HapticFeedback.vibrate();
  }

  /// Success feedback (light + selection)
  static void success() {
    HapticFeedback.lightImpact();
    Future.delayed(const Duration(milliseconds: 50), () {
      HapticFeedback.selectionClick();
    });
  }

  /// Error feedback (heavy impact)
  static void error() {
    HapticFeedback.heavyImpact();
  }

  /// Warning feedback (medium impact)
  static void warning() {
    HapticFeedback.mediumImpact();
  }
}
