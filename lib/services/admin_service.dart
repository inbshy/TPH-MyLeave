import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/models/leave_approval_audit.dart';
import 'package:tph_myleave/models/leave_request_detail.dart';
import 'package:tph_myleave/models/staff_directory_entry.dart';
import 'package:tph_myleave/services/leave_service.dart';

class AdminService {
  AdminService({LeaveService? leaveService})
      : _leave = leaveService ?? LeaveService();

  final _client = SupabaseConfig.client;
  final LeaveService _leave;

  static const _directoryFixSql =
      'supabase/fix_admin_employee_directory.sql';

  Future<List<StaffDirectoryEntry>> fetchStaffDirectory({
    String? roleFilter,
    int? companyId,
    String? search,
  }) async {
    var query = _client.from(AppConstants.tableUsers).select('''
      id, employee_id, name, email, role, staff_type, company_id,
      company (company_id, companyName, group_id, company_groups (group_id, groupName))
    ''');

    if (roleFilter != null && roleFilter.isNotEmpty) {
      query = query.eq('role', roleFilter);
    }
    if (companyId != null) {
      query = query.eq('company_id', companyId);
    }
    if (search != null && search.trim().isNotEmpty) {
      final pattern = '%${search.trim()}%';
      query = query.or('name.ilike.$pattern,email.ilike.$pattern');
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
    try {
      await _client.rpc('admin_change_user_role', params: {
        'p_user_id': userId,
        'p_role': role,
      });
      return;
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e, 'admin_change_user_role')) {
        throw Exception(_directoryErrorMessage(e));
      }
    }

    await _changeUserRoleDirect(userId: userId, role: role);
  }

  Future<void> updateUserProfile({
    required String userId,
    required String name,
    required String email,
    String staffType = 'permanent',
    int? companyId,
  }) async {
    try {
      await _client.rpc('admin_update_user_profile', params: {
        'p_user_id': userId,
        'p_name': name,
        'p_email': email,
        'p_staff_type': staffType,
        'p_company_id': companyId,
      });
      return;
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e, 'admin_update_user_profile')) {
        throw Exception(_directoryErrorMessage(e));
      }
    }

    await _updateUserProfileDirect(
      userId: userId,
      name: name,
      email: email,
      staffType: staffType,
      companyId: companyId,
    );
  }

  Future<void> _changeUserRoleDirect({
    required String userId,
    required String role,
  }) async {
    try {
      await _client
          .from(AppConstants.tableUsers)
          .update({'role': role})
          .eq('id', userId);

      await _client
          .from(AppConstants.tableEmployees)
          .update({'role': role})
          .eq('user_id', userId);
    } on PostgrestException catch (e) {
      throw Exception(_directoryErrorMessage(e));
    }
  }

  Future<void> _updateUserProfileDirect({
    required String userId,
    required String name,
    required String email,
    required String staffType,
    int? companyId,
  }) async {
    try {
      final userRow = await _client
          .from(AppConstants.tableUsers)
          .select('employee_id, role, company_id')
          .eq('id', userId)
          .maybeSingle();

      if (userRow == null) {
        throw Exception('User not found.');
      }

      final employeeId = userRow['employee_id'] as int;
      final role = userRow['role'] as String? ?? AppConstants.roleEmployee;
      final resolvedCompanyId =
          companyId ?? userRow['company_id'] as int?;

      final userPayload = <String, dynamic>{
        'name': name.trim(),
        'email': email.trim(),
        'staff_type': staffType,
      };
      if (companyId != null) {
        userPayload['company_id'] = companyId;
      }

      await _client
          .from(AppConstants.tableUsers)
          .update(userPayload)
          .eq('id', userId);

      final employeePayload = <String, dynamic>{
        'name': name.trim(),
        'role': role,
      };
      if (resolvedCompanyId != null) {
        employeePayload['company_id'] = resolvedCompanyId;
      }

      final updated = await _client
          .from(AppConstants.tableEmployees)
          .update(employeePayload)
          .eq('user_id', userId)
          .select('id');

      if ((updated as List).isEmpty) {
        await _client.from(AppConstants.tableEmployees).insert({
          'user_id': userId,
          'employee_id': employeeId,
          'name': name.trim(),
          'role': role,
          if (resolvedCompanyId != null) 'company_id': resolvedCompanyId,
        });
      }
    } on PostgrestException catch (e) {
      throw Exception(_directoryErrorMessage(e));
    }
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

  static bool _isMissingRpc(PostgrestException e, String name) {
    final text = '${e.message} ${e.details} ${e.hint}'.toLowerCase();
    return e.code == 'PGRST202' ||
        text.contains(name) ||
        text.contains('could not find the function');
  }

  static String _directoryErrorMessage(PostgrestException e) {
    final text = '${e.message} ${e.details} ${e.hint}'.toLowerCase();
    if (e.code == 'PGRST202' ||
        text.contains('admin_update_user_profile') ||
        text.contains('admin_change_user_role') ||
        text.contains('could not find the function')) {
      return 'Database setup incomplete. In Supabase SQL Editor, run: $_directoryFixSql';
    }
    if (text.contains('only admins') ||
        text.contains('permission') ||
        text.contains('row-level security') ||
        text.contains('policy') ||
        e.code == '42501') {
      return 'Permission denied. Sign in as admin and run $_directoryFixSql in Supabase.';
    }
    final detail = e.details?.toString().trim();
    if (detail != null && detail.isNotEmpty) {
      return '${e.message} ($detail)';
    }
    return e.message;
  }
}
