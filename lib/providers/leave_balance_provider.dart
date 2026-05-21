import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/core/utils/leave_balance_calculator.dart';
import 'package:tph_myleave/models/leave_balance.dart';
import 'package:tph_myleave/providers/leave_provider.dart';

final leaveBalanceYearProvider = StateProvider<int>((ref) {
  return DateTime.now().year;
});

/// Year-to-date balances for the signed-in employee.
final myLeaveBalancesProvider = Provider<AsyncValue<List<LeaveBalanceEntry>>>((ref) {
  final leavesAsync = ref.watch(myLeaveRequestsProvider);
  final year = ref.watch(leaveBalanceYearProvider);

  return leavesAsync.when(
    data: (requests) => AsyncValue.data(
      LeaveBalanceCalculator.compute(requests: requests, year: year),
    ),
    loading: () => const AsyncLoading(),
    error: (e, st) => AsyncError(e, st),
  );
});
