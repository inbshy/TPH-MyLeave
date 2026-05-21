import 'package:flutter/material.dart';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:go_router/go_router.dart';

import 'package:tph_myleave/core/constants/app_constants.dart';

import 'package:tph_myleave/features/company/company_controller.dart';

import 'package:tph_myleave/models/company.dart';

import 'package:tph_myleave/models/company_group.dart';

import 'package:tph_myleave/models/employee_leave_overview.dart';

import 'package:tph_myleave/models/leave_type.dart';

import 'package:tph_myleave/providers/admin_report_provider.dart';

import 'package:tph_myleave/providers/auth_provider.dart';

import 'package:tph_myleave/providers/employee_provider.dart';

import 'package:tph_myleave/features/admin/admin_leave_export.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

final managersProvider =
    FutureProvider<List<({String id, String name, String email})>>((ref) {
  return ref.watch(employeeServiceProvider).fetchManagers();
});



class AdminEmployeeBalancesPage extends ConsumerWidget {

  const AdminEmployeeBalancesPage({super.key});



  @override

  Widget build(BuildContext context, WidgetRef ref) {

    final role = ref.watch(authProvider).role;

    if (role != AppConstants.roleAdmin) {

      WidgetsBinding.instance.addPostFrameCallback((_) {

        if (context.mounted) context.go('/dashboard');

      });

      return const Scaffold(

        body: Center(child: CircularProgressIndicator()),

      );

    }



    final companies = ref.watch(companiesProvider);

    final groups = ref.watch(companyGroupsProvider);

    final selectedGroupId = ref.watch(adminSelectedGroupIdProvider);

    final selectedCompanyId = ref.watch(adminSelectedCompanyIdProvider);

    final overviews = ref.watch(adminEmployeeBalancesProvider);



    return Scaffold(

      appBar: AppBar(
        title: const Text('Employee leave balances'),
        actions: [
          IconButton(
            tooltip: 'Export leave CSV',
            icon: const Icon(Icons.download_outlined),
            onPressed: () => exportAdminLeaveCsv(context, ref),
          ),
        ],
      ),

      body: RefreshIndicator(

        onRefresh: () async {

          ref.invalidate(adminEmployeeBalancesProvider);

          await ref.read(adminEmployeeBalancesProvider.future);

        },

        child: ListView(

          padding: const EdgeInsets.all(16),

          physics: const AlwaysScrollableScrollPhysics(),

          children: [

            Text(

              'Filter employees or change their group / company assignment.',

              style: Theme.of(context).textTheme.bodyMedium,

            ),

            const SizedBox(height: 12),

            groups.when(

              data: (list) => DropdownButtonFormField<int?>(

                key: ValueKey('group-$selectedGroupId'),

                initialValue: selectedGroupId,

                decoration: const InputDecoration(

                  labelText: 'Group',

                  border: OutlineInputBorder(),

                ),

                items: [

                  const DropdownMenuItem<int?>(

                    value: null,

                    child: Text('All groups'),

                  ),

                  ...list.map(

                    (g) => DropdownMenuItem<int?>(

                      value: g.id,

                      child: Text(g.groupName),

                    ),

                  ),

                ],

                onChanged: (v) {

                  ref.read(adminSelectedGroupIdProvider.notifier).state = v;

                  ref.read(adminSelectedCompanyIdProvider.notifier).state =

                      null;

                  ref.invalidate(adminEmployeeBalancesProvider);

                },

              ),

              loading: () => const LinearProgressIndicator(),

              error: (e, _) => Text('Error loading groups: $e'),

            ),

            const SizedBox(height: 12),

            companies.when(

              data: (list) {

                final filtered = selectedGroupId == null

                    ? list

                    : list.where((c) => c.groupId == selectedGroupId).toList();

                return DropdownButtonFormField<int?>(

                  key: ValueKey('company-$selectedCompanyId-$selectedGroupId'),

                  initialValue: selectedCompanyId,

                  decoration: const InputDecoration(

                    labelText: 'Company (optional)',

                    border: OutlineInputBorder(),

                  ),

                  items: [

                    const DropdownMenuItem<int?>(

                      value: null,

                      child: Text('All companies in filter'),

                    ),

                    ...filtered.map(

                      (c) => DropdownMenuItem<int?>(

                        value: c.id,

                        child: Text(c.companyName),

                      ),

                    ),

                  ],

                  onChanged: (v) {

                    ref.read(adminSelectedCompanyIdProvider.notifier).state = v;

                    ref.invalidate(adminEmployeeBalancesProvider);

                  },

                );

              },

              loading: () => const LinearProgressIndicator(),

              error: (e, _) => Text('Error loading companies: $e'),

            ),

            const SizedBox(height: 16),

            overviews.when(

              data: (employees) {

                if (employees.isEmpty) {

                  return const Padding(

                    padding: EdgeInsets.all(24),

                    child: Text('No employees found for this filter.'),

                  );

                }

                final companyList = companies.valueOrNull ?? [];

                final groupList = groups.valueOrNull ?? [];

                return Column(

                  children: employees

                      .map(

                        (e) => _EmployeeBalanceCard(

                          overview: e,

                          companies: companyList,

                          groups: groupList,

                        ),

                      )

                      .toList(),

                );

              },

              loading: () => const AppLoadingIndicator(

                message: 'Loading employee balances…',

              ),

              error: (e, _) => Text('Error: $e'),

            ),

          ],

        ),

      ),

    );

  }

}



