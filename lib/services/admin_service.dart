import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/models/leave_approval_audit.dart';
import 'package:tph_myleave/models/leave_request_detail.dart';
import 'package:tph_myleave/models/leave_usage_summary.dart';
import 'package:tph_myleave/models/staff_directory_entry.dart';
import 'package:tph_myleave/services/leave_service.dart';

class AdminService {
  AdminService({LeaveService? leaveService})
      : _leave = leaveService ?? LeaveService();

  final _client = SupabaseConfig.client;
  final LeaveService _leave;

  Future<List<StaffDirectoryEntry>> fetchStaffDirectory({
    String? roleFilter,
    int? companyId,
    String? search,
  }) async {
    var query = _client.from(AppConstants.tableUsers).select('''
      id, employee_id, name, email, role, staff_type, company_id, manager_user_id,
      company:company_id (companyName, company_groups (groupName))
    ''');

    if (roleFilter != null && roleFilter.isNotEmpty) {
      query = query.eq('role', roleFilter);
    }
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    if (search != null && search.trim().isNotEmpty) {
      final q = '%${search.trim()}%';
      query = query.or('name.ilike.$q,email.ilike.$q');
    }

    final rows = await query.order('name');
    return (rows as List<dynamic>)
        .map((r) => StaffDirectoryEntry.fromJson(Map<String, dynamic>.from(r as Map)))
        .toList();
  }

  Future<void> changeUserRole({
    required String userId,
    required String role,
  }) async {
    await _client.rpc('admin_change_user_role', params: {
      'p_user_id': userId,
      'p_role': role,
    });
  }

  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String email,
    String staffType = 'permanent',
    int? companyId,
  }) async {
    await _client.rpc('admin_update_user_profile', params: {
      'p_user_id': userId,
      'p_name': name,
      'p_email': email,
      'p_staff_type': staffType,
      'p_company_id': companyId,
    });
  }

  Future<void> sendPasswordResetEmail(String email) async {
    await _client.auth.resetPasswordForEmail(email.trim());
  }

  Future<List<LeaveApprovalAudit>> fetchApprovalAudit(int leaveId) async {
    try {
      final rows = await _client
          .from(AppConstants.tableLeaveApprovalAudit)
          .select()
          .eq('leave_id', leaveId)
          .order('created_at');

      return (rows as List<dynamic>)
          .map(
            (r) => LeaveApprovalAudit.fromJson(
              Map<String, dynamic>.from(r as Map),
            ),
          )
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<LeaveRequestDetail>> fetchApprovalHistory({
    int? year,
    String? statusFilter,
  }) async {
    var query = _client.from(AppConstants.tableLeaveRequests).select();

    if (statusFilter != null && statusFilter.isNotEmpty) {
      query = query.eq('status', statusFilter);
    } else {
      query = query.inFilter('status', [
        AppConstants.leaveStatusApproved,
        AppConstants.leaveStatusRejected,
      ]);
    }

    if (year != null) {
      query = query
          .gte('date_start', '$year-01-01')
          .lte('date_start', '$year-12-31T23:59:59');
    }

    final rows = await query.order('date_start', ascending: false);
    final details = <LeaveRequestDetail>[];
    for (final raw in rows as List<dynamic>) {
      final leave = await _leave.fetchLeaveDetailById(
        (raw as Map)['id'] as int,
      );
      if (leave != null) details.add(leave);
    }
    return details;
  }

  Future<List<LeaveUsageSummary>> fetchLeaveUsageReport({
    int? year,
    int? companyId,
  }) async {
    final y = year ?? DateTime.now().year;
    final details = await _leave.fetchLeaveDetailsForExport(
      companyId: companyId,
      year: y,
    );

    final approved = details.where(
      (d) => d.request.status == AppConstants.leaveStatusApproved,
    );

    final map = <String, LeaveUsageSummary>{};
    for (final d in approved) {
      final key = '${d.request.employeeID}|${d.request.leaveType.storageValue}';
      final existing = map[key];
      if (existing == null) {
        map[key] = LeaveUsageSummary(
          employeeId: d.request.employeeID,
          employeeName: d.employeeName,
          companyName: d.companyName,
          leaveType: d.request.leaveType.displayLabel,
          totalDays: d.request.totalLeave,
          requestCount: 1,
        );
      } else {
        map[key] = LeaveUsageSummary(
          employeeId: existing.employeeId,
          employeeName: existing.employeeName,
          companyName: existing.companyName,
          leaveType: existing.leaveType,
          totalDays: existing.totalDays + d.request.totalLeave,
          requestCount: existing.requestCount + 1,
        );
      }
    }

    final list = map.values.toList()
      ..sort((a, b) => a.employeeName.compareTo(b.employeeName));
    return list;
  }
}
