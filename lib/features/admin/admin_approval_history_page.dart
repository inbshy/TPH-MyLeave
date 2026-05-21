import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/core/utils/date_utils.dart';
import 'package:tph_myleave/providers/admin_service_provider.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/widgets/approval_audit_timeline.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class AdminApprovalHistoryPage extends ConsumerWidget {
  const AdminApprovalHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).role;
    if (role != AppConstants.roleAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final history = ref.watch(approvalHistoryProvider);
    final year = ref.watch(approvalHistoryYearProvider);
    final statusFilter = ref.watch(approvalHistoryStatusProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Approval history')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: year,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(5, (i) => DateTime.now().year - i)
                        .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(approvalHistoryYearProvider.notifier).state = v;
                        ref.invalidate(approvalHistoryProvider);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    initialValue: statusFilter,
                    decoration: const InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All processed')),
                      DropdownMenuItem(
                        value: AppConstants.leaveStatusApproved,
                        child: Text('Approved'),
                      ),
                      DropdownMenuItem(
                        value: AppConstants.leaveStatusRejected,
                        child: Text('Rejected'),
                      ),
                    ],
                    onChanged: (v) {
                      ref.read(approvalHistoryStatusProvider.notifier).state = v;
                      ref.invalidate(approvalHistoryProvider);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: history.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No records for this filter.'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: list.length,
                  itemBuilder: (_, i) {
                    final d = list[i];
                    final r = d.request;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 10),
                      child: ExpansionTile(
                        title: Text(d.employeeName),
                        subtitle: Text(
                          '${r.leaveType.displayLabel} · ${r.status}\n'
                          '${AppDateUtils.formatDateRange(r.dateStart, r.dateEnd)}',
                        ),
                        children: [
                          Padding(
                            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
                            child: ApprovalAuditTimeline(leaveId: r.id!),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
