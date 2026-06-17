import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../services/store_status_service.dart';

/// Cached store operational settings (delivery fee, min order, open state).
final storeSettingsProvider = FutureProvider<StoreStatus>((ref) async {
  return StoreStatusService().fetchStatus();
});

/// Provider for store settings with safe defaults while loading.
final storeSettingsSyncProvider = Provider<StoreStatus>((ref) {
  return ref.watch(storeSettingsProvider).maybeWhen(
        data: (status) => status,
        orElse: () => const StoreStatus(isOpen: true),
      );
});
