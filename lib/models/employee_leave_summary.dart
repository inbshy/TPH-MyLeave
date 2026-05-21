import 'package:tph_myleave/models/leave_balance.dart';

/// Employee row for admin balance overview.
class EmployeeLeaveSummary {
  const EmployeeLeaveSummary({
    required this.employeeId,
    required this.name,
    required this.companyName,
    required this.balances,
  });

  final int employeeId;
  final String name;
  final String companyName;
  final List<LeaveBalanceEntry> balances;
}
