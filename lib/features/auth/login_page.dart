import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/features/auth/auth_controller.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/widgets/primary_button.dart';

class LoginPage extends ConsumerStatefulWidget {
  const LoginPage({super.key});

  @override
  ConsumerState<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends ConsumerState<LoginPage> {
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (!_formKey.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    await ref.read(authProvider.notifier).signIn(
          email: _emailController.text,
          password: _passwordController.text,
        );
  }

  void _goAfterLogin(AuthState auth) {
    if (auth.hasProfile) context.go('/dashboard');
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);

    ref.listen<AuthState>(authProvider, (prev, next) {
      if (prev?.isLoading != true || next.isLoading) return;
      if (!mounted) return;
      if (next.error != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(next.error!),
            duration: const Duration(seconds: 6),
          ),
        );
        return;
      }
      if (next.user != null) _goAfterLogin(next);
    });

    return Scaffold(
      appBar: AppBar(title: const Text('Login')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  if (auth.error != null && !auth.isLoading)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        auth.error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  TextFormField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    enabled: !auth.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Email',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final s = v?.trim() ?? '';
                      if (s.isEmpty) return 'Enter your email';
                      if (!s.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _passwordController,
                    obscureText: true,
                    enabled: !auth.isLoading,
                    decoration: const InputDecoration(
                      labelText: 'Password',
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if (v == null || v.isEmpty) return 'Enter your password';
                      return null;
                    },
                    onFieldSubmitted: auth.isLoading ? null : (_) => _login(),
                  ),
                  const SizedBox(height: 24),
                  PrimaryButton(
                    label: auth.isLoading ? 'Signing in…' : 'Login',
                    onPressed: auth.isLoading ? null : _login,
                  ),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerRight,
                    child: TextButton(
                      onPressed: auth.isLoading
                          ? null
                          : () async {
                              final email = _emailController.text.trim();
                              if (email.isEmpty || !email.contains('@')) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Enter your email first.'),
                                  ),
                                );
                                return;
                              }
                              try {
                                await ref
                                    .read(authServiceProvider)
                                    .resetPasswordForEmail(email);
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Password reset link sent to $email',
                                    ),
                                  ),
                                );
                              } catch (e) {
                                if (!context.mounted) return;
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(content: Text('Reset failed: $e')),
                                );
                              }
                            },
                      child: const Text('Forgot password?'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextButton(
                    onPressed: auth.isLoading ? null : () => context.push('/register'),
                    child: const Text('Register employee'),
                  ),
                ],
              ),
            ),
          ),
          if (auth.isLoading)
            const ColoredBox(
              color: Color(0x33000000),
              child: Center(child: CircularProgressIndicator()),
            ),
        ],
      ),
    );
  }
}
