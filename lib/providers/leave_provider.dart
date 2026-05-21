import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/models/admin_leave_stats.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/models/leave_request_detail.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/providers/employee_provider.dart';
import 'package:tph_myleave/services/leave_service.dart';

final leaveServiceProvider = Provider<LeaveService>((ref) => LeaveService());

final myLeaveRequestsProvider = FutureProvider<List<LeaveRequest>>((ref) async {
  final user = ref.watch(authProvider).user;
  if (user == null) return [];
  final eid = await ref
      .watch(employeeServiceProvider)
      .resolveEmployeeIdForUser(user.id);
  if (eid == null) return [];
  return ref.watch(leaveServiceProvider).fetchLeavesForEmployee(eid);
});

final pendingLeaveRequestsProvider =
    FutureProvider<List<LeaveRequest>>((ref) async {
  final role = ref.watch(authProvider).role;
  if (!AppConstants.canApproveLeave(role)) {
    return [];
  }
  return ref.watch(leaveServiceProvider).fetchPendingLeaves(role: role);
});

final pendingLeaveDetailsProvider =
    FutureProvider<List<LeaveRequestDetail>>((ref) async {
  final role = ref.watch(authProvider).role;
  if (!AppConstants.canApproveLeave(role)) {
    return [];
  }
  return ref.watch(leaveServiceProvider).fetchPendingLeaveDetails(role: role);
});

final adminLeaveStatsProvider = FutureProvider<AdminLeaveStats>((ref) async {
  final role = ref.watch(authProvider).role;
  if (role != AppConstants.roleAdmin) {
    return AdminLeaveStats.empty;
  }
  return ref.watch(leaveServiceProvider).fetchAdminLeaveStats();
});

final leaveDetailProvider =
    FutureProvider.family<LeaveRequestDetail?, int>((ref, id) async {
  return ref.watch(leaveServiceProvider).fetchLeaveDetailById(id);
});
