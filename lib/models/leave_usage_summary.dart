class LeaveUsageSummary {
  const LeaveUsageSummary({
    required this.employeeId,
    required this.employeeName,
    required this.companyName,
    required this.leaveType,
    required this.totalDays,
    required this.requestCount,
  });

  final int employeeId;
  final String employeeName;
  final String companyName;
  final String leaveType;
  final int totalDays;
  final int requestCount;
}
