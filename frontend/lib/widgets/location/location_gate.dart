import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../services/address_service.dart';
import 'delivery_location_coordinator.dart';

/// Guards home shell — skips auto sheet right after setup completes.
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

    if (DeliveryLocationSession.setupJustCompleted) {
      DeliveryLocationSession.consumeSetupCompleted();
      return;
    }

    try {
      final defaultAddress = await AddressService().getDefaultAddress();
      if (!mounted || defaultAddress != null) return;
      // No auto sheet — first-time users are handled by PostAuthGate → LocationSetupScreen.
    } catch (_) {
      // Gate failure should not block home shell.
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
