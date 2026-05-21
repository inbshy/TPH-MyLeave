import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/models/leave_request_detail.dart';
import 'package:tph_myleave/providers/leave_provider.dart';

final teamCalendarMonthProvider = StateProvider<DateTime>((ref) {
  final now = DateTime.now();
  return DateTime(now.year, now.month);
});

final teamCalendarLeavesProvider =
    FutureProvider<List<LeaveRequestDetail>>((ref) async {
  final month = ref.watch(teamCalendarMonthProvider);
  final start = DateTime(month.year, month.month, 1);
  final end = DateTime(month.year, month.month + 1, 0, 23, 59, 59);
  return ref.watch(leaveServiceProvider).fetchTeamLeavesInRange(
        start: start,
        end: end,
      );
});
