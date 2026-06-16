import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../main.dart' show MyHomePage;
import '../../services/address_service.dart';
import '../../utils/responsive_helper.dart';
import 'location_permission_screen.dart';
import 'location_setup_screen.dart';

/// Routes customers through location permission + address setup before home.
class PostAuthGateScreen extends StatefulWidget {
  const PostAuthGateScreen({super.key});

  @override
  State<PostAuthGateScreen> createState() => _PostAuthGateScreenState();
}

class _PostAuthGateScreenState extends State<PostAuthGateScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _runGate());
  }

  Future<void> _runGate() async {
    try {
      final defaultAddress = await AddressService().getDefaultAddress();
      if (!mounted) return;

      if (defaultAddress != null) {
        if (!mounted) return;
        Navigator.of(context).pushAndRemoveUntil(
          MaterialPageRoute<void>(
            builder: (_) => const MyHomePage(title: 'Meatvo'),
          ),
          (_) => false,
        );
        return;
      }

      final permission = await Geolocator.checkPermission();
      if (!mounted) return;

      final needsRationale = permission == LocationPermission.denied ||
          permission == LocationPermission.unableToDetermine;

      if (needsRationale) {
        await LocationPermissionScreen.show(context);
      }

      if (!mounted) return;

      await Navigator.of(context).pushReplacement(
        PageRouteBuilder<void>(
          pageBuilder: (_, __, ___) => const LocationSetupScreen(),
          transitionsBuilder: (_, animation, __, child) {
            return FadeTransition(opacity: animation, child: child);
          },
          transitionDuration: const Duration(milliseconds: 300),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      await Navigator.of(context).pushReplacement(
        MaterialPageRoute<void>(builder: (_) => const LocationSetupScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    return const Scaffold(
      backgroundColor: AppColors.surface,
      body: SafeArea(
        child: Center(
          child: SizedBox(
            width: 28,
            height: 28,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              color: AppColors.primary,
            ),
          ),
        ),
      ),
    );
  }
}
