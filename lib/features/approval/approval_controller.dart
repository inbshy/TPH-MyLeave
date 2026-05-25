import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/providers/admin_service_provider.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/services/leave_service.dart';

/// State for approval/rejection actions
class ApprovalActionState {
  const ApprovalActionState({
    this.processingId,
    this.error,
    this.successMessage,
  });

  final int? processingId;      // ID of leave currently being processed
  final String? error;
  final String? successMessage;

  bool get isProcessing => processingId != null;

  ApprovalActionState copyWith({
    int? processingId,
    String? error,
    String? successMessage,
    bool clearError = false,
    bool clearSuccess = false,
    bool clearProcessing = false,
  }) {
    return ApprovalActionState(
      processingId: clearProcessing ? null : (processingId ?? this.processingId),
      error: clearError ? null : (error ?? this.error),
      successMessage: clearSuccess ? null : (successMessage ?? this.successMessage),
    );
  }
}

/// Controller for approving / rejecting leave requests
class ApprovalController extends StateNotifier<ApprovalActionState> {
  ApprovalController(this._ref) : super(const ApprovalActionState());

  final Ref _ref;

  LeaveService get _leave => _ref.read(leaveServiceProvider);

  /// Get current user's name for audit trail
  Future<String?> _approverName() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return null;
    final profile =
        await _ref.read(authServiceProvider).fetchUserProfile(user.id);
    return profile?['name'] as String?;
  }

  /// Approve a leave request
  Future<void> approve(int leaveId, {String adminComment = ''}) async {
    state = state.copyWith(
      processingId: leaveId,
      clearError: true,
      clearSuccess: true,
    );

    try {
      final role = _ref.read(authProvider).role;
      await _leave.approveLeave(
        leaveId,
        adminComment: adminComment,
        approverName: await _approverName(),
        approverRole: role,
      );

      _invalidateRelatedProviders(leaveId);

      state = state.copyWith(
        processingId: null,
        successMessage: 'Leave request approved successfully',
      );
    } catch (e) {
      state = state.copyWith(
        processingId: null,
        error: e.toString(),
      );
    }
  }

  /// Reject a leave request
  Future<void> reject({
    required int leaveId,
    required String rejectedReason,
    String adminComment = '',
  }) async {
    state = state.copyWith(
      processingId: leaveId,
      clearError: true,
      clearSuccess: true,
    );

    try {
      await _leave.rejectLeave(
        leaveId,
        rejectedReason: rejectedReason,
        adminComment: adminComment,
        approverName: await _approverName(),
      );

      _invalidateRelatedProviders(leaveId);

      state = state.copyWith(
        processingId: null,
        successMessage: 'Leave request rejected',
      );
    } catch (e) {
      state = state.copyWith(
        processingId: null,
        error: e.toString(),
      );
    }
  }

  /// Invalidate all related providers after action
  void _invalidateRelatedProviders(int leaveId) {
    _ref.invalidate(pendingLeaveRequestsProvider);
    _ref.invalidate(pendingLeaveDetailsProvider);
    _ref.invalidate(myLeaveRequestsProvider);
    _ref.invalidate(leaveDetailProvider(leaveId));

    try {
      _ref.invalidate(approvalHistoryProvider);
    } catch (_) {}
  }

  /// Clear messages (call this when user starts a new action)
  void clearMessages() {
    state = state.copyWith(clearError: true, clearSuccess: true);
  }
}

final approvalControllerProvider =
    StateNotifierProvider<ApprovalController, ApprovalActionState>((ref) {
  return ApprovalController(ref);
});