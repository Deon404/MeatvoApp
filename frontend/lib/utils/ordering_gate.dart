import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../providers/store_settings_provider.dart';
import '../widgets/store/store_closed_sheet.dart';

/// Blocks add/increment cart actions when the store is closed.
abstract final class OrderingGate {
  static Future<void> guardAddToCart(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    final status = ref.read(storeSettingsSyncProvider);
    if (!status.isOpen) {
      await StoreClosedSheet.show(context, status);
      return;
    }
    await action();
  }

  /// Blocks only when [nextQuantity] exceeds [currentQuantity].
  static Future<void> guardQuantityChange(
    BuildContext context,
    WidgetRef ref, {
    required int currentQuantity,
    required int nextQuantity,
    required Future<void> Function() action,
  }) async {
    if (nextQuantity > currentQuantity) {
      await guardAddToCart(context, ref, action);
      return;
    }
    await action();
  }
}
