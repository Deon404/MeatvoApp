import 'package:flutter_riverpod/flutter_riverpod.dart';

final notificationsProvider = FutureProvider<List<AppNotification>>((ref) async {
  await Future<void>.delayed(const Duration(milliseconds: 400));
  return const [
    AppNotification(
      title: 'Order confirmed',
      message: 'Your latest order has been confirmed by store.',
      timeLabel: '2 min ago',
    ),
    AppNotification(
      title: 'Offer unlocked',
      message: 'Use code MEAT50 on your next order.',
      timeLabel: 'Today',
    ),
  ];
});

class AppNotification {
  final String title;
  final String message;
  final String timeLabel;

  const AppNotification({
    required this.title,
    required this.message,
    required this.timeLabel,
  });
}
