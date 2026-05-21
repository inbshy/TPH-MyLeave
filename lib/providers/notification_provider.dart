import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/models/leave_notification.dart';
import 'package:tph_myleave/services/notification_service.dart';

final notificationServiceProvider =
    Provider<NotificationService>((ref) => NotificationService());

final myNotificationsProvider =
    FutureProvider<List<LeaveNotification>>((ref) async {
  return ref.watch(notificationServiceProvider).fetchMyNotifications();
});
