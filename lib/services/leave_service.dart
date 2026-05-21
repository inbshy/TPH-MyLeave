import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/models/admin_leave_stats.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/models/leave_request_detail.dart';
import 'package:tph_myleave/services/company_service.dart';
import 'package:tph_myleave/services/employee_service.dart';
import 'package:tph_myleave/services/notification_service.dart';

class LeaveService {
  LeaveService({
    EmployeeService? employeeService,
    CompanyService? companyService,
    NotificationService? notificationService,
  })  : _employeeService = employeeService ?? EmployeeService(),
        _companyService = companyService ?? CompanyService(),
        _notifications = notificationService ?? NotificationService();

  final _client = SupabaseConfig.client;
  final EmployeeService _employeeService;
  final CompanyService _companyService;
  final NotificationService _notifications;

  Future<List<LeaveRequest>> fetchLeavesForEmployee(int employeeId) async {
    final response = await _client
        .from(AppConstants.tableLeaveRequests)
        .select()
        .eq('employeeID', employeeId)
        .order('date_start', ascending: false);

    final data = response as List<dynamic>;
    return data
        .map((json) => LeaveRequest.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<List<LeaveRequest>> fetchPendingLeaves({String? role}) async {
    final statuses = role == AppConstants.roleManager
        ? [
            AppConstants.leaveStatusPending,
            AppConstants.leaveStatusPendingManager,
          ]
        : [
            AppConstants.leaveStatusPending,
            AppConstants.leaveStatusPendingManager,
            AppConstants.leaveStatusPendingAdmin,
          ];

    final response = await _client
        .from(AppConstants.tableLeaveRequests)
        .select()
        .inFilter('status', statuses)
        .order('date_start', ascending: true);

    final data = response as List<dynamic>;
    return data
        .map((json) => LeaveRequest.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
  }

  Future<AdminLeaveStats> fetchAdminLeaveStats() async {
    final response = await _client
        .from(AppConstants.tableLeaveRequests)
        .select('status');

    var pendingApproval = 0;
    var approved = 0;
    var rejected = 0;

    final rows = response as List<dynamic>;
    for (final row in rows) {
      final status =
          (row as Map)['status']?.toString().toLowerCase() ?? '';
      if (AppConstants.isPendingLeaveStatus(status)) {
        pendingApproval++;
      } else if (status == AppConstants.leaveStatusApproved) {
        approved++;
      } else if (status == AppConstants.leaveStatusRejected) {
        rejected++;
      }
    }

    return AdminLeaveStats(
      pendingApproval: pendingApproval,
      approved: approved,
      rejected: rejected,
      total: rows.length,
    );
  }

  Future<LeaveRequest?> fetchLeaveById(int id) async {
    final row = await _client
        .from(AppConstants.tableLeaveRequests)
        .select()
        .eq('id', id)
        .maybeSingle();
    if (row == null) return null;
    return LeaveRequest.fromJson(Map<String, dynamic>.from(row));
  }

  Future<LeaveRequestDetail?> fetchLeaveDetailById(int id) async {
    final leave = await fetchLeaveById(id);
    if (leave == null) return null;
    return _enrichLeave(leave);
  }

  Future<List<LeaveRequestDetail>> fetchPendingLeaveDetails({String? role}) async {
    final pending = await fetchPendingLeaves(role: role);
    final details = <LeaveRequestDetail>[];
    for (final leave in pending) {
      final d = await _enrichLeave(leave);
      if (d != null) details.add(d);
    }
    return details;
  }

  Future<LeaveRequestDetail?> _enrichLeave(LeaveRequest leave) async {
    final emp = await _employeeService.fetchEmployeeById(leave.employeeID);
    var name = emp?.name ?? 'Employee #${leave.employeeID}';
    var companyName = '—';
    String? groupName;
    String? email;

    try {
      final userRow = await _client
          .from(AppConstants.tableUsers)
          .select('name, email, company_id')
          .eq('employee_id', leave.employeeID)
          .maybeSingle();
      if (userRow != null) {
        name = userRow['name'] as String? ?? name;
        email = userRow['email'] as String?;
        final cid = userRow['company_id'] as int?;
        if (cid != null) {
          final company = await _companyService.fetchCompanyById(cid);
          companyName = company?.companyName ?? companyName;
          groupName = company?.groupName;
        }
      }
    } catch (_) {
      if (emp?.companyId != null) {
        final company =
            await _companyService.fetchCompanyById(emp!.companyId!);
        companyName = company?.companyName ?? companyName;
        groupName = company?.groupName;
      }
    }

    if (companyName == '—' && emp?.companyId != null) {
      final company = await _companyService.fetchCompanyById(emp!.companyId!);
      if (company != null) {
        companyName = company.companyName;
        groupName = company.groupName;
      }
    }

    return LeaveRequestDetail(
      request: leave,
      employeeName: name,
      companyName: companyName,
      groupName: groupName,
      employeeEmail: email,
    );
  }

  Future<int> submitLeave(LeaveRequest leave) async {
    final row = await _client
        .from(AppConstants.tableLeaveRequests)
        .insert(leave.toInsertJson())
        .select('id')
        .single();
    final id = row['id'] as int;
    await _notifications.notifyLeaveEvent(leaveId: id, event: 'submitted');
    await _notifications.trySendLeaveEmail(leaveId: id, event: 'submitted');
    return id;
  }

  Future<void> cancelPendingLeave(int id) async {
    await _client.rpc('cancel_pending_leave', params: {'p_leave_id': id});
    await _notifications.notifyLeaveEvent(leaveId: id, event: 'cancelled');
  }

  Future<void> updatePendingLeave(LeaveRequest leave) async {
    if (leave.id == null) {
      throw ArgumentError('Leave id required for update');
    }
    await _client.rpc('update_pending_leave', params: {
      'p_leave_id': leave.id,
      'p_date_start': leave.dateStart.toIso8601String(),
      'p_date_end': leave.dateEnd.toIso8601String(),
      'p_leave_type': leave.leaveType.storageValue,
      'p_total_leave': leave.totalLeave,
      'p_employee_comment': leave.employeeComment,
      'p_attachment_path': leave.attachmentPath,
    });
  }

  Future<void> approveLeave(
    int id, {
    String adminComment = '',
    String? approverName,
    String? approverRole,
  }) async {
    try {
      await _client.rpc('process_leave_approval', params: {
        'p_leave_id': id,
        'p_action': 'approve',
        'p_comment': adminComment.trim(),
      });
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e, 'process_leave_approval')) rethrow;
      await _legacyApprove(id, adminComment: adminComment, approverName: approverName);
      await _notifications.notifyLeaveEvent(leaveId: id, event: 'approved');
      await _notifications.trySendLeaveEmail(leaveId: id, event: 'approved');
      return;
    }

    final leave = await fetchLeaveById(id);
    if (leave?.status == AppConstants.leaveStatusApproved) {
      if (approverName != null && approverName.isNotEmpty) {
        await _client
            .from(AppConstants.tableLeaveRequests)
            .update({'approveBy': approverName})
            .eq('id', id);
      }
      await _notifications.notifyLeaveEvent(leaveId: id, event: 'approved');
      await _notifications.trySendLeaveEmail(leaveId: id, event: 'approved');
    } else if (approverRole == AppConstants.roleManager) {
      await _notifications.notifyLeaveEvent(leaveId: id, event: 'submitted');
    }
  }

  Future<void> _legacyApprove(
    int id, {
    required String adminComment,
    String? approverName,
  }) async {
    final patch = <String, dynamic>{
      'status': AppConstants.leaveStatusApproved,
      'admin_comment': adminComment.trim(),
      'rejected_reason': '',
    };
    if (approverName != null && approverName.isNotEmpty) {
      patch['approveBy'] = approverName;
    }
    await _client.from(AppConstants.tableLeaveRequests).update(patch).eq('id', id);
  }

  Future<void> rejectLeave(
    int id, {
    required String rejectedReason,
    String adminComment = '',
    String? approverName,
  }) async {
    try {
      await _client.rpc('process_leave_approval', params: {
        'p_leave_id': id,
        'p_action': 'reject',
        'p_comment': adminComment.trim(),
        'p_rejected_reason': rejectedReason.trim(),
      });
    } on PostgrestException catch (e) {
      if (!_isMissingRpc(e, 'process_leave_approval')) rethrow;
      final patch = <String, dynamic>{
        'status': AppConstants.leaveStatusRejected,
        'rejected_reason': rejectedReason.trim(),
        'admin_comment': adminComment.trim(),
      };
      if (approverName != null && approverName.isNotEmpty) {
        patch['approveBy'] = approverName;
      }
      await _client.from(AppConstants.tableLeaveRequests).update(patch).eq('id', id);
    }

    if (approverName != null && approverName.isNotEmpty) {
      await _client
          .from(AppConstants.tableLeaveRequests)
          .update({'approveBy': approverName})
          .eq('id', id);
    }

    await _notifications.notifyLeaveEvent(leaveId: id, event: 'rejected');
    await _notifications.trySendLeaveEmail(leaveId: id, event: 'rejected');
  }

  bool _isMissingRpc(PostgrestException e, String name) {
    return e.code == 'PGRST202' ||
        e.message.contains(name) ||
        e.message.contains('Could not find the function');
  }

  Future<List<LeaveRequestDetail>> fetchTeamLeavesInRange({
    required DateTime start,
    required DateTime end,
    List<String> statuses = const [
      AppConstants.leaveStatusApproved,
      AppConstants.leaveStatusPending,
    ],
  }) async {
    final response = await _client
        .from(AppConstants.tableLeaveRequests)
        .select()
        .gte('date_end', start.toIso8601String())
        .lte('date_start', end.toIso8601String())
        .inFilter('status', statuses)
        .order('date_start');

    final data = response as List<dynamic>;
    final details = <LeaveRequestDetail>[];
    for (final raw in data) {
      final leave =
          LeaveRequest.fromJson(Map<String, dynamic>.from(raw as Map));
      final d = await _enrichLeave(leave);
      if (d != null) details.add(d);
    }
    return details;
  }

  Future<List<LeaveRequestDetail>> fetchLeaveDetailsForExport({
    int? companyId,
    int? year,
  }) async {
    var userQuery = _client
        .from(AppConstants.tableUsers)
        .select('employee_id')
        .eq('role', AppConstants.roleEmployee);

    if (companyId != null) {
      userQuery = userQuery.eq('company_id', companyId);
    }

    final users = await userQuery;
    final ids = (users as List<dynamic>)
        .map((r) => (r as Map)['employee_id'] as int)
        .toList();
    if (ids.isEmpty) return [];

    var leaveQuery = _client
        .from(AppConstants.tableLeaveRequests)
        .select()
        .inFilter('employeeID', ids);

    if (year != null) {
      leaveQuery = leaveQuery
          .gte('date_start', '$year-01-01')
          .lte('date_start', '$year-12-31T23:59:59');
    }

    final rows = await leaveQuery.order('date_start', ascending: false);
    final details = <LeaveRequestDetail>[];
    for (final raw in rows as List<dynamic>) {
      final leave =
          LeaveRequest.fromJson(Map<String, dynamic>.from(raw as Map));
      final d = await _enrichLeave(leave);
      if (d != null) details.add(d);
    }
    return details;
  }
}
