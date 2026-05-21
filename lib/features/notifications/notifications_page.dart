import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:tph_myleave/providers/notification_provider.dart';
import 'package:tph_myleave/widgets/loading_indicator.dart';

class NotificationsPage extends ConsumerWidget {
  const NotificationsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(myNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifications')),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(myNotificationsProvider);
          await ref.read(myNotificationsProvider.future);
        },
        child: async.when(
          data: (list) {
            if (list.isEmpty) {
              return ListView(
                children: const [
                  SizedBox(height: 48),
                  Center(child: Text('No notifications yet.')),
                ],
              );
            }
            return ListView.builder(
              itemCount: list.length,
              itemBuilder: (context, i) {
                final n = list[i];
                return ListTile(
                  leading: Icon(
                    n.isRead ? Icons.notifications_none : Icons.notifications_active,
                  ),
                  title: Text(n.title),
                  subtitle: Text(n.body),
                  onTap: () async {
                    if (!n.isRead) {
                      await ref
                          .read(notificationServiceProvider)
                          .markRead(n.id);
                      ref.invalidate(myNotificationsProvider);
                    }
                    if (n.leaveId != null && context.mounted) {
                      context.push('/leave/${n.leaveId}');
                    }
                  },
                );
              },
            );
          },
          loading: () => const AppLoadingIndicator(),
          error: (e, _) => Center(child: Text('Error: $e')),
        ),
      ),
    );
  }
}
