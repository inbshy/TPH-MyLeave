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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Leave Balance'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myLeaveRequestsProvider);
          await ref.read(myLeaveRequestsProvider.future);
        },
        child: balancesAsync.when(
          data: (balances) {
            final capped = balances.where((b) => !b.isUnlimited).toList();
            final totalEntitlement = capped.fold<int>(0, (s, b) => s + (b.entitlement ?? 0));
            final totalUsed = capped.fold<int>(0, (s, b) => s + b.usedDays);
            final totalPending = capped.fold<int>(0, (s, b) => s + b.pendingDays);
            final totalRemaining = capped.fold<int>(0, (s, b) => s + (b.remainingDays ?? 0));

            return SingleChildScrollView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header
                  Text(
                    'Leave Balance $year',
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Your entitlement and usage overview',
                    style: theme.textTheme.bodyLarge?.copyWith(
                      color: colorScheme.onSurfaceVariant,
                    ),
                  ),

                  const SizedBox(height: 32),

                  // Overall Summary Card
                  Card(
                    elevation: 0,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                    color: colorScheme.primaryContainer.withAlpha(50),
                    child: Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(Icons.summarize_rounded, color: colorScheme.primary),
                              const SizedBox(width: 8),
                              Text(
                                'Overall Summary',
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _SummaryRow(label: 'Total Entitlement', value: '$totalEntitlement days'),
                          _SummaryRow(label: 'Used (Approved)', value: '$totalUsed days'),
                          _SummaryRow(label: 'Pending Approval', value: '$totalPending days'),
                          const Divider(height: 24),
                          _SummaryRow(
                            label: 'Total Remaining',
                            value: '$totalRemaining days',
                            bold: true,
                            valueColor: totalRemaining > 0 ? colorScheme.primary : colorScheme.error,
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // Breakdown Section
                  Text(
                    'Breakdown by Leave Type',
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 12),

                  ...balances.map((entry) => _BalanceCard(entry: entry)),
                ],
              ),
            );
          },
          loading: () => const Padding(
            padding: EdgeInsets.only(top: 100),
            child: AppLoadingIndicator(message: 'Calculating leave balance…'),
          ),
          error: (e, _) => Padding(
            padding: const EdgeInsets.all(40),
            child: Center(
              child: Column(
                children: [
                  Icon(Icons.error_outline, size: 48, color: colorScheme.error),
                  const SizedBox(height: 16),
                  Text('Failed to load balance', style: theme.textTheme.titleMedium),
                  const SizedBox(height: 8),
                  Text('$e', textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ==================== Helper Widgets ====================

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.entry});

  final LeaveBalanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final remaining = entry.remainingDays ?? 0;

    return Card(
      margin: const EdgeInsets.only(bottom: 16),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              entry.type.displayLabel,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 16),

            if (entry.isUnlimited) ...[
              _DetailRow(label: 'Entitlement', value: 'Unlimited'),
              _DetailRow(label: 'Used', value: '${entry.usedDays} days'),
              _DetailRow(label: 'Pending', value: '${entry.pendingDays} days'),
            ] else ...[
              _DetailRow(
                label: 'Entitlement',
                value: '${entry.entitlement} days / year',
              ),
              _DetailRow(label: 'Used', value: '${entry.usedDays} days'),
              _DetailRow(label: 'Pending', value: '${entry.pendingDays} days'),

              const SizedBox(height: 20),

              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('Remaining', style: theme.textTheme.titleSmall),
                  Text(
                    '$remaining days',
                    style: theme.textTheme.headlineSmall?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: remaining == 0 ? colorScheme.error : colorScheme.primary,
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 12),
              ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: LinearProgressIndicator(
                  value: entry.usageFraction ?? 0,
                  minHeight: 10,
                  backgroundColor: colorScheme.surfaceContainerHighest,
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
    this.valueColor,
  });

  final String label;
  final String value;
  final bool bold;
  final Color? valueColor;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: Theme.of(context).textTheme.bodyLarge),
          Text(
            value,
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                  fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
                  color: valueColor,
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
      padding: const EdgeInsets.symmetric(vertical: 5),
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