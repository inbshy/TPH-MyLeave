import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/features/dashboard/dashboard_widgets.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/widgets/leave_card.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';
import 'package:tph_myleave/widgets/primary_button.dart';

class ManagerDashboard extends ConsumerWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingLeaveRequestsProvider);

    return RefreshIndicator(
      onRefresh: () => ref.refresh(pendingLeaveRequestsProvider.future),
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Manager overview',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            const SizedBox(height: 8),
            Text(
              'Pending requests from your team appear here. Pull down to refresh.',
              style: Theme.of(context).textTheme.bodyMedium,
            ),
            const SizedBox(height: 24),
            pendingAsync.when(
              data: (List<LeaveRequest> list) {
                final preview = list.take(5).toList();
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: DashboardStatTile(
                            label: 'Awaiting review',
                            value: '${list.length}',
                            icon: Icons.pending_actions_outlined,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 28),
                    Text(
                      'Next up',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    if (preview.isEmpty)
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Text(
                          'No pending leave requests. You are all caught up.',
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      )
                    else
                      ...preview.map((r) {
                        final id = r.id;
                        return LeaveCard(
                          request: r,
                          margin: EdgeInsets.zero,
                          onTap: id == null
                              ? null
                              : () => context.push('/approvals/$id'),
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
                        color: Theme.of(context).colorScheme.error,
                      ),
                ),
              ),
            ),
            const SizedBox(height: 24),
            PrimaryButton(
              label: 'Open approvals',
              icon: Icons.approval,
              onPressed: () => context.push('/approvals'),
            ),
            const SizedBox(height: 12),
            PrimaryButton(
              label: 'Team leave calendar',
              icon: Icons.calendar_month_outlined,
              onPressed: () => context.push('/team-calendar'),
            ),
          ],
        ),
      ),
    );
  }
}
