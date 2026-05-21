import 'package:tph_myleave/models/leave_balance.dart';

class EmployeeLeaveOverview {
  const EmployeeLeaveOverview({
    required this.employeeId,
    required this.name,
    required this.email,
    required this.companyId,
    required this.companyName,
    this.groupId,
    this.groupName,
    required this.balances,
  });

  final int employeeId;
  final String name;
  final String email;
  final int companyId;
  final String companyName;
  final int? groupId;
  final String? groupName;
  final List<LeaveBalanceEntry> balances;
}
