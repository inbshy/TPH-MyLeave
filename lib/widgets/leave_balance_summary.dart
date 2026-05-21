import 'package:flutter/material.dart';
import 'package:tph_myleave/models/leave_balance.dart';
import 'package:tph_myleave/models/leave_type.dart';

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

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              'Leave balance ($year)',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            if (onViewAll != null)
              TextButton(onPressed: onViewAll, child: const Text('View all')),
          ],
        ),
        const SizedBox(height: 8),
        if (capped.isEmpty)
          Text(
            'No leave recorded this year yet.',
            style: Theme.of(context).textTheme.bodyMedium,
          )
        else
          ...capped.map((e) => _BalanceRow(entry: e)),
      ],
    );
  }
}

class _BalanceRow extends StatelessWidget {
  const _BalanceRow({required this.entry});

  final LeaveBalanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final remaining = entry.remainingDays;
    final cap = entry.entitlement;
    final fraction = entry.usageFraction ?? 0.0;

    final remainingLabel = entry.isUnlimited
        ? (entry.bookedDays == 0 ? 'Unlimited' : '${entry.bookedDays} day(s) used')
        : '$remaining of $cap day(s) left';

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  entry.type.displayLabel,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ),
              Text(
                remainingLabel,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: remaining == 0 && !entry.isUnlimited
                          ? scheme.error
                          : scheme.primary,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          if (!entry.isUnlimited) ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: fraction,
                minHeight: 6,
                backgroundColor: scheme.surfaceContainerHighest,
              ),
            ),
            const SizedBox(height: 4),
          ],
          Text(
            'Used ${entry.usedDays} · Pending ${entry.pendingDays}',
            style: Theme.of(context).textTheme.bodySmall,
          ),
        ],
      ),
    );
  }
}
