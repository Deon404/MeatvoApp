import 'package:flutter/material.dart';

/// Premium page transitions for smooth navigation
class AppTransitions {
  /// Slide transition from right (default navigation)
  static Route<T> slideRight<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(1.0, 0.0);
        const end = Offset.zero;
        const curve = Curves.easeInOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Slide transition from bottom (for modals)
  static Route<T> slideUp<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 1.0);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var tween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(tween),
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
      opaque: false,
    );
  }

  /// Fade transition (for splash to home)
  static Route<T> fade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 400),
    );
  }

  /// Scale transition (for product detail)
  static Route<T> scale<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(begin: 0.9, end: 1.0).animate(
            CurvedAnimation(
              parent: animation,
              curve: Curves.easeOutCubic,
            ),
          ),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 300),
    );
  }

  /// Combined slide and fade (premium feel)
  static Route<T> slideFade<T>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        const begin = Offset(0.0, 0.1);
        const end = Offset.zero;
        const curve = Curves.easeOutCubic;

        var slideTween = Tween(begin: begin, end: end).chain(
          CurveTween(curve: curve),
        );

        return SlideTransition(
          position: animation.drive(slideTween),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: const Duration(milliseconds: 350),
    );
  }
}

/// Extension methods for easy navigation with transitions
extension NavigationExtensions on BuildContext {
  /// Navigate with slide right transition
  Future<T?> pushSlideRight<T>(Widget page) {
    return Navigator.push<T>(
      this,
      AppTransitions.slideRight<T>(page),
    );
  }

  /// Navigate with slide up transition
  Future<T?> pushSlideUp<T>(Widget page) {
    return Navigator.push<T>(
      this,
      AppTransitions.slideUp<T>(page),
    );
  }

  /// Navigate with fade transition
  Future<T?> pushFade<T>(Widget page) {
    return Navigator.push<T>(
      this,
      AppTransitions.fade<T>(page),
    );
  }

  /// Navigate with scale transition
  Future<T?> pushScale<T>(Widget page) {
    return Navigator.push<T>(
      this,
      AppTransitions.scale<T>(page),
    );
  }

  /// Navigate with slide fade transition
  Future<T?> pushSlideFade<T>(Widget page) {
    return Navigator.push<T>(
      this,
      AppTransitions.slideFade<T>(page),
    );
  }
}
