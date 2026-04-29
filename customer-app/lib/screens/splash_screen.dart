import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import '../services/push_notification_service.dart';
import '../widgets/loading_skeleton.dart';

class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen> {
  @override
  void initState() {
    super.initState();
    Future.microtask(() async {
      await ref.read(pushNotificationServiceProvider).initialize();
      await ref.read(authNotifierProvider.notifier).bootstrap();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authNotifierProvider);
    if (!auth.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (auth.isAuthenticated) {
          context.go('/home');
        } else {
          context.go('/login');
        }
      });
    }

    return const Scaffold(
      body: Padding(
        padding: EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            LoadingSkeleton(height: 24),
            SizedBox(height: 16),
            LoadingSkeleton(height: 16),
          ],
        ),
      ),
    );
  }
}
