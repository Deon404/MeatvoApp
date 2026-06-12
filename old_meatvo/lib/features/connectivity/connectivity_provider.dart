import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final connectivityServiceProvider = Provider<Connectivity>((_) {
  return Connectivity();
});

final isOfflineProvider = StreamProvider<bool>((ref) async* {
  final connectivity = ref.watch(connectivityServiceProvider);

  Future<bool> checkOffline() async {
    final results = await connectivity.checkConnectivity();
    return results.every((r) => r == ConnectivityResult.none);
  }

  yield await checkOffline();

  await for (final results in connectivity.onConnectivityChanged) {
    yield results.every((r) => r == ConnectivityResult.none);
  }
});
