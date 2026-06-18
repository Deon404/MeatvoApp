import 'package:flutter/material.dart';

/// Shared layout metrics for bottom nav + floating cart.
abstract final class MeatvoLayout {
  static const double navBarHeight = 72;
  /// Horizontal inset for [MeatvoFloatingNavBar] left/right.
  static const double navBarMargin = 16;
  /// Vertical gap above safe area; matches nav `Positioned` bottom offset.
  static const double navBarBottomGap = 10;
  static const double cartBarHeight = 56;

  static const double _tabScrollBottomGap = 12;

  static bool isCompactHeight(BuildContext context) {
    return MediaQuery.sizeOf(context).height < 720;
  }

  /// Extra scroll padding inside tab bodies (nav handled by shell parent padding).
  static double tabScrollBottomPadding(BuildContext context) {
    return _tabScrollBottomGap;
  }

  /// Bottom inset for tab content inside [MyHomePage] shell (nav overlay).
  static double tabShellBottomInset(BuildContext context) {
    return MediaQuery.paddingOf(context).bottom +
        navBarBottomGap +
        navBarHeight;
  }

  /// Total vertical space occupied by the floating nav from screen bottom.
  static double floatingNavTotalHeight(BuildContext context) {
    return tabShellBottomInset(context);
  }

  /// Scroll bottom padding on Home tab (floating cart only; nav via shell).
  static double homeScrollBottomInset(BuildContext context) {
    return cartBarHeight + 16;
  }

  /// Scroll padding for category grid + catalog (floating cart in tab shell).
  static double browsingScrollBottomInset(BuildContext context) {
    return homeScrollBottomInset(context) + tabScrollBottomPadding(context);
  }

  /// Scroll padding for pushed catalog screens (cart bar + safe area, no tab nav).
  static double catalogScrollBottomInset(BuildContext context) {
    return cartBarHeight + floatingCartBottomGap + 8 +
        MediaQuery.paddingOf(context).bottom;
  }

  /// Fixed add-to-cart bar on product detail (padding + 48px CTA).
  static const double productDetailBottomBarHeight = 72;

  /// Bottom offset for [FloatingCartBar] above the product detail bottom bar.
  static double productDetailFloatingCartBottom(
    BuildContext context, {
    bool hasBottomBar = true,
  }) {
    final safe = MediaQuery.paddingOf(context).bottom;
    if (hasBottomBar) {
      return safe + productDetailBottomBarHeight + floatingCartBottomGap;
    }
    return safe + floatingCartBottomGap;
  }

  /// Product detail ListView padding above bottom bar + floating cart pill.
  static double productDetailScrollBottomInset(BuildContext context) {
    return productDetailFloatingCartBottom(context) + cartBarHeight + 8;
  }

  /// Nav + cart + spacing — for screens **outside** the tab shell only.
  static double contentBottomPadding(BuildContext context) {
    return floatingNavTotalHeight(context) + cartBarHeight + 16;
  }

  /// Gap between [FloatingCartBar] and the floating nav bar in tab shell.
  static const double floatingCartBottomGap = 8;

  /// Bottom offset for [FloatingCartBar] above the tab-shell nav bar.
  static double tabShellFloatingCartBottom(BuildContext context) {
    return tabShellBottomInset(context) + floatingCartBottomGap;
  }
}
