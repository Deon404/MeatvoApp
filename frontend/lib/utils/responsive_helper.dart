import 'package:flutter/material.dart';

/// Screen-relative sizing for ~5"–6.7" Android devices (720p–1080p).
class R {
  static late MediaQueryData _mq;

  static void init(BuildContext context) {
    _mq = MediaQuery.of(context);
  }

  static double _height([BuildContext? context]) {
    if (context != null) return MediaQuery.sizeOf(context).height;
    return _mq.size.height;
  }

  static double _width([BuildContext? context]) {
    if (context != null) return MediaQuery.sizeOf(context).width;
    return _mq.size.width;
  }

  /// Screen height percentage (0–100).
  static double sh(double percent, [BuildContext? context]) {
    return _height(context) * (percent / 100);
  }

  /// Screen width percentage (0–100).
  static double sw(double percent, [BuildContext? context]) {
    return _width(context) * (percent / 100);
  }

  /// Bottom safe padding (keyboard + home indicator + spacing).
  static double bottomPadding(BuildContext context) =>
      MediaQuery.viewInsetsOf(context).bottom +
      MediaQuery.paddingOf(context).bottom +
      16;

  /// Top safe padding (notch / status bar).
  static double topPadding(BuildContext context) =>
      MediaQuery.paddingOf(context).top;

  /// Small screen if logical height &lt; 600.
  static bool isSmallScreen(BuildContext context) =>
      MediaQuery.sizeOf(context).height < 600;

  /// Adaptive font size (375pt design width baseline).
  static double fontSize(double base, BuildContext context) {
    final scale = MediaQuery.sizeOf(context).width / 375;
    return (base * scale).clamp(base * 0.85, base * 1.2);
  }
}

// --- Legacy fraction-based API (0.0–1.0) used across the codebase ---

double sh(BuildContext context, double fraction) {
  assert(fraction >= 0 && fraction <= 1, 'fraction must be between 0 and 1');
  return MediaQuery.sizeOf(context).height * fraction;
}

double sw(BuildContext context, double fraction) {
  assert(fraction >= 0 && fraction <= 1, 'fraction must be between 0 and 1');
  return MediaQuery.sizeOf(context).width * fraction;
}

double bottomPadding(BuildContext context) {
  return MediaQuery.paddingOf(context).bottom;
}

double keyboardInset(BuildContext context) {
  return MediaQuery.viewInsetsOf(context).bottom;
}

double sheetBottomPadding(BuildContext context, {double extra = 16}) {
  return R.bottomPadding(context) - 16 + extra;
}

EdgeInsets modalSheetInsets(
  BuildContext context, {
  double horizontal = 20,
  double top = 20,
  double extraBottom = 16,
}) {
  return EdgeInsets.only(
    left: horizontal,
    right: horizontal,
    top: top,
    bottom: MediaQuery.viewInsetsOf(context).bottom +
        MediaQuery.paddingOf(context).bottom +
        extraBottom,
  );
}

SizedBox vGap(BuildContext context, [double fraction = 0.02]) {
  return SizedBox(height: sh(context, fraction));
}

bool isCompactScreenHeight(BuildContext context) {
  return MediaQuery.sizeOf(context).height < 720;
}

/// Converts a fixed logical height to a screen-height percent for [R.sh].
double heightToPercent(BuildContext context, double logicalHeight) {
  final h = MediaQuery.sizeOf(context).height;
  if (h <= 0) return logicalHeight;
  return (logicalHeight / h * 100).clamp(1, 100);
}

/// Form / OTP screens: scroll + keyboard inset padding.
Widget keyboardAwareForm({
  required BuildContext context,
  required Widget child,
  EdgeInsetsGeometry? padding,
}) {
  return Padding(
    padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
    child: SingleChildScrollView(
      padding: padding,
      child: child,
    ),
  );
}