class _EmployeeBalanceCard extends ConsumerStatefulWidget {

  const _EmployeeBalanceCard({

    required this.overview,

    required this.companies,

    required this.groups,

  });



  final EmployeeLeaveOverview overview;

  final List<Company> companies;

  final List<CompanyGroup> groups;



  @override

  ConsumerState<_EmployeeBalanceCard> createState() =>

      _EmployeeBalanceCardState();

}



class _EmployeeBalanceCardState extends ConsumerState<_EmployeeBalanceCard> {

  bool _busy = false;



  Future<void> _changeAssignment() async {

    final overview = widget.overview;

    if (widget.groups.isEmpty || widget.companies.isEmpty) {

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Add at least one group and company first.')),

      );

      return;

    }



    var groupId = overview.groupId ?? widget.groups.first.id;

    var companyId = overview.companyId;

    final companiesInGroup = widget.companies

        .where((c) => c.groupId == groupId)

        .toList();

    if (companiesInGroup.isEmpty) {

      companyId = widget.companies.first.id;

      groupId = widget.companies.first.groupId ?? widget.groups.first.id;

    } else if (!companiesInGroup.any((c) => c.id == companyId)) {

      companyId = companiesInGroup.first.id;

    }



    final saved = await showDialog<bool>(

      context: context,

      builder: (ctx) => StatefulBuilder(

        builder: (ctx, setDialogState) {

          final inGroup =

              widget.companies.where((c) => c.groupId == groupId).toList();

          return AlertDialog(

            title: Text('Assign ${overview.name}'),

            content: Column(

              mainAxisSize: MainAxisSize.min,

              crossAxisAlignment: CrossAxisAlignment.stretch,

              children: [

                Text(

                  'Pick the group, then the company under that group.',

                  style: Theme.of(ctx).textTheme.bodySmall,

                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<int>(

                  initialValue: groupId,

                  decoration: const InputDecoration(

                    labelText: 'Group',

                    border: OutlineInputBorder(),

                  ),

                  items: widget.groups

                      .map(

                        (g) => DropdownMenuItem(

                          value: g.id,

                          child: Text(g.groupName),

                        ),

                      )

                      .toList(),

                  onChanged: (v) {

                    if (v == null) return;

                    setDialogState(() {

                      groupId = v;

                      final next = widget.companies

                          .where((c) => c.groupId == groupId)

                          .toList();

                      companyId =

                          next.isNotEmpty ? next.first.id : companyId;

                    });

                  },

                ),

                const SizedBox(height: 12),

                DropdownButtonFormField<int>(

                  initialValue: companyId,

                  decoration: const InputDecoration(

                    labelText: 'Company',

                    border: OutlineInputBorder(),

                  ),

                  items: inGroup

                      .map(

                        (c) => DropdownMenuItem(

                          value: c.id,

                          child: Text(c.companyName),

                        ),

                      )

                      .toList(),

                  onChanged: inGroup.isEmpty

                      ? null

                      : (v) => setDialogState(() => companyId = v!),

                ),

                if (inGroup.isEmpty)

                  Padding(

                    padding: const EdgeInsets.only(top: 8),

                    child: Text(

                      'No companies in this group. Add one under Companies & groups.',

                      style: Theme.of(ctx).textTheme.bodySmall?.copyWith(

                            color: Theme.of(ctx).colorScheme.error,

                          ),

                    ),

                  ),

              ],

            ),

            actions: [

              TextButton(

                onPressed: () => Navigator.pop(ctx, false),

                child: const Text('Cancel'),

              ),

              FilledButton(

                onPressed: inGroup.isEmpty ? null : () => Navigator.pop(ctx, true),

                child: const Text('Save'),

              ),

            ],

          );

        },

      ),

    );



    if (saved != true || !mounted) return;

    if (companyId == overview.companyId) return;



    setState(() => _busy = true);

    try {

      await ref.read(employeeServiceProvider).updateEmployeeCompany(

            employeeId: overview.employeeId,

            companyId: companyId,

          );

      ref.invalidate(adminEmployeeBalancesProvider);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(

        const SnackBar(content: Text('Employee assignment updated.')),

      );

    } catch (e) {

      if (!mounted) return;

      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : '$e';

      ScaffoldMessenger.of(context).showSnackBar(

        SnackBar(content: Text('Could not update assignment: $message')),

      );

    } finally {

      if (mounted) setState(() => _busy = false);

    }

  }

