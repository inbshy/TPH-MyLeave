import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';
import 'package:tph_myleave/providers/auth_provider.dart';
import 'package:tph_myleave/providers/leave_provider.dart';
import 'package:tph_myleave/widgets/leave_card.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class LeaveHistoryPage extends ConsumerWidget {
  const LeaveHistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final role = ref.watch(authProvider).role;
    if (!AppConstants.canApplyLeave(role)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted) context.go('/dashboard');
      });
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final async = ref.watch(myLeaveRequestsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Leave history')),
      body: async.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Text('No leave requests yet.'),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, i) {
              final r = list[i];
              return LeaveCard(
                request: r,
                onTap: r.id != null
                    ? () => context.push('/leave/${r.id}')
                    : null,
              );
            },
          );
        },
        loading: () => const AppLoadingIndicator(message: 'Loading your requests…'),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
