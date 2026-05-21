import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/core/utils/leave_balance_calculator.dart';
import 'package:tph_myleave/models/employee_leave_summary.dart';
import 'package:tph_myleave/providers/employee_provider.dart';
import 'package:tph_myleave/providers/leave_balance_provider.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/services/leave_service.dart';

final adminStaffBalancesProvider =
    FutureProvider.family<List<EmployeeLeaveSummary>, int>((ref, companyId) async {
  final year = ref.watch(leaveBalanceYearProvider);
  final staff =
      await ref.watch(employeeServiceProvider).fetchStaffForCompany(companyId);
  final leaveService = ref.watch(leaveServiceProvider);

  final summaries = <EmployeeLeaveSummary>[];
  for (final person in staff) {
    final requests = await leaveService.fetchLeavesForEmployee(person.employeeId);
    final balances =
        LeaveBalanceCalculator.compute(requests: requests, year: year);
    summaries.add(
      EmployeeLeaveSummary(
        employeeId: person.employeeId,
        name: person.name,
        companyName: '',
        balances: balances,
      ),
    );
  }
  return summaries;
});
