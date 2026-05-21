import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/models/leave_approval_audit.dart';
import 'package:tph_myleave/models/leave_request_detail.dart';
import 'package:tph_myleave/models/leave_usage_summary.dart';
import 'package:tph_myleave/models/staff_directory_entry.dart';
import 'package:tph_myleave/services/admin_service.dart';

final adminServiceProvider = Provider<AdminService>((ref) => AdminService());

final staffDirectoryProvider =
    FutureProvider<List<StaffDirectoryEntry>>((ref) async {
  final role = ref.watch(staffDirectoryRoleFilterProvider);
  final companyId = ref.watch(staffDirectoryCompanyFilterProvider);
  final search = ref.watch(staffDirectorySearchProvider);
  return ref.watch(adminServiceProvider).fetchStaffDirectory(
        roleFilter: role,
        companyId: companyId,
        search: search,
      );
});

final staffDirectoryRoleFilterProvider = StateProvider<String?>((ref) => null);
final staffDirectoryCompanyFilterProvider = StateProvider<int?>((ref) => null);
final staffDirectorySearchProvider = StateProvider<String>((ref) => '');

final approvalHistoryProvider =
    FutureProvider<List<LeaveRequestDetail>>((ref) async {
  final year = ref.watch(approvalHistoryYearProvider);
  final status = ref.watch(approvalHistoryStatusProvider);
  return ref.watch(adminServiceProvider).fetchApprovalHistory(
        year: year,
        statusFilter: status,
      );
});

final approvalHistoryYearProvider =
    StateProvider<int>((ref) => DateTime.now().year);
final approvalHistoryStatusProvider = StateProvider<String?>((ref) => null);

final leaveUsageReportProvider =
    FutureProvider<List<LeaveUsageSummary>>((ref) async {
  final year = ref.watch(usageReportYearProvider);
  final companyId = ref.watch(usageReportCompanyProvider);
  return ref.watch(adminServiceProvider).fetchLeaveUsageReport(
        year: year,
        companyId: companyId,
      );
});

final usageReportYearProvider = StateProvider<int>((ref) => DateTime.now().year);
final usageReportCompanyProvider = StateProvider<int?>((ref) => null);

final leaveAuditProvider =
    FutureProvider.family<List<LeaveApprovalAudit>, int>((ref, leaveId) {
  return ref.watch(adminServiceProvider).fetchApprovalAudit(leaveId);
});
