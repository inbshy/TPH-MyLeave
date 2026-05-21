import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/core/utils/leave_balance_calculator.dart';
import 'package:tph_myleave/core/utils/leave_validators.dart';
import 'package:tph_myleave/providers/leave_balance_provider.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/services/leave_service.dart';

class LeaveSubmitState {
  const LeaveSubmitState({
    this.isLoading = false,
    this.error,
  });

  final bool isLoading;
  final String? error;

  LeaveSubmitState copyWith({
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return LeaveSubmitState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }
}

/// Coordinates submitting a leave request and refreshing lists.
class LeaveFormController extends StateNotifier<LeaveSubmitState> {
  LeaveFormController(this._ref) : super(const LeaveSubmitState());

  final Ref _ref;

  LeaveService get _leave => _ref.read(leaveServiceProvider);

  Future<void> submit(LeaveRequest request) async {
    final balances =
        _ref.read(myLeaveBalancesProvider).valueOrNull ?? const [];
    final remaining = LeaveBalanceCalculator.entryForType(
      balances,
      request.leaveType,
    )?.remainingDays;

    final check = LeaveValidators.validate(
      leaveType: request.leaveType,
      start: request.dateStart,
      end: request.dateEnd,
      remainingDaysThisYear: remaining,
    );
    if (!check.isValid) {
      state = state.copyWith(isLoading: false, error: check.message);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true);
    try {
      await _leave.submitLeave(request);
      _ref.invalidate(myLeaveRequestsProvider);
      _ref.invalidate(pendingLeaveRequestsProvider);
      // Balances derive from myLeaveRequestsProvider.
      state = const LeaveSubmitState();
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }
}

final leaveFormControllerProvider =
    StateNotifierProvider<LeaveFormController, LeaveSubmitState>((ref) {
  return LeaveFormController(ref);
});
