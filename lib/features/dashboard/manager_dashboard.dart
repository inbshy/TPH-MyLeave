import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/features/dashboard/dashboard_widgets.dart';
import 'package:tph_myleave/models/leave_request.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/widgets/leave_card.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class ManagerDashboard extends ConsumerWidget {
  const ManagerDashboard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingLeaveRequestsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/approvals'),
        icon: const Icon(Icons.pending_actions),
        label: const Text('Review All'),
        elevation: 6,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(pendingLeaveRequestsProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Text(
                'Team Overview',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Manage your team\'s leave requests',
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // Stats Section
              pendingAsync.when(
                data: (List<LeaveRequest> list) {
                  final pendingCount = list.length;
                  final preview = list.take(5).toList();

                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      DashboardStatTile(
                        label: 'Awaiting Your Review',
                        value: '$pendingCount',
                        icon: Icons.pending_actions_rounded,
                        color: Colors.orange.shade600,
                      ),

                      const SizedBox(height: 36),

                      // Recent / Next Up
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Pending Requests',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          if (pendingCount > 5)
                            TextButton.icon(
                              onPressed: () => context.push('/approvals'),
                              icon: const Icon(Icons.arrow_forward, size: 18),
                              label: const Text('See all'),
                            ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (preview.isEmpty)
                        _buildEmptyState(context)
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: preview.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final request = preview[index];
                            return LeaveCard(
                              request: request,
                              onTap: request.id == null
                                  ? null
                                  : () => context.push('/approvals/${request.id}'),
                            );
                          },
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: AppLoadingIndicator(
                    message: 'Loading team requests...',
                  ),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text('Failed to load requests', style: theme.textTheme.titleMedium),
                        Text('$e', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 60),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(
            Icons.check_circle_outline,
            size: 72,
            color: theme.colorScheme.primary.withOpacity(0.25),
          ),
          const SizedBox(height: 20),
          Text(
            'All caught up!',
            style: theme.textTheme.titleLarge?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'No pending leave requests from your team',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}