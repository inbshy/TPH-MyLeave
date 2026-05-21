import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/features/dashboard/dashboard_widgets.dart';
import 'package:tph_myleave/models/leave_request_detail.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';
import 'package:tph_myleave/widgets/primary_button.dart';

/// Admin home: review and approve leave only (no apply-leave flows).
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingLeaveDetailsProvider);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(pendingLeaveDetailsProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: scheme.primaryContainer,
                  foregroundColor: scheme.onPrimaryContainer,
                  child: const Icon(Icons.admin_panel_settings_outlined),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Administrator',
                        style: Theme.of(context).textTheme.headlineSmall,
                      ),
                      Text(
                        'Approve employee leave requests. Admins do not apply for leave.',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            pendingAsync.when(
              data: (List<LeaveRequestDetail> pending) {
                final preview = pending.take(5).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DashboardStatTile(
                            label: 'Awaiting approval',
                            value: '${pending.length}',
                            icon: Icons.pending_actions_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Pending requests',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (preview.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No pending leave requests.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ...preview.map((d) {
                        final r = d.request;
                        final id = r.id;
                        return Card(
                          margin: EdgeInsets.zero,
                          child: ListTile(
                            onTap: id == null
                                ? null
                                : () => context.push('/approvals/$id'),
                            title: Text(d.employeeName),
                            subtitle: Text(
                              '${d.companyName} · ${r.leaveType.displayLabel}\n'
                              '${r.totalLeave} day(s)',
                              maxLines: 2,
                            ),
                            trailing: r.attachmentPath.isNotEmpty
                                ? const Icon(Icons.attach_file)
                                : null,
                          ),
                        );
                      }),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: AppLoadingIndicator(
                  message: 'Loading pending requests…',
                ),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Could not load requests: $e',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Open approval queue',
              icon: Icons.approval,
              onPressed: () => context.push('/approvals'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Employee leave balances',
              icon: Icons.groups_outlined,
              onPressed: () => context.push('/admin/employee-balances'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Team leave calendar',
              icon: Icons.calendar_month_outlined,
              onPressed: () => context.push('/team-calendar'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Employee directory',
              icon: Icons.badge_outlined,
              onPressed: () => context.push('/admin/employee-directory'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Leave usage report',
              icon: Icons.analytics_outlined,
              onPressed: () => context.push('/admin/leave-usage'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Approval history',
              icon: Icons.history,
              onPressed: () => context.push('/admin/approval-history'),
            ),
          ],
        ),
      ),
    );
  }
}
