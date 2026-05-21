import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/models/leave_notification.dart';

class NotificationService {
  final _client = SupabaseConfig.client;

  Future<void> notifyLeaveEvent({
    required int leaveId,
    required String event,
  }) async {
    try {
      await _client.rpc('notify_leave_event', params: {
        'p_leave_id': leaveId,
        'p_event': event,
      });
    } on PostgrestException catch (_) {
      // Phase 1 SQL not applied yet — in-app notifications optional.
    }
  }

  /// Optional email via Supabase Edge Function `send-leave-email`.
  Future<void> trySendLeaveEmail({
    required int leaveId,
    required String event,
  }) async {
    try {
      await _client.functions.invoke(
        'send-leave-email',
        body: {'leave_id': leaveId, 'event': event},
      );
    } catch (_) {
      // Edge function not deployed or email not configured.
    }
  }

  Future<List<LeaveNotification>> fetchMyNotifications({int limit = 30}) async {
    try {
      final rows = await _client
          .from(AppConstants.tableLeaveNotifications)
          .select()
          .order('created_at', ascending: false)
          .limit(limit);

      return (rows as List<dynamic>)
          .map(
            (r) => LeaveNotification.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> markRead(int notificationId) async {
    await _client
        .from(AppConstants.tableLeaveNotifications)
        .update({'read_at': DateTime.now().toUtc().toIso8601String()})
        .eq('id', notificationId);
  }
}