  Future<void> _assignManager() async {
    final overview = widget.overview;
    final managers = await ref.read(managersProvider.future);
    String? managerId;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('Manager for ${overview.name}'),
          content: DropdownButtonFormField<String?>(
            initialValue: managerId,
            decoration: const InputDecoration(
              labelText: 'Reporting manager',
              border: OutlineInputBorder(),
            ),
            items: [
              const DropdownMenuItem<String?>(
                value: null,
                child: Text('None (same-company fallback)'),
              ),
              ...managers.map(
                (m) => DropdownMenuItem<String?>(
                  value: m.id,
                  child: Text('${m.name} (${m.email})'),
                ),
              ),
            ],
            onChanged: (v) => setDialogState(() => managerId = v),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) return;

    setState(() => _busy = true);
    try {
      await ref.read(employeeServiceProvider).assignManager(
            employeeId: overview.employeeId,
            managerUserId: managerId,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Manager assignment updated.')),
      );
    } catch (e) {
      if (!mounted) return;
      final message = e is Exception
          ? e.toString().replaceFirst('Exception: ', '')
          : '$e';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not assign manager: $message')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override

  Widget build(BuildContext context) {

    final overview = widget.overview;

    final capped = overview.balances.where((b) => !b.isUnlimited).toList();



    return Card(

      margin: const EdgeInsets.only(bottom: 12),

      child: ExpansionTile(

        title: Text(overview.name),

        subtitle: Text(

          '${overview.companyName}'

          '${overview.groupName != null ? ' · ${overview.groupName}' : ''}',

        ),

        trailing: _busy
            ? const SizedBox(
                width: 40,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: 'Assign manager',
                    icon: const Icon(Icons.supervisor_account_outlined),
                    onPressed: _assignManager,
                  ),
                  IconButton(
                    tooltip: 'Change group / company',
                    icon: const Icon(Icons.edit_outlined),
                    onPressed: _changeAssignment,
                  ),
                ],
              ),

        children: [

          Padding(

            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),

            child: Column(

              crossAxisAlignment: CrossAxisAlignment.start,

              children: [

                Text('Email: ${overview.email}',

                    style: Theme.of(context).textTheme.bodySmall),

                const SizedBox(height: 8),

                ...capped.map((b) {

                  final remaining = b.remainingDays ?? 0;

                  final cap = b.entitlement ?? 0;

                  return Padding(

                    padding: const EdgeInsets.symmetric(vertical: 4),

                    child: Row(

                      children: [

                        Expanded(

                          child: Text(b.type.displayLabel),

                        ),

                        Text(

                          '$remaining / $cap left',

                          style: TextStyle(

                            fontWeight: FontWeight.w600,

                            color: remaining == 0

                                ? Theme.of(context).colorScheme.error

                                : Theme.of(context).colorScheme.primary,

                          ),

                        ),

                      ],

                    ),

                  );

                }),

                if (overview.balances

                    .any((b) => b.type == LeaveType.unpaid)) ...[

                  const SizedBox(height: 4),

                  Text(

                    'Unpaid: ${overview.balances.firstWhere((b) => b.type == LeaveType.unpaid).bookedDays} day(s) used',

                    style: Theme.of(context).textTheme.bodySmall,

                  ),

                ],

              ],

            ),

          ),

        ],

      ),

    );

  }

}

