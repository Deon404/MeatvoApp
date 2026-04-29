import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/notifications_provider.dart';
import '../../widgets/app_empty_state.dart';
import '../../widgets/app_error_state.dart';
import '../../widgets/loading_skeleton.dart';

class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: notifications.when(
        data: (items) {
          if (items.isEmpty) {
            return const AppEmptyState(
              icon: Icons.notifications_off_outlined,
              title: 'No notifications',
              subtitle: 'Important order updates yahan dikhenge.',
            );
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final n = items[index];
              return ListTile(
                leading: const Icon(Icons.notifications_active_outlined),
                title: Text(n.title),
                subtitle: Text(n.message),
                trailing: Text(n.timeLabel),
              );
            },
          );
        },
        loading: () => ListView(
          padding: const EdgeInsets.all(16),
          children: const [
            LoadingSkeleton(height: 20),
            SizedBox(height: 12),
            LoadingSkeleton(height: 60),
            SizedBox(height: 12),
            LoadingSkeleton(height: 60),
          ],
        ),
        error: (err, _) => AppErrorState(
          title: 'Notifications unavailable',
          subtitle: '$err',
          onRetry: () => ref.invalidate(notificationsProvider),
        ),
      ),
    );
  }
}
