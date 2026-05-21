import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/providers/admin_service_provider.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/services/leave_service.dart';

class ApprovalActionState {
  const ApprovalActionState({
    this.processingId,
    this.error,
  });

  final int? processingId;
  final String? error;

  ApprovalActionState copyWith({
    int? processingId,
    String? error,
    bool clearError = false,
    bool clearProcessing = false,
  }) {
    return ApprovalActionState(
      processingId: clearProcessing ? null : (processingId ?? this.processingId),
      error: clearError ? null : (error ?? this.error),
    );
  }
}

class ApprovalController extends StateNotifier<ApprovalActionState> {
  ApprovalController(this._ref) : super(const ApprovalActionState());

  final Ref _ref;

  LeaveService get _leave => _ref.read(leaveServiceProvider);

  Future<String?> _approverName() async {
    final user = _ref.read(authProvider).user;
    if (user == null) return null;
    final profile =
        await _ref.read(authServiceProvider).fetchUserProfile(user.id);
    return profile?['name'] as String?;
  }

  Future<void> approve(int leaveId, {String adminComment = ''}) async {
    state = state.copyWith(processingId: leaveId, clearError: true);
    try {
      final role = _ref.read(authProvider).role;
      await _leave.approveLeave(
        leaveId,
        adminComment: adminComment,
        approverName: await _approverName(),
        approverRole: role,
      );
      _invalidate(leaveId);
      state = const ApprovalActionState();
    } catch (e) {
      state = ApprovalActionState(processingId: null, error: e.toString());
    }
  }

  Future<void> reject(
    int leaveId, {
    required String rejectedReason,
    String adminComment = '',
  }) async {
    state = state.copyWith(processingId: leaveId, clearError: true);
    try {
      await _leave.rejectLeave(
        leaveId,
        rejectedReason: rejectedReason,
        adminComment: adminComment,
        approverName: await _approverName(),
      );
      _invalidate(leaveId);
      state = const ApprovalActionState();
    } catch (e) {
      state = ApprovalActionState(processingId: null, error: e.toString());
    }
  }

  void _invalidate(int leaveId) {
    _ref.invalidate(pendingLeaveRequestsProvider);
    _ref.invalidate(pendingLeaveDetailsProvider);
    _ref.invalidate(myLeaveRequestsProvider);
    _ref.invalidate(leaveDetailProvider(leaveId));
    try {
      _ref.invalidate(approvalHistoryProvider);
    } catch (_) {}
  }
}

final approvalControllerProvider =
    StateNotifierProvider<ApprovalController, ApprovalActionState>((ref) {
  return ApprovalController(ref);
});
