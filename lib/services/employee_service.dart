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
}
