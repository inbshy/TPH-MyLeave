import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/features/company/company_controller.dart';
import 'package:tph_myleave/models/leave_balance.dart';
import 'package:tph_myleave/providers/admin_staff_balances_provider.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class AdminStaffBalancesPage extends ConsumerStatefulWidget {
  const AdminStaffBalancesPage({super.key});

  @override
  ConsumerState<AdminStaffBalancesPage> createState() =>
      _AdminStaffBalancesPageState();
}

class _AdminStaffBalancesPageState extends ConsumerState<AdminStaffBalancesPage> {
  int? _companyId;

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    if (role != AppConstants.roleAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final companies = ref.watch(companiesProvider);
    final balancesAsync = _companyId == null
        ? null
        : ref.watch(adminStaffBalancesProvider(_companyId!));

    return Scaffold(
      appBar: AppBar(title: const Text('Staff leave balances')),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: companies.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Text('No companies. Add companies first.');
                }
                return DropdownButtonFormField<int>(
                  value: _companyId,
                  decoration: const InputDecoration(
                    labelText: 'Select company',
                    border: OutlineInputBorder(),
                  ),
                  items: list
                      .map(
                        (c) => DropdownMenuItem(
                          value: c.id,
                          child: Text(
                            c.groupName != null
                                ? '${c.companyName} (${c.groupName})'
                                : c.companyName,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _companyId = v),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
          ),
          Expanded(
            child: _companyId == null
                ? const Center(child: Text('Select a company to view balances.'))
                : balancesAsync!.when(
                    data: (summaries) {
                      if (summaries.isEmpty) {
                        return const Center(
                          child: Text('No employees in this company.'),
                        );
                      }
                      return ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                        itemCount: summaries.length,
                        itemBuilder: (context, i) {
                          final s = summaries[i];
                          return Card(
                            margin: const EdgeInsets.only(bottom: 12),
                            child: ExpansionTile(
                              title: Text(s.name),
                              subtitle: Text('ID: ${s.employeeId}'),
                              children: s.balances
                                  .where((b) => !b.isUnlimited || b.bookedDays > 0)
                                  .map((b) => _BalanceLine(entry: b))
                                  .toList(),
                            ),
                          );
                        },
                      );
                    },
                    loading: () => const AppLoadingIndicator(
                      message: 'Loading staff balances…',
                    ),
                    error: (e, _) => Center(child: Text('Error: $e')),
                  ),
          ),
        ],
      ),
    );
  }
}

class _BalanceLine extends StatelessWidget {
  const _BalanceLine({required this.entry});

  final LeaveBalanceEntry entry;

  @override
  Widget build(BuildContext context) {
    final remaining = entry.remainingDays;
    final label = entry.isUnlimited
        ? '${entry.type.displayLabel}: ${entry.bookedDays} day(s) used (no cap)'
        : '${entry.type.displayLabel}: $remaining of ${entry.entitlement} left '
            '(used ${entry.usedDays}, pending ${entry.pendingDays})';

    return ListTile(
      dense: true,
      title: Text(label, style: Theme.of(context).textTheme.bodySmall),
    );
  }
}
