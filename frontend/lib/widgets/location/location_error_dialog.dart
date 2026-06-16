import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

import '../../core/constants/app_constants.dart';
import '../../design_system/tokens/meatvo_radii.dart';
import '../../design_system/tokens/meatvo_spacing.dart';
import '../../services/maps_service.dart';

/// Location error fallback — shown only after native dialogs were declined.
class LocationErrorDialog extends StatelessWidget {
  final LocationException error;

  const LocationErrorDialog({
    super.key,
    required this.error,
  });

  bool get _showOpenSettings {
    if (error.errorType == LocationErrorType.permissionDeniedForever) {
      return true;
    }
    return error.errorType == LocationErrorType.serviceDisabled &&
        error.nativeResolutionAttempted;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(MeatvoRadii.md),
      ),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: AppColors.primaryHover,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(
              _showOpenSettings ? Icons.settings_outlined : Icons.location_off_outlined,
              color: AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: MeatvoSpacing.sm),
          Expanded(
            child: Text(
              error.title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
      content: Text(
        error.message,
        style: const TextStyle(
          fontSize: 14,
          color: AppColors.textSecondary,
          height: 1.5,
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text(
            'Search Manually',
            style: TextStyle(color: AppColors.textSecondary),
          ),
        ),
        if (_showOpenSettings)
          ElevatedButton(
            onPressed: () async {
              Navigator.of(context).pop();
              if (error.errorType == LocationErrorType.serviceDisabled) {
                await Geolocator.openLocationSettings();
              } else {
                await Geolocator.openAppSettings();
              }
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MeatvoRadii.sm),
              ),
            ),
            child: const Text('Open Settings'),
          )
        else
          ElevatedButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(MeatvoRadii.sm),
              ),
            ),
            child: const Text('Try Again'),
          ),
      ],
    );
  }
}

Future<bool?> showLocationErrorDialog(
  BuildContext context,
  LocationException error,
) async {
  return showDialog<bool>(
    context: context,
    builder: (context) => LocationErrorDialog(error: error),
  );
}
