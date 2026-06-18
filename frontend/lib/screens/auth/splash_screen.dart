import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../design_system/tokens/meatvo_colors.dart';
import '../../navigation/app_destinations.dart';
import '../../services/auth_service.dart';
import '../../services/push_notification_service.dart';
import '../../services/storage_service.dart';
import '../../utils/app_transitions.dart';
import '../onboarding/onboarding_screen.dart';
import 'phone_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    );
    _fadeAnimation = CurvedAnimation(
      parent: _controller,
      curve: Curves.easeIn,
    );
    _controller.forward();
    WidgetsBinding.instance.addPostFrameCallback((_) => _initialize());
  }

  Future<void> _initialize() async {
    try {
      await Future.delayed(const Duration(seconds: 2));
      if (!mounted) return;

      var isLoggedIn = false;
      try {
        final token = await StorageService().getAccessToken();
        isLoggedIn = token != null;
      } catch (e) {
        if (kDebugMode) {
          debugPrint('Error checking login status: $e');
        }
      }

      if (!mounted) return;

      if (isLoggedIn) {
        Widget destination = destinationAfterAuth();
        try {
          // Always sync role from backend — cached profile can be stale after
          // an admin changes the user's role in the dashboard.
          final userProfile = await AuthService().getMe();
          if (userProfile != null) {
            destination = destinationAfterAuth(role: userProfile.role);
          }
          // Upload FCM token in background — do not block splash navigation.
          unawaited(PushNotificationService().syncTokenWithBackend());
        } catch (e) {
          if (kDebugMode) {
            debugPrint('Failed to fetch user profile for role-based routing: $e');
          }
          final cached = await AuthService().getCurrentUserProfile();
          if (cached != null) {
            destination = destinationAfterAuth(role: cached.role);
          }
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(AppTransitions.fade(destination));
      } else {
        if (!mounted) return;
        final prefs = await SharedPreferences.getInstance();
        final onboardingDone = prefs.getBool('onboarding_completed') ?? false;
        if (!mounted) return;

        final destination = onboardingDone
            ? const PhoneScreen()
            : const OnboardingScreen();
        Navigator.of(context).pushReplacement(AppTransitions.fade(destination));
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('Error in splash initialization: $e');
      }
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        AppTransitions.fade(const PhoneScreen()),
      );
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  MeatvoColors.brandPrimary,
                  MeatvoColors.brandPrimaryDark,
                ],
              ),
            ),
          ),
          Positioned.fill(
            child: FadeTransition(
              opacity: _fadeAnimation,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Meatvo',
                    style: GoogleFonts.poppins(
                      fontSize: 40,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Farm Fresh. Delivered Fresh.',
                    style: GoogleFonts.poppins(
                      fontSize: 14,
                      color: Colors.white.withValues(alpha: 0.8),
                    ),
                  ),
                ],
              ),
            ),
          ),
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Image.asset(
              'assets/images/splash_food.png',
              height: MediaQuery.of(context).size.height * 0.32,
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) =>
                  const SizedBox.shrink(),
            ),
          ),
        ],
      ),
    );
  }
}
