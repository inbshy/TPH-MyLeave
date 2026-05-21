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
  static const String leaveStatusApproved = 'approved';
  static const String leaveStatusRejected = 'rejected';

  /// Supabase table names used by this app.
  static const String tableUsers = 'users';
  static const String tableCompany = 'company';
  static const String tableCompanyGroups = 'company_groups';
  static const String tableLeaveRequests = 'leave_requests';
  static const String tableEmployees = 'employees';

  static const String storageLeaveAttachments = 'leave-attachments';
}
