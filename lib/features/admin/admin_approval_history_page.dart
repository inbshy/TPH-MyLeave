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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Approval History'),
        elevation: 0,
      ),
      body: Column(
        children: [
          // Filters
          Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
            color: colorScheme.surface,
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    value: year,
                    decoration: InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: List.generate(6, (i) => DateTime.now().year - i)
                        .map((y) => DropdownMenuItem(value: y, child: Text('$y')))
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(approvalHistoryYearProvider.notifier).state = v;
                        ref.invalidate(approvalHistoryProvider);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButtonFormField<String?>(
                    value: statusFilter,
                    decoration: InputDecoration(
                      labelText: 'Status',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    ),
                    items: const [
                      DropdownMenuItem(value: null, child: Text('All')),
                      DropdownMenuItem(value: AppConstants.leaveStatusApproved, child: Text('Approved')),
                      DropdownMenuItem(value: AppConstants.leaveStatusRejected, child: Text('Rejected')),
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

          // List
          Expanded(
            child: history.when(
              data: (list) {
                if (list.isEmpty) {
                  return _buildEmptyState(context, year, statusFilter);
                }

                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder: (context, index) {
                    final d = list[index];
                    final r = d.request;
                    final isApproved = r.status == AppConstants.leaveStatusApproved;

                    return Card(
                      elevation: 0,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                      child: ExpansionTile(
                        tilePadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                        childrenPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                        leading: CircleAvatar(
                          backgroundColor: isApproved
                              ? Colors.green.shade100
                              : Colors.red.shade100,
                          child: Icon(
                            isApproved ? Icons.check_circle : Icons.cancel,
                            color: isApproved ? Colors.green.shade700 : Colors.red.shade700,
                          ),
                        ),
                        title: Text(
                          d.employeeName,
                          style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        subtitle: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const SizedBox(height: 4),
                            Text(
                              '${r.leaveType.displayLabel} · ${r.totalLeave} day(s)',
                              style: theme.textTheme.bodyMedium,
                            ),
                            Text(
                              AppDateUtils.formatDateRange(r.dateStart, r.dateEnd),
                              style: theme.textTheme.bodySmall?.copyWith(
                                color: colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ],
                        ),
                        children: [
                          ApprovalAuditTimeline(leaveId: r.id!),
                        ],
                      ),
                    );
                  },
                );
              },
              loading: () => const AppLoadingIndicator(message: 'Loading history...'),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(40),
                  child: Text('Error: $e'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context, int year, String? statusFilter) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final statusText = statusFilter == null ? 'processed' : statusFilter.toLowerCase();

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(40),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.history_toggle_off_rounded,
              size: 80,
              color: colorScheme.primary.withOpacity(0.3),
            ),
            const SizedBox(height: 24),
            Text(
              'No Records Found',
              style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 12),
            Text(
              'No $statusText leave records for $year.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}