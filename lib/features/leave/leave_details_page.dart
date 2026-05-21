import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
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
          return _DetailBody(leave: leave);
        },
        loading: () => const AppLoadingIndicator(),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _DetailBody extends StatelessWidget {
  const _DetailBody({required this.leave});

  final LeaveRequest leave;

  String _statusLabel(BuildContext context) {
    return switch (leave.status.toLowerCase()) {
      'approved' => 'Approved',
      'rejected' => 'Rejected',
      _ => 'Pending approval',
    };
  }

  Color _statusColor(BuildContext context) {
    final s = leave.status.toLowerCase();
    if (s == 'approved') return Colors.green.shade700;
    if (s == 'rejected') return Colors.red.shade700;
    return Theme.of(context).colorScheme.tertiary;
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;
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
                Row(
                  children: [
                    Icon(
                      Icons.description_outlined,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text('Status', style: t.labelMedium),
                  ],
                ),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 10,
                  children: [
                    Chip(
                      label: Text(
                        _statusLabel(context),
                        style: TextStyle(
                          color: _statusColor(context),
                        ),
                      ),
                      backgroundColor: _statusColor(context).withValues(alpha: 0.15),
                      side: BorderSide(color: _statusColor(context)),
                    ),
                  ],
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
          Text('Admin comment', style: t.labelMedium),
          Text(leave.adminComment, style: t.bodyMedium),
        ],
      ],
    );
  }
}
