import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/features/dashboard/dashboard_widgets.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/widgets/leave_card.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';
import 'package:tph_myleave/widgets/primary_button.dart';

class EmployeeDashboard extends ConsumerWidget {
  const EmployeeDashboard({super.key});

  static String _greetingName(String? email) {
    if (email == null || email.isEmpty) return 'there';
    final local = email.split('@').first;
    return local.isEmpty ? 'there' : local;
  }

  static int _statusCount(List<LeaveRequest> list, String status) {
    final s = status.toLowerCase();
    return list.where((e) => e.status.toLowerCase() == s).length;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final email = ref.watch(authProvider).user?.email;
    final name = _greetingName(email);
    final leavesAsync = ref.watch(myLeaveRequestsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(myLeaveRequestsProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Hi, $name',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Track your leave at a glance, or start a new request.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            leavesAsync.when(
              data: (leaves) {
                final pending =
                    _statusCount(leaves, AppConstants.leaveStatusPending);
                final approved =
                    _statusCount(leaves, AppConstants.leaveStatusApproved);
                final recent = leaves.take(3).toList();

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DashboardStatTile(
                            label: 'Pending',
                            value: '$pending',
                            icon: Icons.hourglass_top_outlined,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DashboardStatTile(
                            label: 'Approved',
                            value: '$approved',
                            icon: Icons.check_circle_outline,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: DashboardStatTile(
                            label: 'Total',
                            value: '${leaves.length}',
                            icon: Icons.event_note_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Row(
                      children: [
                        Text(
                          'Recent requests',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const Spacer(),
                        TextButton(
                          onPressed: () => context.push('/leave-history'),
                          child: const Text('See all'),
                        ),
                      ],
                    ),
                    if (recent.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'You have not submitted any leave yet.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ...recent.map((r) {
                        final id = r.id;
                        return LeaveCard(
                          request: r,
                          margin: EdgeInsets.zero,
                          onTap: id == null
                              ? null
                              : () => context.push('/leave/$id'),
                        );
                      }),
                  ],
                );
              },
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: AppLoadingIndicator(message: 'Loading your leave…'),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Could not load leave: $e',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Apply for leave',
              icon: Icons.add_circle_outline,
              onPressed: () => context.push('/apply-leave'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'View leave balance',
              icon: Icons.pie_chart_outline,
              onPressed: () => context.push('/leave-balance'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Leave history',
              icon: Icons.history,
              onPressed: () => context.push('/leave-history'),
            ),
          ],
        ),
      ),
    );
  }
}
