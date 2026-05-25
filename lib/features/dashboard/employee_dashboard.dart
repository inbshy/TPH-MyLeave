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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/apply-leave'),
        icon: const Icon(Icons.add),
        label: const Text('New Leave Request'),
        elevation: 6,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(myLeaveRequestsProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Greeting
              Text(
                'Good morning, $name 👋',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                "Here's what's happening with your leaves",
                style: theme.textTheme.bodyLarge?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),

              const SizedBox(height: 32),

              // Stats & Content
              leavesAsync.when(
                data: (leaves) {
                  final pending = _statusCount(leaves, AppConstants.leaveStatusPending);
                  final approved = _statusCount(leaves, AppConstants.leaveStatusApproved);
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
                              icon: Icons.hourglass_top_rounded,
                              color: Colors.orange.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DashboardStatTile(
                              label: 'Approved',
                              value: '$approved',
                              icon: Icons.check_circle_rounded,
                              color: Colors.green.shade600,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DashboardStatTile(
                              label: 'Total',
                              value: '${leaves.length}',
                              icon: Icons.calendar_today_rounded,
                              color: colorScheme.primary,
                            ),
                          ),
                        ],
                      ),

                      const SizedBox(height: 36),

                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            'Recent Requests',
                            style: theme.textTheme.titleLarge?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          TextButton.icon(
                            onPressed: () => context.push('/leave-history'),
                            icon: const Icon(Icons.arrow_forward, size: 18),
                            label: const Text('See all'),
                          ),
                        ],
                      ),

                      const SizedBox(height: 12),

                      if (recent.isEmpty)
                        _buildEmptyState(context)
                      else
                        ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: recent.length,
                          separatorBuilder: (_, __) => const SizedBox(height: 12),
                          itemBuilder: (context, index) {
                            final r = recent[index];
                            return LeaveCard(
                              request: r,
                              onTap: r.id == null ? null : () => context.push('/leave/${r.id}'),
                            );
                          },
                        ),
                    ],
                  );
                },
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 80),
                  child: AppLoadingIndicator(message: 'Loading your leave data...'),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 60),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text('Failed to load leaves', style: theme.textTheme.titleMedium),
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
            Icons.beach_access,
            size: 72,
            color: theme.colorScheme.primary.withOpacity(0.25),
          ),
          const SizedBox(height: 20),
          Text(
            'No requests yet',
            style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Your leave applications will show up here',
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