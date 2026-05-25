import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/features/dashboard/dashboard_widgets.dart';
import 'package:tph_myleave/models/admin_leave_stats.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  static String _summaryMessage(AdminLeaveStats stats) {
    if (stats.pendingApproval == 0) {
      return 'All leave requests are processed. Great job!';
    }
    if (stats.pendingApproval == 1) {
      return '1 leave request is waiting for your approval.';
    }
    return '${stats.pendingApproval} leave requests are waiting for approval.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminLeaveStatsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => context.push('/admin/pending-leaves'),
        icon: const Icon(Icons.pending_actions),
        label: const Text('Review Pending'),
        elevation: 6,
      ),
      body: RefreshIndicator(
        onRefresh: () => ref.refresh(adminLeaveStatsProvider.future),
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(20, 52, 20, 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  CircleAvatar(
                    radius: 28,
                    backgroundColor: colorScheme.primaryContainer,
                    child: const Icon(
                      Icons.admin_panel_settings,
                      size: 28,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Administrator',
                          style: theme.textTheme.headlineMedium?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          'Leave Management Overview',
                          style: theme.textTheme.bodyLarge?.copyWith(
                            color: colorScheme.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 32),

              // Summary Card
              statsAsync.when(
                data: (stats) => _buildSummaryCard(context, stats),
                loading: () => const Padding(
                  padding: EdgeInsets.symmetric(vertical: 60),
                  child: AppLoadingIndicator(message: 'Loading admin overview...'),
                ),
                error: (e, _) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Center(
                    child: Column(
                      children: [
                        Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                        const SizedBox(height: 12),
                        Text('Failed to load data', style: theme.textTheme.titleMedium),
                        Text('$e', textAlign: TextAlign.center),
                      ],
                    ),
                  ),
                ),
              ),

              const SizedBox(height: 36),

              // Stats Section
              Text(
                'Leave Statistics',
                style: theme.textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),

              statsAsync.when(
                data: (stats) => _StatGrid(stats: stats),
                loading: () => const SizedBox.shrink(),
                error: (_, __) => const SizedBox.shrink(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSummaryCard(BuildContext context, AdminLeaveStats stats) {
    final colorScheme = Theme.of(context).colorScheme;
    final hasPending = stats.pendingApproval > 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: hasPending ? colorScheme.primaryContainer : colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: hasPending
              ? colorScheme.primary.withOpacity(0.3)
              : colorScheme.outlineVariant,
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(
            hasPending ? Icons.pending_actions : Icons.check_circle,
            size: 32,
            color: hasPending ? colorScheme.primary : colorScheme.primary,
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              _summaryMessage(stats),
              style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    height: 1.4,
                    fontWeight: hasPending ? FontWeight.w500 : FontWeight.normal,
                  ),
            ),
          ),
        ],
      ),
    );
  }
}

class _StatGrid extends StatelessWidget {
  const _StatGrid({required this.stats});

  final AdminLeaveStats stats;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      _StatDef(
        label: 'Pending Approval',
        value: '${stats.pendingApproval}',
        icon: Icons.pending_actions_outlined,
        color: Colors.orange.shade600,
      ),
      _StatDef(
        label: 'Approved',
        value: '${stats.approved}',
        icon: Icons.check_circle_outline,
        color: Colors.green.shade600,
      ),
      _StatDef(
        label: 'Rejected',
        value: '${stats.rejected}',
        icon: Icons.cancel_outlined,
        color: Colors.red.shade600,
      ),
      _StatDef(
        label: 'Total Requests',
        value: '${stats.total}',
        icon: Icons.event_note_outlined,
        color: null, // Uses default primary
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth >= 600 ? 4 : 2;
        return GridView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            childAspectRatio: 1.15,
          ),
          itemCount: tiles.length,
          itemBuilder: (context, index) {
            final t = tiles[index];
            return DashboardStatTile(
              label: t.label,
              value: t.value,
              icon: t.icon,
              color: t.color,
            );
          },
        );
      },
    );
  }
}

class _StatDef {
  const _StatDef({
    required this.label,
    required this.value,
    required this.icon,
    this.color,
  });

  final String label;
  final String value;
  final IconData icon;
  final Color? color;
}