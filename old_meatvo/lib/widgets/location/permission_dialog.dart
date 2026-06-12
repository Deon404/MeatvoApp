import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_radii.dart';
import '../../design_system/tokens/meatvo_spacing.dart';
import '../../services/maps_service.dart';
import '../../utils/responsive_helper.dart';
import '../onboarding/delivery_location_illustration.dart';

/// Premium pre-permission sheet — shown before the OS location dialog.
class LocationPermissionDialog extends StatelessWidget {
  final String title;
  final String message;
  final VoidCallback? onGranted;
  final VoidCallback? onDenied;
  final bool showSettingsButton;

  const LocationPermissionDialog({
    super.key,
    this.title = 'Location access needed',
    this.message =
        'Meatvo uses your location to show products available in your area and deliver orders accurately.',
    this.onGranted,
    this.onDenied,
    this.showSettingsButton = false,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bottom = MediaQuery.paddingOf(context).bottom;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        MeatvoSpacing.lg,
        0,
        MeatvoSpacing.lg,
        MeatvoSpacing.lg + bottom,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(MeatvoRadii.xl),
          border: Border.all(color: AppColors.divider),
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.08),
              blurRadius: 32,
              offset: const Offset(0, -4),
            ),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(
            MeatvoSpacing.xl,
            MeatvoSpacing.lg,
            MeatvoSpacing.xl,
            MeatvoSpacing.xl,
          ),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.divider,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                const SizedBox(height: MeatvoSpacing.lg),
                DeliveryLocationIllustration(
                  height: sh(context, 0.2).clamp(120.0, 180.0),
                  variant: DeliveryIllustrationVariant.permission,
                  backgroundImagePath: 'assets/images/location_bg.png',
                ),
                const SizedBox(height: MeatvoSpacing.lg),
                Text(
                  title,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: MeatvoSpacing.sm),
                Text(
                  message,
                  textAlign: TextAlign.center,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: MeatvoSpacing.lg),
                const _BenefitRow(
                  icon: Icons.local_shipping_outlined,
                  text: 'Accurate doorstep delivery',
                ),
                const SizedBox(height: MeatvoSpacing.sm),
                const _BenefitRow(
                  icon: Icons.storefront_outlined,
                  text: 'Products available in your zone',
                ),
                const SizedBox(height: MeatvoSpacing.sm),
                const _BenefitRow(
                  icon: Icons.lock_outline_rounded,
                  text: 'Your data stays private and secure',
                ),
                const SizedBox(height: MeatvoSpacing.xl),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () async {
                      Navigator.of(context).pop();
                      if (showSettingsButton) {
                        await Geolocator.openAppSettings();
                        onDenied?.call();
                        return;
                      }
                      final mapsService = MapsService();
                      final permission =
                          await mapsService.requestLocationPermission();
                      if (permission == LocationPermission.whileInUse ||
                          permission == LocationPermission.always) {
                        onGranted?.call();
                      } else {
                        onDenied?.call();
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(MeatvoRadii.md),
                      ),
                    ),
                    child: Text(
                      showSettingsButton ? 'Open Settings' : 'Allow Location',
                      style: const TextStyle(fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
                const SizedBox(height: MeatvoSpacing.sm),
                TextButton(
                  onPressed: () {
                    Navigator.of(context).pop();
                    onDenied?.call();
                  },
                  child: Text(
                    showSettingsButton ? 'Not now' : 'Maybe later',
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: AppColors.textSecondary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _BenefitRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _BenefitRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 18, color: AppColors.success),
        const SizedBox(width: MeatvoSpacing.sm),
        Expanded(
          child: Text(
            text,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
        ),
      ],
    );
  }
}

Future<bool> showLocationPermissionDialog(
  BuildContext context, {
  String? title,
  String? message,
  bool showSettingsButton = false,
}) async {
  var permissionGranted = false;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    isDismissible: !showSettingsButton,
    enableDrag: !showSettingsButton,
    backgroundColor: Colors.transparent,
    builder: (context) => LocationPermissionDialog(
      title: title ?? 'Location access needed',
      message: message ??
          'Meatvo uses your location to show products available in your area and deliver orders accurately.',
      showSettingsButton: showSettingsButton,
      onGranted: () => permissionGranted = true,
      onDenied: () => permissionGranted = false,
    ),
  );

  return permissionGranted;
}
