import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/core/utils/leave_balance_calculator.dart';
import 'package:tph_myleave/core/utils/leave_validators.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/providers/leave_balance_provider.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/services/leave_service.dart';

/// State for leave form operations
class LeaveSubmitState {
  const LeaveSubmitState({
    this.isLoading = false,
    this.error,
    this.successMessage,
  });

  final bool isLoading;
  final String? error;
  final String? successMessage;

  LeaveSubmitState copyWith({
    bool? isLoading,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
  }) {
    return LeaveSubmitState(
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Controller responsible for submitting, updating, and cancelling leave requests
class LeaveFormController extends StateNotifier<LeaveSubmitState> {
  LeaveFormController(this._ref) : super(const LeaveSubmitState());

  final Ref _ref;

  LeaveService get _leaveService => _ref.read(leaveServiceProvider);

  /// Submit a new leave request
  Future<void> submit(LeaveRequest request) async {
    // Validate before submitting
    final validationError = _validateRequest(request);
    if (validationError != null) {
      state = state.copyWith(
        isLoading: false,
        error: validationError,
      );
      return;
    }

    state = state.copyWith(
      isLoading: true,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _leaveService.submitLeave(request);

      // Refresh relevant providers
      _refreshProviders();

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Leave request submitted successfully',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Update an existing pending leave request
  Future<void> updatePending(LeaveRequest request) async {
    final validationError = _validateRequest(request);
    if (validationError != null) {
      state = state.copyWith(isLoading: false, error: validationError);
      return;
    }

    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      await _leaveService.updatePendingLeave(request);
      _refreshProviders();

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Leave request updated successfully',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Cancel a pending leave request
  Future<void> cancelPending(int leaveId) async {
    state = state.copyWith(isLoading: true, clearError: true, clearSuccess: true);

    try {
      await _leaveService.cancelPendingLeave(leaveId);
      _refreshProviders();

      state = state.copyWith(
        isLoading: false,
        successMessage: 'Leave request cancelled successfully',
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: e.toString(),
      );
    }
  }

  /// Private helper to validate leave request
  String? _validateRequest(LeaveRequest request) {
    final balances = _ref.read(myLeaveBalancesProvider).valueOrNull ?? const [];
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

    return check.isValid ? null : check.message;
  }

  /// Refresh all related providers after mutation
  void _refreshProviders() {
    _ref.invalidate(myLeaveRequestsProvider);
    _ref.invalidate(pendingLeaveRequestsProvider);
    // Optionally refresh balances if needed
    // _ref.invalidate(myLeaveBalancesProvider);
  }

  /// Clear current messages (useful when user starts typing again)
  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final leaveFormControllerProvider =
    StateNotifierProvider<LeaveFormController, LeaveSubmitState>((ref) {
  return LeaveFormController(ref);
});