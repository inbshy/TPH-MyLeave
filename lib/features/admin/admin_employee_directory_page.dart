import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/features/company/company_controller.dart';
import 'package:tph_myleave/models/staff_directory_entry.dart';
import 'package:tph_myleave/providers/admin_service_provider.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class AdminEmployeeDirectoryPage extends ConsumerStatefulWidget {
  const AdminEmployeeDirectoryPage({super.key});

  @override
  ConsumerState<AdminEmployeeDirectoryPage> createState() =>
      _AdminEmployeeDirectoryPageState();
}

class _AdminEmployeeDirectoryPageState
    extends ConsumerState<AdminEmployeeDirectoryPage> {
  final _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final role = ref.watch(authProvider).role;
    if (role != AppConstants.roleAdmin) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final staff = ref.watch(staffDirectoryProvider);
    final companies = ref.watch(companiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Employee directory')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    labelText: 'Search name or email',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.search),
                      onPressed: () {
                        ref.read(staffDirectorySearchProvider.notifier).state =
                            _searchController.text;
                        ref.invalidate(staffDirectoryProvider);
                      },
                    ),
                  ),
                  onSubmitted: (v) {
                    ref.read(staffDirectorySearchProvider.notifier).state = v;
                    ref.invalidate(staffDirectoryProvider);
                  },
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<String?>(
                        initialValue: ref.watch(staffDirectoryRoleFilterProvider),
                        decoration: const InputDecoration(
                          labelText: 'Role',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(value: null, child: Text('All roles')),
                          DropdownMenuItem(
                            value: AppConstants.roleEmployee,
                            child: Text('Employee'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.roleManager,
                            child: Text('Manager'),
                          ),
                          DropdownMenuItem(
                            value: AppConstants.roleAdmin,
                            child: Text('Admin'),
                          ),
                        ],
                        onChanged: (v) {
                          ref.read(staffDirectoryRoleFilterProvider.notifier).state = v;
                          ref.invalidate(staffDirectoryProvider);
                        },
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: companies.when(
                        data: (list) => DropdownButtonFormField<int?>(
                          initialValue:
                              ref.watch(staffDirectoryCompanyFilterProvider),
                          decoration: const InputDecoration(
                            labelText: 'Company',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem(
                              value: null,
                              child: Text('All'),
                            ),
                            ...list.map(
                              (c) => DropdownMenuItem(
                                value: c.id,
                                child: Text(c.companyName, overflow: TextOverflow.ellipsis),
                              ),
                            ),
                          ],
                          onChanged: (v) {
                            ref.read(staffDirectoryCompanyFilterProvider.notifier).state = v;
                            ref.invalidate(staffDirectoryProvider);
                          },
                        ),
                        loading: () => const LinearProgressIndicator(),
                        error: (_, __) => const SizedBox.shrink(),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: staff.when(
              data: (list) {
                if (list.isEmpty) {
                  return const Center(child: Text('No staff found.'));
                }
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(staffDirectoryProvider);
                    await ref.read(staffDirectoryProvider.future);
                  },
                  child: ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (_, i) => _StaffTile(entry: list[i]),
                  ),
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

class _StaffTile extends ConsumerWidget {
  const _StaffTile({required this.entry});

  final StaffDirectoryEntry entry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: ListTile(
        title: Text(entry.name),
        subtitle: Text(
          '${entry.email}\n'
          '${entry.role} · ${entry.companyName}'
          '${entry.groupName != null ? ' · ${entry.groupName}' : ''}'
          '${entry.managerName != null ? '\nManager: ${entry.managerName}' : ''}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.chevron_right),
        onTap: () => _showEditSheet(context, ref),
      ),
    );
  }

  Future<void> _showEditSheet(BuildContext context, WidgetRef ref) async {
    final nameCtrl = TextEditingController(text: entry.name);
    final emailCtrl = TextEditingController(text: entry.email);
    var role = entry.role;
    var staffType = entry.staffType;
    final companies = await ref.read(companiesProvider.future);
    var companyId = entry.companyId;

    if (!context.mounted) return;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: StatefulBuilder(
          builder: (ctx, setLocal) => Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Edit ${entry.name}',
                  style: Theme.of(ctx).textTheme.titleLarge),
              const SizedBox(height: 16),
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Name',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: emailCtrl,
                decoration: const InputDecoration(
                  labelText: 'Email',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: role,
                decoration: const InputDecoration(
                  labelText: 'Role',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(
                    value: AppConstants.roleEmployee,
                    child: Text('Employee'),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.roleManager,
                    child: Text('Manager'),
                  ),
                  DropdownMenuItem(
                    value: AppConstants.roleAdmin,
                    child: Text('Admin'),
                  ),
                ],
                onChanged: (v) => setLocal(() => role = v ?? role),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: staffType,
                decoration: const InputDecoration(
                  labelText: 'Staff type',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'permanent', child: Text('Permanent')),
                  DropdownMenuItem(value: 'contract', child: Text('Contract')),
                ],
                onChanged: (v) => setLocal(() => staffType = v ?? staffType),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                initialValue: companyId,
                decoration: const InputDecoration(
                  labelText: 'Company',
                  border: OutlineInputBorder(),
                ),
                items: companies
                    .map(
                      (c) => DropdownMenuItem(
                        value: c.id,
                        child: Text(c.companyName),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setLocal(() => companyId = v ?? companyId),
              ),
              const SizedBox(height: 16),
              FilledButton(
                onPressed: () async {
                  try {
                    await ref.read(adminServiceProvider).updateUserProfile(
                          userId: entry.userId,
                          name: nameCtrl.text,
                          email: emailCtrl.text,
                          staffType: staffType,
                          companyId: companyId,
                        );
                    if (role != entry.role) {
                      await ref.read(adminServiceProvider).changeUserRole(
                            userId: entry.userId,
                            role: role,
                          );
                    }
                    ref.invalidate(staffDirectoryProvider);
                    if (ctx.mounted) Navigator.pop(ctx);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Profile updated.')),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      final msg = e is Exception
                          ? e.toString().replaceFirst('Exception: ', '')
                          : e.toString();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Update failed: $msg')),
                      );
                    }
                  }
                },
                child: const Text('Save profile'),
              ),
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () async {
                  try {
                    await ref
                        .read(adminServiceProvider)
                        .sendPasswordResetEmail(emailCtrl.text);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            'Password reset email sent to ${emailCtrl.text}',
                          ),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Reset failed: $e')),
                      );
                    }
                  }
                },
                icon: const Icon(Icons.lock_reset),
                label: const Text('Send password reset email'),
              ),
            ],
          ),
        ),
      ),
    );

    nameCtrl.dispose();
    emailCtrl.dispose();
  }
}
