import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:tph_myleave/core/constants/app_constants.dart';

import 'package:tph_myleave/core/utils/date_utils.dart';

import 'package:tph_myleave/features/leave/leave_controller.dart';

import 'package:tph_myleave/models/leave_request.dart';

import 'package:tph_myleave/providers/auth_provider.dart';

import 'package:tph_myleave/providers/employee_provider.dart';

import 'package:tph_myleave/providers/leave_provider.dart';

import 'package:tph_myleave/widgets/approval_audit_timeline.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';



final _leaveByIdProvider =

    FutureProvider.family<LeaveRequest?, int>((ref, id) async {

  return ref.watch(leaveServiceProvider).fetchLeaveById(id);

});



class LeaveDetailsPage extends ConsumerWidget {

  const LeaveDetailsPage({super.key, required this.leaveId});



  final int leaveId;



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final async = ref.watch(_leaveByIdProvider(leaveId));



    return Scaffold(

      appBar: AppBar(title: const Text('Leave details')),

      body: async.when(

        data: (leave) {

          if (leave == null) {

            return const Center(child: Text('Request not found.'));

          }

          return _DetailBody(leave: leave, leaveId: leaveId);

        },

        loading: () => const AppLoadingIndicator(),

        error: (e, _) => Center(child: Text('Error: $e')),

      ),

    );

  }

}



class _DetailBody extends ConsumerWidget {

  const _DetailBody({required this.leave, required this.leaveId});



  final LeaveRequest leave;

  final int leaveId;



  String _statusLabel() {

    return switch (leave.status.toLowerCase()) {

      'approved' => 'Approved',

      'rejected' => 'Rejected',

      'cancelled' => 'Cancelled',

      _ => AppConstants.pendingStatusLabel(leave.status),

    };

  }



  Color _statusColor(BuildContext context) {

    final s = leave.status.toLowerCase();

    if (s == 'approved') return Colors.green.shade700;

    if (s == 'rejected') return Colors.red.shade700;

    if (s == 'cancelled') return Colors.grey.shade700;

    return Theme.of(context).colorScheme.tertiary;

  }



  Future<void> _cancel(BuildContext context, WidgetRef ref) async {

    final ok = await showDialog<bool>(

      context: context,

      builder: (ctx) => AlertDialog(

        title: const Text('Cancel leave?'),

        content: const Text(

          'This will cancel your pending request. You can submit a new one later.',

        ),

        actions: [

          TextButton(

            onPressed: () => Navigator.pop(ctx, false),

            child: const Text('No'),

          ),

          FilledButton(

            onPressed: () => Navigator.pop(ctx, true),

            child: const Text('Yes, cancel'),

          ),

        ],

      ),

    );

    if (ok != true || !context.mounted) return;



    await ref.read(leaveFormControllerProvider.notifier).cancelPending(leaveId);

    final err = ref.read(leaveFormControllerProvider).error;

    if (!context.mounted) return;

    if (err != null) {

      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));

      return;

    }

    ref.invalidate(_leaveByIdProvider(leaveId));

    ref.invalidate(myLeaveRequestsProvider);

    ScaffoldMessenger.of(context).showSnackBar(

      const SnackBar(content: Text('Leave request cancelled.')),

    );

  }



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final t = Theme.of(context).textTheme;

    final user = ref.watch(authProvider).user;

    final employeeIdAsync = user == null

        ? const AsyncValue<int?>.data(null)

        : ref.watch(_myEmployeeIdProvider(user.id));

    final myId = employeeIdAsync.valueOrNull;

    final isOwn = myId != null && myId == leave.employeeID;

    final isPending = AppConstants.isPendingLeaveStatus(leave.status);

    final canEdit = isOwn && isPending && AppConstants.canApplyLeave(ref.watch(authProvider).role);



    return ListView(

      padding: const EdgeInsets.all(24),

      children: [

        Card(

          elevation: 0,

          child: Padding(

            padding: const EdgeInsets.all(16),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text('Status', style: t.labelMedium),

                const SizedBox(height: 8),

                Chip(

                  label: Text(

                    _statusLabel(),

                    style: TextStyle(color: _statusColor(context)),

                  ),

                  backgroundColor: _statusColor(context).withValues(alpha: 0.15),

                  side: BorderSide(color: _statusColor(context)),

                ),

              ],

            ),

          ),

        ),

        const SizedBox(height: 16),

        Text('Dates', style: t.labelMedium),

        Text(

          AppDateUtils.formatDateRange(leave.dateStart, leave.dateEnd),

          style: t.titleMedium,

        ),

        const SizedBox(height: 16),

        Text('Type', style: t.labelMedium),

        Text(leave.leaveType.displayLabel, style: t.titleMedium),

        const SizedBox(height: 16),

        Text('Total days', style: t.labelMedium),

        Text('${leave.totalLeave}', style: t.titleMedium),

        if (leave.approveBy.isNotEmpty) ...[

          const SizedBox(height: 16),

          Text('Approver', style: t.labelMedium),

          Text(leave.approveBy, style: t.titleMedium),

        ],

        const SizedBox(height: 16),

        Text('Your comment', style: t.labelMedium),

        Text(

          leave.employeeComment.isEmpty ? '(none)' : leave.employeeComment,

          style: t.bodyMedium,

        ),

        if (leave.rejectedReason.isNotEmpty) ...[

          const SizedBox(height: 16),

          Text('Rejection reason', style: t.labelMedium),

          Text(

            leave.rejectedReason,

            style: t.bodyMedium?.copyWith(color: Colors.red.shade700),

          ),

        ],

        if (leave.adminComment.isNotEmpty) ...[

          const SizedBox(height: 16),

          Text('Approver comment', style: t.labelMedium),

          Text(leave.adminComment, style: t.bodyMedium),

        ],

        if (leave.id != null &&
            (leave.status == AppConstants.leaveStatusApproved ||
                leave.status == AppConstants.leaveStatusRejected)) ...[
          const SizedBox(height: 16),
          ApprovalAuditTimeline(leaveId: leave.id!),
        ],
        if (canEdit) ...[

          const SizedBox(height: 24),

          FilledButton.icon(

            onPressed: () => context.push('/leave/$leaveId/edit'),

            icon: const Icon(Icons.edit_outlined),

            label: const Text('Edit request'),

          ),

          const SizedBox(height: 8),

          OutlinedButton.icon(

            onPressed: () => _cancel(context, ref),

            icon: const Icon(Icons.cancel_outlined),

            label: const Text('Cancel request'),

          ),

        ],

      ],

    );

  }

}



final _myEmployeeIdProvider = FutureProvider.family<int?, String>((ref, userId) {

  return ref.watch(employeeServiceProvider).resolveEmployeeIdForUser(userId);

});


