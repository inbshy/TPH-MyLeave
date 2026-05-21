import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/features/company/company_controller.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/widgets/primary_button.dart';

class CompleteProfilePage extends ConsumerStatefulWidget {
  const CompleteProfilePage({super.key});

  @override
  ConsumerState<CompleteProfilePage> createState() =>
      _CompleteProfilePageState();
}

class _CompleteProfilePageState extends ConsumerState<CompleteProfilePage> {
  final _nameController = TextEditingController();
  bool _submitting = false;
  int? _selectedCompanyId;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a company')),
      );
      return;
    }

    final name = _nameController.text.trim();
    if (name.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter your name')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      await ref.read(authProvider.notifier).completeEmployeeProfile(
            name: name,
            companyId: _selectedCompanyId!,
          );

      final err = ref.read(authProvider).error;
      if (!mounted) return;

      if (err != null) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(err)));
        return;
      }

      context.go('/dashboard');
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    final companies = ref.watch(companiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Finish registration')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: companies.when(
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'No companies in the database. Ask an admin to add a company in Supabase.',
                ),
              );
            }
            return ListView(
              children: [
                Text(
                  'Your account exists, but your employee profile was not saved yet. '
                  'This usually happens when email confirmation is required. '
                  'Complete the form below.',
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
                const SizedBox(height: 16),
                TextField(
                  readOnly: true,
                  controller: TextEditingController(text: user?.email ?? ''),
                  decoration: const InputDecoration(
                    labelText: 'Email',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Full name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                InputDecorator(
                  decoration: const InputDecoration(
                    labelText: 'Company',
                    border: OutlineInputBorder(),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int>(
                      isExpanded: true,
                      hint: const Text('Select company'),
                      value: _selectedCompanyId,
                      items: list
                          .map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.companyName),
                            ),
                          )
                          .toList(),
                      onChanged: _submitting
                          ? null
                          : (v) => setState(() => _selectedCompanyId = v),
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                PrimaryButton(
                  label: _submitting ? 'Saving…' : 'Save profile',
                  onPressed: _submitting ? null : _save,
                ),
              ],
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
