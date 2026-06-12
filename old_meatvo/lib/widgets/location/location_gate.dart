import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/address_service.dart';
import '../../services/auth_service.dart';
import 'location_onboarding_sheet.dart';

/// Shows Licious-style location sheet on startup when no default delivery address.
class LocationGate extends ConsumerStatefulWidget {
  final Widget child;

  const LocationGate({super.key, required this.child});

  @override
  ConsumerState<LocationGate> createState() => _LocationGateState();
}

class _LocationGateState extends ConsumerState<LocationGate> {
  bool _hasChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeShowOnboarding());
  }

  Future<void> _maybeShowOnboarding() async {
    if (_hasChecked || !mounted) return;
    _hasChecked = true;

    try {
      final defaultAddress = await AddressService().getDefaultAddress();
      if (!mounted || defaultAddress != null) return;

      String? firstName;
      try {
        final profile = await AuthService().getCurrentUserProfile();
        final name = profile?.name?.trim();
        if (name != null && name.isNotEmpty) {
          firstName = name.split(RegExp(r'\s+')).first;
        }
      } catch (_) {}

      if (!mounted) return;
      await LocationOnboardingSheet.show(context, userName: firstName);
    } catch (_) {
      // Gate failure should not block home shell.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
