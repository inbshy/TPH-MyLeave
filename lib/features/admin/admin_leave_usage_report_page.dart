import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/features/company/company_controller.dart';
import 'package:tph_myleave/providers/admin_service_provider.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class AdminLeaveUsageReportPage extends ConsumerWidget {
  const AdminLeaveUsageReportPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).role;
    if (role != AppConstants.roleAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final report = ref.watch(leaveUsageReportProvider);
    final companies = ref.watch(companiesProvider);
    final year = ref.watch(usageReportYearProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leave usage report')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: DropdownButtonFormField<int>(
                    initialValue: year,
                    decoration: const InputDecoration(
                      labelText: 'Year',
                      border: OutlineInputBorder(),
                    ),
                    items: List.generate(
                      5,
                      (i) => DateTime.now().year - i,
                    )
                        .map(
                          (y) => DropdownMenuItem(value: y, child: Text('$y')),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v != null) {
                        ref.read(usageReportYearProvider.notifier).state = v;
                        ref.invalidate(leaveUsageReportProvider);
                      }
                    },
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: companies.when(
                    data: (list) => DropdownButtonFormField<int?>(
                      initialValue: ref.watch(usageReportCompanyProvider),
                      decoration: const InputDecoration(
                        labelText: 'Company',
                        border: OutlineInputBorder(),
                      ),
                      items: [
                        const DropdownMenuItem(
                          value: null,
                          child: Text('All'),
                        ),
                        ...list.map(
                          (c) => DropdownMenuItem(
                            value: c.id,
                            child: Text(c.companyName),
                          ),
                        ),
                      ],
                      onChanged: (v) {
                        ref.read(usageReportCompanyProvider.notifier).state = v;
                        ref.invalidate(leaveUsageReportProvider);
                      },
                    ),
                    loading: () => const LinearProgressIndicator(),
                    error: (_, __) => const SizedBox.shrink(),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: report.when(
              data: (rows) {
                if (rows.isEmpty) {
                  return const Center(
                    child: Text('No approved leave usage for this filter.'),
                  );
                }
                var totalDays = 0;
                for (final r in rows) {
                  totalDays += r.totalDays;
                }
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    Card(
                      child: ListTile(
                        title: const Text('Total approved days'),
                        trailing: Text(
                          '$totalDays',
                          style: Theme.of(context).textTheme.headlineSmall,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    ...rows.map(
                      (r) => Card(
                        child: ListTile(
                          title: Text(r.employeeName),
                          subtitle: Text('${r.companyName} · ${r.leaveType}'),
                          trailing: Text(
                            '${r.totalDays} d\n(${r.requestCount} req)',
                            textAlign: TextAlign.end,
                          ),
                        ),
                      ),
                    ),
                  ],
                );
              },
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),
        ],
      ),
    );
  }
}
