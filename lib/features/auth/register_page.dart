import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tph_myleave/features/company/company_controller.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/services/auth_service.dart';

class RegisterPage extends ConsumerStatefulWidget {
  const RegisterPage({super.key});

  @override
  ConsumerState<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends ConsumerState<RegisterPage> {
  final SupabaseClient _supabase = Supabase.instance.client;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _submitting = false;
  int? _selectedCompanyId;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_selectedCompanyId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a company')),
      );
      return;
    }

    setState(() => _submitting = true);

    try {
      final response = await _supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );

      if (response.user == null) {
        throw Exception('Registration failed.');
      }

      final userId = response.user!.id;
      final email = _emailController.text.trim();
      final name = _nameController.text.trim();

      // RLS only allows inserts when the user has an active session.
      if (response.session == null) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Account created. Confirm your email, then sign in '
              'to finish your profile.',
            ),
            duration: Duration(seconds: 6),
          ),
        );
        context.go('/login');
        return;
      }

      final auth = ref.read(authServiceProvider);
      await auth.createEmployeeProfile(
        userId: userId,
        name: name,
        email: email,
        companyId: _selectedCompanyId!,
      );

      await ref.read(authProvider.notifier).signOut();

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Registration successful. You can sign in now.',
          ),
        ),
      );
      context.go('/login');
    } catch (e) {
      if (!mounted) return;
      final message = e.toString();
      final hint = message.contains('row-level security') ||
              message.contains('employee_id_seq')
          ? '\n\nTip: run supabase/migrations/20260115120000_employee_id_sequence.sql '
              'in the SQL Editor, or disable “Confirm email” under Auth → Providers.'
          : '';
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $message$hint')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final companies = ref.watch(companiesProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Register employee')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: companies.when(
          data: (list) {
            if (list.isEmpty) {
              return const Center(
                child: Text(
                  'No companies available. Run initial_schema.sql or insert a row in the company table.',
                ),
              );
            }
            return ListView(
              children: [
                TextField(
                  controller: _nameController,
                  decoration: const InputDecoration(
                    labelText: 'Name',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _emailController,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(
                    labelText: 'Email',
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
                const SizedBox(height: 12),
                TextField(
                  controller: _passwordController,
                  obscureText: true,
                  decoration: const InputDecoration(
                    labelText: 'Password',
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _submitting ? null : _register,
                  child: Text(_submitting ? 'Please wait…' : 'Register'),
                ),
                TextButton(
                  onPressed: _submitting ? null : () => context.go('/login'),
                  child: const Text('Back to login'),
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
