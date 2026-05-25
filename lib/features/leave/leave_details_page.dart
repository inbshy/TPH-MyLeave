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

final _leaveByIdProvider = FutureProvider.family<LeaveRequest?, int>((ref, id) async {
  return ref.watch(leaveServiceProvider).fetchLeaveById(id);
});

class LeaveDetailsPage extends ConsumerWidget {
  const LeaveDetailsPage({super.key, required this.leaveId});

  final int leaveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(_leaveByIdProvider(leaveId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Details'),
        elevation: 0,
      ),
      body: async.when(
        data: (leave) {
          if (leave == null) {
            return const Center(child: Text('Request not found.'));
          }
          return _DetailBody(leave: leave, leaveId: leaveId);
        },
        loading: () => const AppLoadingIndicator(message: 'Loading details...'),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(40),
            child: Text('Error: $e'),
          ),
        ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final user = ref.watch(authProvider).user;
    final employeeIdAsync = user == null
        ? const AsyncValue<int?>.data(null)
        : ref.watch(_myEmployeeIdProvider(user.id));
    final myId = employeeIdAsync.valueOrNull;
    final isOwn = myId != null && myId == leave.employeeID;
    final isPending = AppConstants.isPendingLeaveStatus(leave.status);
    final canEdit = isOwn && isPending && AppConstants.canApplyLeave(ref.watch(authProvider).role);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Status Section
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: _statusColor(context).withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      leave.status.toLowerCase() == 'approved'
                          ? Icons.check_circle
                          : leave.status.toLowerCase() == 'rejected'
                              ? Icons.cancel
                              : Icons.hourglass_top,
                      color: _statusColor(context),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Status',
                        style: theme.textTheme.labelMedium,
                      ),
                      Text(
                        _statusLabel(),
                        style: theme.textTheme.titleLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                          color: _statusColor(context),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Main Info Card
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    label: 'Leave Type',
                    value: leave.leaveType.displayLabel,
                    icon: Icons.category_outlined,
                  ),
                  const Divider(height: 28),
                  _InfoRow(
                    label: 'Date Range',
                    value: AppDateUtils.formatDateRange(leave.dateStart, leave.dateEnd),
                    icon: Icons.date_range_outlined,
                  ),
                  const Divider(height: 28),
                  _InfoRow(
                    label: 'Total Days',
                    value: '${leave.totalLeave} day${leave.totalLeave > 1 ? 's' : ''}',
                    icon: Icons.timelapse_outlined,
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Comments & Additional Info
          Card(
            elevation: 0,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _SectionTitle('Your Comment'),
                  Text(
                    leave.employeeComment.isEmpty ? '(No comment provided)' : leave.employeeComment,
                    style: theme.textTheme.bodyLarge,
                  ),

                  if (leave.rejectedReason.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionTitle('Rejection Reason'),
                    Text(
                      leave.rejectedReason,
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: Colors.red.shade700,
                      ),
                    ),
                  ],

                  if (leave.adminComment.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionTitle('Approver Comment'),
                    Text(
                      leave.adminComment,
                      style: theme.textTheme.bodyLarge,
                    ),
                  ],

                  if (leave.approveBy.isNotEmpty) ...[
                    const SizedBox(height: 20),
                    _SectionTitle('Approver'),
                    Text(leave.approveBy, style: theme.textTheme.bodyLarge),
                  ],
                ],
              ),
            ),
          ),

          if (leave.id != null &&
              (leave.status == AppConstants.leaveStatusApproved ||
                  leave.status == AppConstants.leaveStatusRejected)) ...[
            const SizedBox(height: 24),
            ApprovalAuditTimeline(leaveId: leave.id!),
          ],

          // Action Buttons
          if (canEdit) ...[
            const SizedBox(height: 32),
            FilledButton.icon(
              onPressed: () => context.push('/leave/$leaveId/edit'),
              icon: const Icon(Icons.edit_outlined),
              label: const Text('Edit Request'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => _cancel(context, ref),
              icon: const Icon(Icons.cancel_outlined),
              label: const Text('Cancel Request'),
              style: OutlinedButton.styleFrom(
                minimumSize: const Size(double.infinity, 54),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.label,
    required this.value,
    required this.icon,
  });

  final String label;
  final String value;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 22, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: Theme.of(context).textTheme.labelMedium),
              Text(
                value,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

final _myEmployeeIdProvider = FutureProvider.family<int?, String>((ref, userId) {
  return ref.watch(employeeServiceProvider).resolveEmployeeIdForUser(userId);
});