import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/models/leave_balance.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/providers/leave_balance_provider.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class LeaveBalancePage extends ConsumerWidget {
  const LeaveBalancePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).role;
    if (!AppConstants.canApplyLeave(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final year = ref.watch(leaveBalanceYearProvider);
    final balancesAsync = ref.watch(myLeaveBalancesProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave balance'),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myLeaveRequestsProvider);
          await ref.read(myLeaveRequestsProvider.future);
        },
        child: balancesAsync.when(
          data: (balances) {
            final capped = balances.where((b) => !b.isUnlimited).toList();
            final totalEntitlement =
                capped.fold<int>(0, (s, b) => s + (b.entitlement ?? 0));
            final totalUsed =
                capped.fold<int>(0, (s, b) => s + b.usedDays);
            final totalPending =
                capped.fold<int>(0, (s, b) => s + b.pendingDays);
            final totalRemaining =
                capped.fold<int>(0, (s, b) => s + (b.remainingDays ?? 0));

            return ListView(
              padding: const EdgeInsets.all(24),
              physics: const AlwaysScrollableScrollPhysics(),
              children: [
                Text(
                  'Entitlement and remaining days for $year.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                Card(
                  color: Theme.of(context).colorScheme.primaryContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Summary (capped leave types)',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                        const SizedBox(height: 12),
                        _SummaryRow(
                          label: 'Total entitlement',
                          value: '$totalEntitlement days',
                        ),
                        _SummaryRow(
                          label: 'Used (approved)',
                          value: '$totalUsed days',
                        ),
                        _SummaryRow(
                          label: 'Pending',
                          value: '$totalPending days',
                        ),
                        const Divider(height: 20),
                        _SummaryRow(
                          label: 'Remaining',
                          value: '$totalRemaining days',
                          bold: true,
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'Breakdown by type',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
                const SizedBox(height: 8),
                ...balances.map((e) => _BalanceCard(entry: e)),
              ],
            );
          },
          loading: () => const AppLoadingIndicator(
            message: 'Calculating leave balance…',
          ),
          error: (e, _) => ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            children: [
              const SizedBox(height: 48),
              Center(child: Text('Error: $e')),
            ],
          ),
        ),
      ),
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.entry});

  final LeaveBalanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final cap = entry.entitlement;
    final remaining = entry.remainingDays;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.type.displayLabel,
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            if (entry.isUnlimited) ...[
              _DetailRow(label: 'Entitlement', value: 'No limit'),
              _DetailRow(label: 'Used (approved)', value: '${entry.usedDays}'),
              _DetailRow(label: 'Pending', value: '${entry.pendingDays}'),
            ] else ...[
              _DetailRow(
                label: 'Entitlement',
                value: '$cap day(s) / year',
              ),
              _DetailRow(
                label: 'Used (approved)',
                value: '${entry.usedDays} day(s)',
              ),
              _DetailRow(
                label: 'Pending',
                value: '${entry.pendingDays} day(s)',
              ),
              const Divider(height: 24),
              Text(
                'Remaining',
                style: Theme.of(context).textTheme.labelLarge,
              ),
              const SizedBox(height: 4),
              Text(
                '$remaining day(s)',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                      color: remaining == 0 ? scheme.error : scheme.primary,
                      fontWeight: FontWeight.bold,
                    ),
              ),
              const SizedBox(height: 8),
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: entry.usageFraction ?? 0,
                  minHeight: 8,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryRow extends StatelessWidget {
  const _SummaryRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

  final String label;
  final String value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: bold ? FontWeight.bold : FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyMedium),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
          ),
        ],
      ),
    );
  }
}
