import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/features/dashboard/dashboard_widgets.dart';
import 'package:tph_myleave/models/admin_leave_stats.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

/// Admin home: leave overview counts only (navigation via drawer).
class AdminDashboard extends ConsumerWidget {
  const AdminDashboard({super.key});

  static String _summaryMessage(AdminLeaveStats stats) {
    if (stats.pendingApproval == 0) {
      return 'No leave requests are waiting for approval right now.';
    }
    if (stats.pendingApproval == 1) {
      return '1 leave request is waiting for approval.';
    }
    return '${stats.pendingApproval} leave requests are waiting for approval.';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statsAsync = ref.watch(adminLeaveStatsProvider);
    final scheme = Theme.of(context).colorScheme;

    return RefreshIndicator(
      onRefresh: () => ref.refresh(adminLeaveStatsProvider.future),
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
                        'Leave overview',
                        style: Theme.of(context).textTheme.bodyMedium,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            statsAsync.when(
              data: (stats) => Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    elevation: 0,
                    color: stats.pendingApproval > 0
                        ? scheme.primaryContainer
                        : scheme.surfaceContainerHighest,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            stats.pendingApproval > 0
                                ? Icons.info_outline
                                : Icons.check_circle_outline,
                            color: stats.pendingApproval > 0
                                ? scheme.onPrimaryContainer
                                : scheme.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _summaryMessage(stats),
                              style: Theme.of(context).textTheme.bodyLarge,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    'Leave requests',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 12),
                  _StatGrid(stats: stats),
                ],
              ),
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 32),
                child: AppLoadingIndicator(message: 'Loading overview…'),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Could not load overview: $e',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: scheme.error,
                      ),
                ),
              ),
            ),
          ],
        ),
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
        label: 'Pending approval',
        value: '${stats.pendingApproval}',
        icon: Icons.pending_actions_outlined,
      ),
      _StatDef(
        label: 'Approved',
        value: '${stats.approved}',
        icon: Icons.check_circle_outline,
      ),
      _StatDef(
        label: 'Rejected',
        value: '${stats.rejected}',
        icon: Icons.cancel_outlined,
      ),
      _StatDef(
        label: 'Total requests',
        value: '${stats.total}',
        icon: Icons.event_note_outlined,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final crossCount = width >= 520 ? 3 : 2;
        final tileWidth = (width - (crossCount - 1) * 12) / crossCount;

        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: tiles
              .map(
                (t) => SizedBox(
                  width: tileWidth,
                  child: DashboardStatTile(
                    label: t.label,
                    value: t.value,
                    icon: t.icon,
                  ),
                ),
              )
              .toList(),
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
  });

  final String label;
  final String value;
  final IconData icon;
}
