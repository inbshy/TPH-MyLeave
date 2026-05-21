import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:tph_myleave/models/leave_approval_audit.dart';
import 'package:tph_myleave/providers/admin_service_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class ApprovalAuditTimeline extends ConsumerWidget {
  const ApprovalAuditTimeline({super.key, required this.leaveId});

  final int leaveId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(leaveAuditProvider(leaveId));

    return async.when(
      data: (entries) {
        if (entries.isEmpty) {
          return Text(
            'No approval history recorded yet.',
            style: Theme.of(context).textTheme.bodySmall,
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Approval history',
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            ...entries.map((e) => _AuditTile(entry: e)),
          ],
        );
      },
      loading: () => const Padding(
        padding: EdgeInsets.symmetric(vertical: 8),
        child: AppLoadingIndicator(),
      ),
      error: (err, _) => Text(
        'Could not load audit trail: $err',
        style: Theme.of(context).textTheme.bodySmall,
      ),
    );
  }
}

class _AuditTile extends StatelessWidget {
  const _AuditTile({required this.entry});

  final LeaveApprovalAudit entry;

  @override
  Widget build(BuildContext context) {
    final e = entry;
    final time = DateFormat.yMMMd().add_jm().format(e.createdAt.toLocal());

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            Icons.history,
            size: 18,
            color: Theme.of(context).colorScheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${e.actionLabel} · ${e.actorName}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
                Text(
                  '${e.actorRole.isNotEmpty ? '${e.actorRole} · ' : ''}$time',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                if (e.comment.isNotEmpty)
                  Text(e.comment, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
