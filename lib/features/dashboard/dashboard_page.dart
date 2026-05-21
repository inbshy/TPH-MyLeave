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

    return Scaffold(
      appBar: AppBar(
        title: Text(AppConstants.dashboardTitle(auth.role)),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            onPressed: () async {
              await ref.read(authProvider.notifier).signOut();
              if (context.mounted) context.go('/login');
            },
            icon: const Icon(Icons.logout),
          ),
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
    final name = ref.watch(authProvider).user?.email ?? 'Account';

    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          UserAccountsDrawerHeader(
            accountName: Text(name),
            accountEmail: Text('Role: $role'),
            currentAccountPicture: const CircleAvatar(
              child: Icon(Icons.person),
            ),
          ),
          ListTile(
            leading: const Icon(Icons.dashboard),
            title: const Text('Home'),
            onTap: () {
              Navigator.pop(context);
              context.go('/dashboard');
            },
          ),
          if (role == AppConstants.roleEmployee) ...[
            ListTile(
              leading: const Icon(Icons.pie_chart_outline),
              title: const Text('Leave balance'),
              onTap: () {
                Navigator.pop(context);
                context.push('/leave-balance');
              },
            ),
            ListTile(
              leading: const Icon(Icons.event_available),
              title: const Text('Apply leave'),
              onTap: () {
                Navigator.pop(context);
                context.push('/apply-leave');
              },
            ),
            ListTile(
              leading: const Icon(Icons.history),
              title: const Text('Leave history'),
              onTap: () {
                Navigator.pop(context);
                context.push('/leave-history');
              },
            ),
          ],
          if (role == AppConstants.roleManager)
            ListTile(
              leading: const Icon(Icons.approval),
              title: const Text('Approvals'),
              onTap: () {
                Navigator.pop(context);
                context.push('/approvals');
              },
            ),
          if (role == AppConstants.roleAdmin) ...[
            ListTile(
              leading: const Icon(Icons.approval),
              title: const Text('Approve leave'),
              onTap: () {
                Navigator.pop(context);
                context.push('/approvals');
              },
            ),
            ListTile(
              leading: const Icon(Icons.business),
              title: const Text('Companies & groups'),
              onTap: () {
                Navigator.pop(context);
                context.push('/company');
              },
            ),
            ListTile(
              leading: const Icon(Icons.people_outline),
              title: const Text('Staff leave balances'),
              onTap: () {
                Navigator.pop(context);
                context.push('/admin/staff-balances');
              },
            ),
          ],
        ],
      ),
    );
  }
}
