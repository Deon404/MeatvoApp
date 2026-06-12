import 'package:flutter/material.dart';

import '../location/location_onboarding_sheet.dart';

/// @deprecated Use [LocationOnboardingSheet.show] instead.
Future<bool?> showLocationSetupDialog(
  BuildContext context, {
  VoidCallback? onLocationGranted,
  VoidCallback? onSkip,
}) async {
  await LocationOnboardingSheet.show(context);
  onLocationGranted?.call();
  return true;
}

/// @deprecated Use [LocationOnboardingSheet] instead.
class LocationSetupDialog extends StatelessWidget {
  final VoidCallback? onLocationGranted;
  final VoidCallback? onSkip;

  const LocationSetupDialog({
    super.key,
    this.onLocationGranted,
    this.onSkip,
  });

  @override
  Widget build(BuildContext context) {
    return const SizedBox.shrink();
  }
}
