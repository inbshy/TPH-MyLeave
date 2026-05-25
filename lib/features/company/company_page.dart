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
      _showSnackBar('Group added successfully');
    } catch (e) {
      _showSnackBar('Error: $e');
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
      _showSnackBar('Company added successfully');
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _editGroup(CompanyGroup group) async {
    final controller = TextEditingController(text: group.groupName);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Edit Group'),
        content: TextField(
          controller: controller,
          decoration: InputDecoration(
            labelText: 'Group Name',
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
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
      _showSnackBar('Group updated');
    } catch (e) {
      _showSnackBar('Error: $e');
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
          title: const Text('Edit Company'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameController,
                decoration: InputDecoration(
                  labelText: 'Company Name',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<int>(
                value: groupId,
                decoration: InputDecoration(
                  labelText: 'Group',
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
                items: groups
                    .map((g) => DropdownMenuItem(value: g.id, child: Text(g.groupName)))
                    .toList(),
                onChanged: (v) => setDialogState(() => groupId = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
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
      _showSnackBar('Company updated');
    } catch (e) {
      _showSnackBar('Error: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider);
    final groups = ref.watch(companyGroupsProvider);
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Companies & Groups'),
        elevation: 0,
      ),
      body: RefreshIndicator(
        onRefresh: _refreshLists,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 40),
          children: [
            // ==================== ADD GROUP ====================
            _SectionCard(
              title: 'Add New Group',
              icon: Icons.folder_outlined,
              child: Column(
                children: [
                  TextField(
                    controller: _groupNameController,
                    enabled: !_busy,
                    decoration: InputDecoration(
                      labelText: 'Group Name',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.folder_outlined),
                    ),
                  ),
                  const SizedBox(height: 16),
                  FilledButton.icon(
                    onPressed: _busy ? null : _addGroup,
                    icon: const Icon(Icons.add),
                    label: const Text('Add Group'),
                    style: FilledButton.styleFrom(
                      minimumSize: const Size(double.infinity, 50),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            // ==================== GROUPS LIST ====================
            _SectionHeader(title: 'Groups', icon: Icons.folder_outlined),
            const SizedBox(height: 12),
            groups.when(
              data: (list) {
                if (list.isEmpty) {
                  return _EmptyState(message: 'No groups yet. Create your first group above.');
                }
                return Column(
                  children: list.map((g) => _GroupCard(
                    group: g,
                    onEdit: () => _editGroup(g),
                    busy: _busy,
                  )).toList(),
                );
              },
              loading: () => const LinearProgressIndicator(),
              error: (e, _) => Text('Error: $e'),
            ),

            const SizedBox(height: 32),

            // ==================== ADD COMPANY ====================
            _SectionCard(
              title: 'Add New Company',
              icon: Icons.business_outlined,
              child: groups.when(
                data: (list) {
                  if (list.isEmpty) {
                    return const Text('Please create a group first before adding a company.');
                  }
                  return Column(
                    children: [
                      DropdownButtonFormField<int>(
                        value: _selectedGroupId,
                        decoration: InputDecoration(
                          labelText: 'Select Group',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.folder_outlined),
                        ),
                        items: list
                            .map((g) => DropdownMenuItem(value: g.id, child: Text(g.groupName)))
                            .toList(),
                        onChanged: _busy ? null : (v) => setState(() => _selectedGroupId = v),
                      ),
                      const SizedBox(height: 16),
                      TextField(
                        controller: _companyNameController,
                        enabled: !_busy,
                        decoration: InputDecoration(
                          labelText: 'Company Name',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                          prefixIcon: const Icon(Icons.business_outlined),
                        ),
                      ),
                      const SizedBox(height: 16),
                      FilledButton.icon(
                        onPressed: _busy ? null : _addCompany,
                        icon: const Icon(Icons.add),
                        label: const Text('Add Company'),
                        style: FilledButton.styleFrom(
                          minimumSize: const Size(double.infinity, 50),
                        ),
                      ),
                    ],
                  );
                },
                loading: () => const LinearProgressIndicator(),
                error: (e, _) => Text('Error: $e'),
              ),
            ),

            const SizedBox(height: 32),

            // ==================== COMPANIES LIST ====================
            _SectionHeader(title: 'All Companies', icon: Icons.business_outlined),
            const SizedBox(height: 12),
            companies.when(
              data: (list) {
                final groupList = groups.valueOrNull ?? [];
                if (list.isEmpty) {
                  return _EmptyState(message: 'No companies yet.');
                }
                return Column(
                  children: list.map((c) => _CompanyCard(
                    company: c,
                    onEdit: () => _editCompany(c, groupList),
                    busy: _busy || groupList.isEmpty,
                  )).toList(),
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

// ==================== HELPER WIDGETS ====================

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.title, required this.icon});

  final String title;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, color: Theme.of(context).colorScheme.primary),
        const SizedBox(width: 10),
        Text(
          title,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.w600,
              ),
        ),
      ],
    );
  }
}

class _SectionCard extends StatelessWidget {
  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
  });

  final String title;
  final IconData icon;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                ),
              ],
            ),
            const SizedBox(height: 20),
            child,
          ],
        ),
      ),
    );
  }
}

class _GroupCard extends StatelessWidget {
  const _GroupCard({
    required this.group,
    required this.onEdit,
    required this.busy,
  });

  final CompanyGroup group;
  final VoidCallback onEdit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        leading: const Icon(Icons.folder_outlined),
        title: Text(group.groupName, style: const TextStyle(fontWeight: FontWeight.w600)),
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: busy ? null : onEdit,
        ),
      ),
    );
  }
}

class _CompanyCard extends StatelessWidget {
  const _CompanyCard({
    required this.company,
    required this.onEdit,
    required this.busy,
  });

  final Company company;
  final VoidCallback onEdit;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        leading: const Icon(Icons.business),
        title: Text(company.companyName, style: const TextStyle(fontWeight: FontWeight.w600)),
        subtitle: company.groupName != null
            ? Text('Group: ${company.groupName}')
            : null,
        trailing: IconButton(
          icon: const Icon(Icons.edit_outlined),
          onPressed: busy ? null : onEdit,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline, color: Theme.of(context).colorScheme.primary),
          const SizedBox(width: 16),
          Expanded(child: Text(message)),
        ],
      ),
    );
  }
}