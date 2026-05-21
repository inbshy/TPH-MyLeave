import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/models/leave_request_detail.dart';
import 'package:tph_myleave/services/company_service.dart';
import 'package:tph_myleave/services/employee_service.dart';

class LeaveService {
  LeaveService({
    EmployeeService? employeeService,
    CompanyService? companyService,
  })  : _employeeService = employeeService ?? EmployeeService(),
        _companyService = companyService ?? CompanyService();

  final _client = SupabaseConfig.client;
  final EmployeeService _employeeService;
  final CompanyService _companyService;

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

  Future<List<LeaveRequest>> fetchPendingLeaves() async {
    final response = await _client
        .from(AppConstants.tableLeaveRequests)
        .select()
        .eq('status', AppConstants.leaveStatusPending)
        .order('date_start', ascending: true);

    final data = response as List<dynamic>;
    return data
        .map((json) => LeaveRequest.fromJson(Map<String, dynamic>.from(json as Map)))
        .toList();
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

  Future<List<LeaveRequestDetail>> fetchPendingLeaveDetails() async {
    final pending = await fetchPendingLeaves();
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
      if (emp != null) {
        final company = await _companyService.fetchCompanyById(emp.id);
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

  Future<void> submitLeave(LeaveRequest leave) async {
    await _client
        .from(AppConstants.tableLeaveRequests)
        .insert(leave.toInsertJson());
  }

  Future<void> approveLeave(int id, {String adminComment = ''}) async {
    await _client.from(AppConstants.tableLeaveRequests).update({
      'status': AppConstants.leaveStatusApproved,
      'admin_comment': adminComment.trim(),
      'rejected_reason': '',
    }).eq('id', id);
  }

  Future<void> rejectLeave(int id, {required String rejectedReason, String adminComment = ''}) async {
    await _client.from(AppConstants.tableLeaveRequests).update({
      'status': AppConstants.leaveStatusRejected,
      'rejected_reason': rejectedReason.trim(),
      'admin_comment': adminComment.trim(),
    }).eq('id', id);
  }
}
