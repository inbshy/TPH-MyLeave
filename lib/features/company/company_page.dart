import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/features/company/company_controller.dart';
import 'package:tph_myleave/models/company.dart';
import 'package:tph_myleave/models/company_group.dart';
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

  void _showError(Object e) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
  }

  void _showSuccess(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _refreshLists() async {
    ref.invalidate(companiesProvider);
    ref.invalidate(companyGroupsProvider);
    await Future.wait([
      ref.read(companiesProvider.future),
      ref.read(companyGroupsProvider.future),
    ]);
  }

  Future<void> _addGroup() async {
    final name = _groupNameController.text.trim();
    if (name.isEmpty) return;
    setState(() => _busy = true);
    try {
      await ref.read(companyServiceProvider).createCompanyGroup(name);
      await _refreshLists();
      _groupNameController.clear();
      _showSuccess('Group added.');
    } catch (e) {
      _showError(e);
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
      await _refreshLists();
      _companyNameController.clear();
      _showSuccess('Company added.');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editGroup(CompanyGroup group) async {
    final controller = TextEditingController(text: group.groupName);
    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit group'),
        content: TextField(
          controller: controller,
          decoration: const InputDecoration(
            labelText: 'Group name',
            border: OutlineInputBorder(),
          ),
          autofocus: true,
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
    );
    if (saved != true || !mounted) {
      controller.dispose();
      return;
    }

    final name = controller.text.trim();
    controller.dispose();
    if (name.isEmpty) return;

    setState(() => _busy = true);
    try {
      await ref.read(companyServiceProvider).updateCompanyGroup(
            groupId: group.id,
            groupName: name,
          );
      await _refreshLists();
      _showSuccess('Group updated.');
    } catch (e) {
      _showError(e);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editCompany(Company company, List<CompanyGroup> groups) async {
    final nameController = TextEditingController(text: company.companyName);
    var groupId = company.groupId ?? groups.firstOrNull?.id;

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Edit company'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: const InputDecoration(
                  labelText: 'Company name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: groupId,
                decoration: const InputDecoration(
                  labelText: 'Group',
                  border: OutlineInputBorder(),
                ),
                items: groups
                    .map(
                      (g) => DropdownMenuItem(
                        value: g.id,
                        child: Text(g.groupName),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setDialogState(() => groupId = v),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: groupId == null ? null : () => Navigator.pop(ctx, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );

    if (saved != true || !mounted) {
      nameController.dispose();
      return;
    }

    final name = nameController.text.trim();
    nameController.dispose();
    final resolvedGroupId = groupId;
    if (name.isEmpty || resolvedGroupId == null) return;

    setState(() => _busy = true);
    try {
      await ref.read(companyServiceProvider).updateCompany(
            companyId: company.id,
            companyName: name,
            groupId: resolvedGroupId,
          );
      await _refreshLists();
      _showSuccess('Company updated.');
    } catch (e) {
      _showError(e);
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
        onRefresh: _refreshLists,
        child: ListView(
          padding: const EdgeInsets.all(16),
          physics: const AlwaysScrollableScrollPhysics(),
          children: [
            Text(
              'Add group',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _groupNameController,
              enabled: !_busy,
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
              'All groups',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            groups.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Text('No groups yet.');
                }
                return Column(
                  children: list
                      .map(
                        (g) => Card(
                          child: ListTile(
                            leading: const Icon(Icons.folder_outlined),
                            title: Text(g.groupName),
                            trailing: IconButton(
                              tooltip: 'Edit group',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: _busy ? null : () => _editGroup(g),
                            ),
                          ),
                        ),
                      )
                      .toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),
            const SizedBox(height: 24),
            Text(
              'Add company',
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
                      key: ValueKey(_selectedGroupId),
                      initialValue: _selectedGroupId,
                      decoration: const InputDecoration(
                        labelText: 'Group',
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
                      enabled: !_busy,
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
                final groupList = groups.valueOrNull ?? [];
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
                            trailing: IconButton(
                              tooltip: 'Edit company',
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: groupList.isEmpty || _busy
                                  ? null
                                  : () => _editCompany(c, groupList),
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
