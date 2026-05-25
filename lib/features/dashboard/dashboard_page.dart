import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/features/dashboard/admin_dashboard.dart';
import 'package:tph_myleave/features/dashboard/employee_dashboard.dart';
import 'package:tph_myleave/features/dashboard/manager_dashboard.dart';
import 'package:tph_myleave/providers/auth_provider.dart';

class DashboardPage extends ConsumerStatefulWidget {
  const DashboardPage({super.key});

  @override
  ConsumerState<DashboardPage> createState() => _DashboardPageState();
}

class _DashboardPageState extends ConsumerState<DashboardPage> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(authProvider.notifier).refreshProfile();
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final role = auth.role ?? AppConstants.roleEmployee;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(
          AppConstants.dashboardTitle(auth.role),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        elevation: 0,
        centerTitle: false,
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout_rounded),
          ),
          const SizedBox(width: 8),
        ],
      ),
      drawer: _DashboardDrawer(role: role),
      body: switch (role) {
        AppConstants.roleAdmin => const AdminDashboard(),
        AppConstants.roleManager => const ManagerDashboard(),
        _ => const EmployeeDashboard(),
      },
    );
  }
}

class _DashboardDrawer extends ConsumerWidget {
  const _DashboardDrawer({required this.role});

  final String role;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final email = auth.user?.email ?? 'user@example.com';
    final name = email.split('@').first;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Drawer(
      child: Column(
        children: [
          // Modern Drawer Header
          UserAccountsDrawerHeader(
            decoration: BoxDecoration(
              color: colorScheme.primary,
            ),
            currentAccountPicture: CircleAvatar(
              backgroundColor: colorScheme.onPrimary,
              child: Icon(
                Icons.person_rounded,
                size: 32,
                color: colorScheme.primary,
              ),
            ),
            accountName: Text(
              name,
              style: theme.textTheme.titleMedium?.copyWith(
                color: colorScheme.onPrimary,
                fontWeight: FontWeight.w600,
              ),
            ),
            accountEmail: Text(
              'Role: $role',
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onPrimary.withOpacity(0.9),
              ),
            ),
          ),

          // Navigation Items
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(vertical: 8),
              children: [
                _buildDrawerItem(
                  context,
                  icon: Icons.dashboard_rounded,
                  title: 'Home',
                  onTap: () {
                    Navigator.pop(context);
                    context.go('/dashboard');
                  },
                ),
                _buildDrawerItem(
                  context,
                  icon: Icons.notifications_rounded,
                  title: 'Notifications',
                  onTap: () {
                    Navigator.pop(context);
                    context.push('/notifications');
                  },
                ),

                const Divider(height: 16),

                // Role-based Menu
                if (role == AppConstants.roleEmployee) ...[
                  _buildSectionTitle(context, 'My Leaves'),
                  _buildDrawerItem(
                    context,
                    icon: Icons.pie_chart_rounded,
                    title: 'Leave Balance',
                    onTap: () => _navigate(context, '/leave-balance'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.add_circle_outline_rounded,
                    title: 'Apply for Leave',
                    onTap: () => _navigate(context, '/apply-leave'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.history_rounded,
                    title: 'Leave History',
                    onTap: () => _navigate(context, '/leave-history'),
                  ),
                ],

                if (role == AppConstants.roleManager) ...[
                  _buildSectionTitle(context, 'Team Management'),
                  _buildDrawerItem(
                    context,
                    icon: Icons.approval_rounded,
                    title: 'Approvals',
                    onTap: () => _navigate(context, '/approvals'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.calendar_month_rounded,
                    title: 'Team Calendar',
                    onTap: () => _navigate(context, '/team-calendar'),
                  ),
                ],

                if (role == AppConstants.roleAdmin) ...[
                  _buildSectionTitle(context, 'Administration'),
                  _buildDrawerItem(
                    context,
                    icon: Icons.pending_actions_rounded,
                    title: 'Approve Leave',
                    onTap: () => _navigate(context, '/approvals'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.business_rounded,
                    title: 'Companies',
                    onTap: () => _navigate(context, '/company'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.badge_rounded,
                    title: 'Employee Directory',
                    onTap: () => _navigate(context, '/admin/employee-directory'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.groups_rounded,
                    title: 'Employee Balances',
                    onTap: () => _navigate(context, '/admin/employee-balances'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.history_rounded,
                    title: 'Approval History',
                    onTap: () => _navigate(context, '/admin/approval-history'),
                  ),
                  _buildDrawerItem(
                    context,
                    icon: Icons.calendar_month_rounded,
                    title: 'Team Calendar',
                    onTap: () => _navigate(context, '/team-calendar'),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerItem(
    BuildContext context, {
    required IconData icon,
    required String title,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon, size: 24),
      title: Text(
        title,
        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
      ),
      onTap: onTap,
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 2),
    );
  }

  Widget _buildSectionTitle(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 4),
      child: Text(
        title.toUpperCase(),
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  void _navigate(BuildContext context, String route) {
    Navigator.pop(context);
    context.push(route);
  }
}