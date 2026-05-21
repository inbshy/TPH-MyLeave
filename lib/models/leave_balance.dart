import 'package:tph_myleave/models/leave_type.dart';

/// Year-to-date leave usage for one leave category.
class LeaveBalanceEntry {
  const LeaveBalanceEntry({
    required this.type,
    required this.year,
    required this.usedDays,
    required this.pendingDays,
  });

  final LeaveType type;
  final int year;
  final int usedDays;
  final int pendingDays;

  /// Annual entitlement; `null` means no cap (e.g. unpaid leave).
  int? get entitlement => type.yearlyEntitlement;

  int get bookedDays => usedDays + pendingDays;

  /// Days left this year; `null` when there is no entitlement cap.
  int? get remainingDays {
    final cap = entitlement;
    if (cap == null) return null;
    final left = cap - bookedDays;
    return left < 0 ? 0 : left;
  }

  bool get isUnlimited => entitlement == null;

  double? get usageFraction {
    final cap = entitlement;
    if (cap == null || cap == 0) return null;
    return (bookedDays / cap).clamp(0.0, 1.0);
  }
}
