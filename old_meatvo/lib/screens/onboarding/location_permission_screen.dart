import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/theme/meatvo_theme_extensions.dart';
import '../../design_system/tokens/meatvo_radii.dart';
import '../../design_system/tokens/meatvo_spacing.dart';
import '../../services/maps_service.dart';
import '../../utils/responsive_helper.dart';
import '../../widgets/onboarding/delivery_location_illustration.dart';

/// Elegant full-screen pre-permission rationale — avoids default system-style dialogs.
class LocationPermissionScreen extends StatelessWidget {
  final VoidCallback onContinue;
  final VoidCallback onSkip;

  const LocationPermissionScreen({
    super.key,
    required this.onContinue,
    required this.onSkip,
  });

  static Future<bool> show(BuildContext context) async {
    final result = await Navigator.of(context).push<bool>(
      PageRouteBuilder<bool>(
        opaque: true,
        pageBuilder: (_, __, ___) => LocationPermissionScreen(
          onContinue: () => Navigator.of(context).pop(true),
          onSkip: () => Navigator.of(context).pop(false),
        ),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(
            opacity: CurvedAnimation(parent: animation, curve: Curves.easeOut),
            child: SlideTransition(
              position: Tween<Offset>(
                begin: const Offset(0, 0.04),
                end: Offset.zero,
              ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
              child: child,
            ),
          );
        },
        transitionDuration: const Duration(milliseconds: 350),
      ),
    );
    return result ?? false;
  }

  @override
  Widget build(BuildContext context) {
    R.init(context);
    final mv = context.meatvo;
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return PopScope(
      canPop: false,
      child: Scaffold(
        resizeToAvoidBottomInset: true,
        backgroundColor: mv.surfaceWarm,
        body: SafeArea(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final isCompact = constraints.maxHeight < 720;
              final cardPadding =
                  isCompact ? MeatvoSpacing.lg : MeatvoSpacing.xl;
              final illustrationHeight =
                  isCompact ? sh(context, 0.18) : sh(context, 0.24);

              return Padding(
                padding: EdgeInsets.fromLTRB(
                  MeatvoSpacing.lg,
                  MeatvoSpacing.md,
                  MeatvoSpacing.lg,
                  MeatvoSpacing.lg + bottom,
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        physics: const BouncingScrollPhysics(),
                        child: Container(
                          padding: EdgeInsets.all(cardPadding),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(MeatvoRadii.xl),
                            border: Border.all(color: AppColors.divider),
                            boxShadow: [
                              BoxShadow(
                                color: AppColors.textPrimary
                                    .withValues(alpha: 0.06),
                                blurRadius: 32,
                                offset: const Offset(0, 12),
                              ),
                            ],
                          ),
                          child: Column(
                            children: [
                              DeliveryLocationIllustration(
                                height: illustrationHeight,
                                variant: DeliveryIllustrationVariant.permission,
                                backgroundImagePath: 'assets/images/location_bg.png',
                              ),
                              SizedBox(
                                height: isCompact
                                    ? MeatvoSpacing.md
                                    : MeatvoSpacing.lg,
                              ),
                              Text(
                                'We need your location',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.headlineSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.textPrimary,
                                  height: 1.2,
                                ),
                              ),
                              const SizedBox(height: MeatvoSpacing.sm),
                              Text(
                                'Meatvo uses your location to show fresh products available in your area and deliver orders accurately to your doorstep.',
                                textAlign: TextAlign.center,
                                style: theme.textTheme.bodyMedium?.copyWith(
                                  color: AppColors.textSecondary,
                                  height: 1.55,
                                ),
                              ),
                              SizedBox(
                                height: isCompact
                                    ? MeatvoSpacing.md
                                    : MeatvoSpacing.lg,
                              ),
                              const _TrustRow(
                                icon: Icons.verified_user_outlined,
                                text:
                                    'Your location is never shared with third parties',
                              ),
                              const SizedBox(height: MeatvoSpacing.sm),
                              const _TrustRow(
                                icon: Icons.local_shipping_outlined,
                                text: 'Faster delivery to the right address',
                              ),
                              const SizedBox(height: MeatvoSpacing.sm),
                              const _TrustRow(
                                icon: Icons.inventory_2_outlined,
                                text: 'See only products available near you',
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: MeatvoSpacing.md),
                    SizedBox(
                      height: 52,
                      child: ElevatedButton(
                        onPressed: () async {
                          final mapsService = MapsService();
                          final permission =
                              await mapsService.requestLocationPermission();
                          
                          if (!context.mounted) return;
                          
                          if (permission == LocationPermission.deniedForever) {
                            // Permission permanently denied - open settings
                            await Geolocator.openAppSettings();
                            if (!context.mounted) return;
                            
                            // Show message and allow user to continue manually
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Please enable location permission in Settings to use GPS, or enter address manually',
                                ),
                                duration: const Duration(seconds: 4),
                                backgroundColor: AppColors.textSecondary,
                                action: SnackBarAction(
                                  label: 'Manual Entry',
                                  textColor: Colors.white,
                                  onPressed: onSkip,
                                ),
                              ),
                            );
                            return;
                          }
                          
                          // Only continue if permission was actually granted
                          if (permission == LocationPermission.whileInUse ||
                              permission == LocationPermission.always) {
                            onContinue();
                          } else {
                            // Permission denied (not forever) - show message
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Location permission is needed for GPS. You can enter address manually instead.',
                                ),
                                duration: Duration(seconds: 3),
                                backgroundColor: AppColors.textSecondary,
                              ),
                            );
                          }
                        },
                        child: const Text('Allow Location Access'),
                      ),
                    ),
                    const SizedBox(height: MeatvoSpacing.sm),
                    TextButton(
                      onPressed: onSkip,
                      child: Text(
                        'Enter address manually instead',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: AppColors.textSecondary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

class _TrustRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _TrustRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 20, color: AppColors.success),
        const SizedBox(width: MeatvoSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                  height: 1.45,
                ),
          ),
        ),
      ],
    );
  }
}
