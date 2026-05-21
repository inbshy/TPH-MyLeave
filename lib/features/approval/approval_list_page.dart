import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class ApprovalListPage extends ConsumerWidget {
  const ApprovalListPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(pendingLeaveDetailsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending approvals')),
      body: async.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(child: Text('No pending requests.'));
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final d = list[i];
              final r = d.request;
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: ListTile(
                  onTap: r.id != null
                      ? () => context.push('/approvals/${r.id}')
                      : null,
                  title: Text(d.employeeName),
                  subtitle: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(d.companyName),
                      if (d.groupName != null) Text('Group: ${d.groupName}'),
                      Text(
                        '${r.leaveType.displayLabel} · '
                        '${AppDateUtils.formatDateRange(r.dateStart, r.dateEnd)} · '
                        '${r.totalLeave} day(s)',
                      ),
                      if (r.employeeComment.isNotEmpty)
                        Text(
                          'Note: ${r.employeeComment}',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                    ],
                  ),
                  trailing: r.attachmentPath.isNotEmpty
                      ? const Icon(Icons.attach_file)
                      : null,
                ),
              );
            },
          );
        },
        loading: () => const AppLoadingIndicator(message: 'Loading…'),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
