/// Shared static values for roles, leave workflow, and defaults.
class AppConstants {
  AppConstants._();

  static const String roleEmployee = 'employee';
  static const String roleManager = 'manager';
  static const String roleAdmin = 'admin';

  static bool canApplyLeave(String? role) => role == roleEmployee;

  static bool canApproveLeave(String? role) =>
      role == roleManager || role == roleAdmin;

  static String dashboardTitle(String? role) => switch (role) {
        roleAdmin => 'Admin dashboard',
        roleManager => 'Manager dashboard',
        _ => 'Dashboard',
      };

  static const String leaveStatusPending = 'pending';
  static const String leaveStatusPendingManager = 'pending_manager';
  static const String leaveStatusPendingAdmin = 'pending_admin';
  static const String leaveStatusApproved = 'approved';
  static const String leaveStatusRejected = 'rejected';
  static const String leaveStatusCancelled = 'cancelled';

  static bool isPendingLeaveStatus(String? status) {
    final s = status?.toLowerCase();
    return s == leaveStatusPending ||
        s == leaveStatusPendingManager ||
        s == leaveStatusPendingAdmin;
  }

  static String pendingStatusLabel(String? status) => switch (status) {
        leaveStatusPendingAdmin => 'Awaiting admin approval',
        leaveStatusPendingManager => 'Awaiting manager approval',
        leaveStatusPending => 'Pending approval',
        _ => status ?? '—',
      };

  static const String tableLeaveNotifications = 'leave_notifications';
  static const String tableLeaveApprovalAudit = 'leave_approval_audit';

  /// Supabase table names used by this app.
  static const String tableUsers = 'users';
  static const String tableCompany = 'company';
  static const String tableCompanyGroups = 'company_groups';
  static const String tableLeaveRequests = 'leave_requests';
  static const String tableEmployees = 'employees';

  static const String storageLeaveAttachments = 'leave-attachments';
}
