import 'package:flutter/material.dart';
import 'package:tph_myleave/models/leave_balance.dart';

/// Compact leave-balance strip for the employee dashboard.
class LeaveBalanceSummary extends StatelessWidget {
  const LeaveBalanceSummary({
    super.key,
    required this.balances,
    required this.year,
    this.onViewAll,
  });

  final List<LeaveBalanceEntry> balances;
  final VoidCallback? onViewAll;
  final int year;

  @override
  Widget build(BuildContext context) {
    final capped = balances.where((b) => !b.isUnlimited).toList();
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Row(
          children: [
            Icon(Icons.account_balance_wallet_outlined, color: colorScheme.primary),
            const SizedBox(width: 10),
            Text(
              'Leave Balance ($year)',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Spacer(),
            if (onViewAll != null)
              TextButton(
                onPressed: onViewAll,
                child: const Text('View all'),
              ),
          ],
        ),

        const SizedBox(height: 16),

        if (capped.isEmpty)
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.info_outline, color: colorScheme.primary),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'No leave recorded this year yet.',
                    style: theme.textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          )
        else
          ...capped.map((entry) => _BalanceCard(entry: entry)),
      ],
    );
  }
}

class _BalanceCard extends StatelessWidget {
  const _BalanceCard({required this.entry});

  final LeaveBalanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final remaining = entry.remainingDays ?? 0;
    final isLow = remaining <= 3 && !entry.isUnlimited;

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colorScheme.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Type + Remaining
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.type.displayLabel,
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: isLow
                      ? colorScheme.errorContainer
                      : colorScheme.primaryContainer,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  entry.isUnlimited
                      ? (entry.bookedDays == 0 ? 'Unlimited' : '${entry.bookedDays} used')
                      : '$remaining left',
                  style: theme.textTheme.labelMedium?.copyWith(
                    color: isLow
                        ? colorScheme.onErrorContainer
                        : colorScheme.onPrimaryContainer,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 12),

          // Progress Bar
          if (!entry.isUnlimited) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: LinearProgressIndicator(
                value: entry.usageFraction ?? 0,
                minHeight: 8,
                backgroundColor: colorScheme.surfaceContainerHighest,
                color: isLow ? colorScheme.error : colorScheme.primary,
              ),
            ),
            const SizedBox(height: 10),
          ],

          // Used + Pending
          Row(
            children: [
              _StatChip(
                icon: Icons.check_circle_outline,
                label: 'Used',
                value: '${entry.usedDays}',
              ),
              const SizedBox(width: 16),
              _StatChip(
                icon: Icons.hourglass_top_outlined,
                label: 'Pending',
                value: '${entry.pendingDays}',
              ),
              if (!entry.isUnlimited) ...[
                const Spacer(),
                Text(
                  '${entry.entitlement} total',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  const _StatChip({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Row(
      children: [
        Icon(icon, size: 16, color: colorScheme.primary),
        const SizedBox(width: 6),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}