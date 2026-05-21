import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/models/leave_balance.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/models/leave_type.dart';

class LeaveBalanceCalculator {
  LeaveBalanceCalculator._();

  static bool _countsForYear(LeaveRequest request, int year) {
    return request.dateStart.year == year || request.dateEnd.year == year;
  }

  static List<LeaveBalanceEntry> compute({
    required List<LeaveRequest> requests,
    int? year,
  }) {
    final y = year ?? DateTime.now().year;
    final inYear = requests.where((r) => _countsForYear(r, y));

    return LeaveType.values.map((type) {
      var used = 0;
      var pending = 0;

      for (final r in inYear.where((r) => r.leaveType == type)) {
        final status = r.status.toLowerCase();
        if (status == AppConstants.leaveStatusRejected ||
            status == AppConstants.leaveStatusCancelled) {
          continue;
        }
        if (AppConstants.isPendingLeaveStatus(status)) {
          pending += r.totalLeave;
        } else if (status == AppConstants.leaveStatusApproved) {
          used += r.totalLeave;
        }
      }

      return LeaveBalanceEntry(
        type: type,
        year: y,
        usedDays: used,
        pendingDays: pending,
      );
    }).toList();
  }

  static LeaveBalanceEntry? entryForType(
    List<LeaveBalanceEntry> balances,
    LeaveType type,
  ) {
    for (final e in balances) {
      if (e.type == type) return e;
    }
    return null;
  }
}
