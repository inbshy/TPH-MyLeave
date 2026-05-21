import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/models/employee.dart';

class EmployeeService {
  final _client = SupabaseConfig.client;

  Future<int?> resolveEmployeeIdForUser(String userId) async {
    final userRow = await _client
        .from(AppConstants.tableUsers)
        .select('employee_id')
        .eq('id', userId)
        .maybeSingle();

    final fromUser = userRow?['employee_id'];
    if (fromUser is int) return fromUser;

    try {
      final emp = await _client
          .from(AppConstants.tableEmployees)
          .select('employee_id')
          .eq('user_id', userId)
          .maybeSingle();
      final id = emp?['employee_id'];
      if (id is int) return id;
    } catch (_) {}

    return null;
  }

  Future<List<Employee>> fetchEmployeesForCompany(int companyId) async {
    try {
      final response = await _client
          .from(AppConstants.tableEmployees)
          .select()
          .eq('company_id', companyId)
          .order('name');

      final list = response as List<dynamic>;
      return list
          .map((e) => Employee.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<List<({int employeeId, String name, String? email})>> fetchStaffForCompany(
    int companyId,
  ) async {
    final response = await _client
        .from(AppConstants.tableUsers)
        .select('employee_id, name, email')
        .eq('company_id', companyId)
        .eq('role', AppConstants.roleEmployee)
        .order('name');

    final list = response as List<dynamic>;
    return list.map((row) {
      final m = Map<String, dynamic>.from(row as Map);
      return (
        employeeId: m['employee_id'] as int,
        name: m['name'] as String? ?? 'Unknown',
        email: m['email'] as String?,
      );
    }).toList();
  }

  Future<Employee?> fetchEmployeeById(int employeeId) async {
    try {
      final row = await _client
          .from(AppConstants.tableEmployees)
          .select()
          .eq('employee_id', employeeId)
          .maybeSingle();
      if (row == null) return null;
      return Employee.fromJson(Map<String, dynamic>.from(row));
    } catch (_) {
      return null;
    }
  }

  /// Updates both [users] and [employees] rows for the given staff id.
  Future<void> updateEmployeeCompany({
    required int employeeId,
    required int companyId,
  }) async {
    try {
      await _client.rpc(
        'admin_update_employee_company',
        params: {
          'p_employee_id': employeeId,
          'p_company_id': companyId,
        },
      );
      return;
    } on PostgrestException catch (e) {
      if (e.code != 'PGRST202' &&
          !e.message.contains('admin_update_employee_company') &&
          !e.message.contains('Could not find the function')) {
        throw Exception(_assignmentErrorMessage(e));
      }
    }

    try {
      await _client
          .from(AppConstants.tableUsers)
          .update({'company_id': companyId})
          .eq('employee_id', employeeId);

      await _client
          .from(AppConstants.tableEmployees)
          .update({'company_id': companyId})
          .eq('employee_id', employeeId);
    } on PostgrestException catch (e) {
      throw Exception(_assignmentErrorMessage(e));
    }
  }

  Future<List<({String id, String name, String email})>> fetchManagers() async {
    final response = await _client
        .from(AppConstants.tableUsers)
        .select('id, name, email')
        .eq('role', AppConstants.roleManager)
        .order('name');

    return (response as List<dynamic>).map((row) {
      final m = Map<String, dynamic>.from(row as Map);
      return (
        id: m['id'] as String,
        name: m['name'] as String? ?? 'Manager',
        email: m['email'] as String? ?? '',
      );
    }).toList();
  }

  Future<void> assignManager({
    required int employeeId,
    String? managerUserId,
  }) async {
    await _client.rpc('assign_employee_manager', params: {
      'p_employee_id': employeeId,
      'p_manager_user_id': managerUserId,
    });
  }

  static String _assignmentErrorMessage(PostgrestException e) {
    final text = '${e.message} ${e.details} ${e.hint}'.toLowerCase();
    if (e.code == 'PGRST202' ||
        text.contains('admin_update_employee_company') ||
        text.contains('could not find the function')) {
      return 'Database setup incomplete. In Supabase SQL Editor, run: '
          'supabase/fix_admin_employee_assignment.sql';
    }
    if (text.contains('policy') ||
        text.contains('row-level security') ||
        text.contains('permission') ||
        e.code == '42501') {
      return 'Permission denied. In Supabase SQL Editor, run: '
          'supabase/fix_admin_employee_assignment.sql';
    }
    return e.message;
  }
}
