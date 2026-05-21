import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/models/employee_leave_overview.dart';
import 'package:tph_myleave/services/admin_report_service.dart';

final adminReportServiceProvider =
    Provider<AdminReportService>((ref) => AdminReportService());

final adminSelectedGroupIdProvider = StateProvider<int?>((ref) => null);
final adminSelectedCompanyIdProvider = StateProvider<int?>((ref) => null);

final adminEmployeeBalancesProvider =
    FutureProvider<List<EmployeeLeaveOverview>>((ref) async {
  final companyId = ref.watch(adminSelectedCompanyIdProvider);
  final groupId = ref.watch(adminSelectedGroupIdProvider);
  return ref.watch(adminReportServiceProvider).fetchEmployeeBalances(
        companyId: companyId,
        groupId: companyId == null ? groupId : null,
      );
});
