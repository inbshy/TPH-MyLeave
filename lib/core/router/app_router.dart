import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/features/approval/approval_details_page.dart';
import 'package:tph_myleave/features/approval/approval_list_page.dart';
import 'package:tph_myleave/features/auth/complete_profile_page.dart';
import 'package:tph_myleave/features/auth/login_page.dart';
import 'package:tph_myleave/features/auth/register_page.dart';
import 'package:tph_myleave/features/admin/admin_staff_balances_page.dart';
import 'package:tph_myleave/features/company/company_page.dart';
import 'package:tph_myleave/features/dashboard/dashboard_page.dart';
import 'package:tph_myleave/features/leave/apply_leave_page.dart';
import 'package:tph_myleave/features/leave/leave_balance_page.dart';
import 'package:tph_myleave/features/leave/leave_details_page.dart';
import 'package:tph_myleave/features/leave/leave_history_page.dart';
import 'package:tph_myleave/providers/auth_provider.dart';

final _rootNavigatorKey = GlobalKey<NavigatorState>();

final appRouterProvider = Provider<GoRouter>((ref) {
  final auth = ref.watch(authProvider);

  return GoRouter(
    navigatorKey: _rootNavigatorKey,
    initialLocation: '/login',
    redirect: (context, state) {
      final loggedIn = auth.user != null;
      final loc = state.matchedLocation;
      final authRoute = loc == '/login' || loc == '/register';
      final profileRoute = loc == '/complete-profile';

      if (!loggedIn && !authRoute) return '/login';
      if (loggedIn && auth.needsProfile && !profileRoute) {
        return '/complete-profile';
      }
      if (loggedIn && !auth.needsProfile && (authRoute || profileRoute)) {
        return '/dashboard';
      }

      final role = auth.role;
      if (loc.startsWith('/company') && role != AppConstants.roleAdmin) {
        return '/dashboard';
      }
      if (loc.startsWith('/admin/staff-balances') &&
          role != AppConstants.roleAdmin) {
        return '/dashboard';
      }
      if (loc.startsWith('/approvals') && !AppConstants.canApproveLeave(role)) {
        return '/dashboard';
      }
      if (!AppConstants.canApplyLeave(role) &&
          (loc == '/apply-leave' ||
              loc == '/leave-history' ||
              loc == '/leave-balance' ||
              loc.startsWith('/leave/'))) {
        return '/dashboard';
      }

      return null;
    },
    routes: [
      GoRoute(
        path: '/login',
        builder: (context, state) => const LoginPage(),
      ),
      GoRoute(
        path: '/register',
        builder: (context, state) => const RegisterPage(),
      ),
      GoRoute(
        path: '/complete-profile',
        builder: (context, state) => const CompleteProfilePage(),
      ),
      GoRoute(
        path: '/dashboard',
        builder: (context, state) => const DashboardPage(),
      ),
      GoRoute(
        path: '/apply-leave',
        builder: (context, state) => const ApplyLeavePage(),
      ),
      GoRoute(
        path: '/leave-history',
        builder: (context, state) => const LeaveHistoryPage(),
      ),
      GoRoute(
        path: '/leave-balance',
        builder: (context, state) => const LeaveBalancePage(),
      ),
      GoRoute(
        path: '/leave/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return LeaveDetailsPage(leaveId: id);
        },
      ),
      GoRoute(
        path: '/approvals',
        builder: (context, state) => const ApprovalListPage(),
      ),
      GoRoute(
        path: '/approvals/:id',
        builder: (context, state) {
          final id = int.parse(state.pathParameters['id']!);
          return ApprovalDetailsPage(leaveId: id);
        },
      ),
      GoRoute(
        path: '/company',
        builder: (context, state) => const CompanyPage(),
      ),
      GoRoute(
        path: '/admin/staff-balances',
        builder: (context, state) => const AdminStaffBalancesPage(),
      ),
    ],
  );
});
