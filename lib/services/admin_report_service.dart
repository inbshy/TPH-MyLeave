import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/core/utils/leave_balance_calculator.dart';
import 'package:tph_myleave/models/employee_leave_overview.dart';
import 'package:tph_myleave/services/company_service.dart';
import 'package:tph_myleave/services/leave_service.dart';

class AdminReportService {
  AdminReportService({
    LeaveService? leaveService,
    CompanyService? companyService,
  })  : _leave = leaveService ?? LeaveService(),
        _company = companyService ?? CompanyService();

  final _client = SupabaseConfig.client;
  final LeaveService _leave;
  final CompanyService _company;

  Future<List<EmployeeLeaveOverview>> fetchEmployeeBalances({
    int? companyId,
    int? groupId,
    int? year,
  }) async {
    final y = year ?? DateTime.now().year;

    Set<int>? companyIdsForGroup;
    if (groupId != null) {
      final companies = await _company.fetchCompanies();
      companyIdsForGroup = companies
          .where((c) => c.groupId == groupId)
          .map((c) => c.id)
          .toSet();
      if (companyIdsForGroup.isEmpty) return [];
    }

    var query = _client
        .from(AppConstants.tableUsers)
        .select('employee_id, name, email, company_id')
        .eq('role', AppConstants.roleEmployee);

    if (companyId != null) {
      query = query.eq('company_id', companyId);
    } else if (companyIdsForGroup != null) {
      query = query.inFilter('company_id', companyIdsForGroup.toList());
    }

    final rows = await query.order('name');
    final users = rows as List<dynamic>;
    final overviews = <EmployeeLeaveOverview>[];

    for (final raw in users) {
      final map = Map<String, dynamic>.from(raw as Map);
      final eid = map['employee_id'] as int;
      final cid = map['company_id'] as int;
      final company = await _company.fetchCompanyById(cid);

      final leaves = await _leave.fetchLeavesForEmployee(eid);
      final balances = LeaveBalanceCalculator.compute(
        requests: leaves,
        year: y,
      );

      overviews.add(
        EmployeeLeaveOverview(
          employeeId: eid,
          name: map['name'] as String,
          email: map['email'] as String,
          companyId: cid,
          companyName: company?.companyName ?? '—',
          groupId: company?.groupId,
          groupName: company?.groupName,
          balances: balances,
        ),
      );
    }

    return overviews;
  }
}
