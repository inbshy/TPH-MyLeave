import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/features/company/company_controller.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class CompanyPage extends ConsumerStatefulWidget {
  const CompanyPage({super.key});

  @override
  ConsumerState<CompanyPage> createState() => _CompanyPageState();
}

class _CompanyPageState extends ConsumerState<CompanyPage> {
  final _groupNameController = TextEditingController();
  final _companyNameController = TextEditingController();
  int? _selectedGroupId;
  bool _busy = false;

  @override
  void dispose() {
    _groupNameController.dispose();
    _companyNameController.dispose();
    super.dispose();
  }

  Future<void> _addGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(companyServiceProvider).createCompanyGroup(name);
      ref.invalidate(companyGroupsProvider);
      _groupNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Group company added.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _addCompany() async {
    final name = _companyNameController.text.trim();
    if (name.isEmpty || _selectedGroupId == null) return;
    setState(() => _busy = true);
    try {
      await ref.read(companyServiceProvider).createCompany(
            companyName: name,
            groupId: _selectedGroupId!,
          );
      ref.invalidate(companiesProvider);
      _companyNameController.clear();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Company added.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider);
    final groups = ref.watch(companyGroupsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Companies & groups')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(companiesProvider);
          ref.invalidate(companyGroupsProvider);
          await Future.wait([
            ref.read(companiesProvider.future),
            ref.read(companyGroupsProvider.future),
          ]);
        },
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Add group company',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _groupNameController,
              decoration: const InputDecoration(
                labelText: 'Group name',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 8),
            FilledButton(
              onPressed: _busy ? null : _addGroup,
              child: const Text('Add group'),
            ),
            const SizedBox(height: 24),
            Text(
              'Add company under a group',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            groups.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Text('Create a group first.');
                }
                return Column(
                  children: [
                    DropdownButtonFormField<int>(
                      value: _selectedGroupId,
                      decoration: const InputDecoration(
                        labelText: 'Group company',
                        border: OutlineInputBorder(),
                      ),
                      items: list
                          .map(
                            (g) => DropdownMenuItem(
                              value: g.id,
                              child: Text(g.groupName),
                            ),
                          )
                          .toList(),
                      onChanged: _busy
                          ? null
                          : (v) => setState(() => _selectedGroupId = v),
                    ),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _companyNameController,
                      decoration: const InputDecoration(
                        labelText: 'Company name',
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 8),
                    FilledButton(
                      onPressed: _busy ? null : _addCompany,
                      child: const Text('Add company'),
                    ),
                  ],
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),
            Text(
              'All companies',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            companies.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Text('No companies yet.');
                }
                return Column(
                  children: list
                      .map(
                        (c) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.business),
                            title: Text(c.companyName),
                            subtitle: Text(
                              c.groupName != null
                                  ? 'Group: ${c.groupName}'
                                  : 'Group ID: ${c.groupId ?? '-'}',
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const AppLoadingIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
          ],
        ),
      ),
    );
  }
}
