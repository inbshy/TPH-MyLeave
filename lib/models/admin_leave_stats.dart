/// Aggregated leave request counts for the admin dashboard.
class AdminLeaveStats {
  const AdminLeaveStats({
    required this.pendingApproval,
    required this.approved,
    required this.rejected,
    required this.total,
  });

  final int pendingApproval;
  final int approved;
  final int rejected;
  final int total;

  static const empty = AdminLeaveStats(
    pendingApproval: 0,
    approved: 0,
    rejected: 0,
    total: 0,
  );
}
