import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/features/auth/auth_controller.dart';
import 'package:tph_myleave/providers/auth_provider.dart';

/// Notifies [GoRouter] when auth changes without recreating the router instance.
class RouterRefresh extends ChangeNotifier {
  RouterRefresh(Ref ref) {
    ref.listen<AuthState>(authProvider, (_, _) => notifyListeners());
  }
}

final routerRefreshProvider = Provider<RouterRefresh>((ref) {
  final refresh = RouterRefresh(ref);
  ref.onDispose(refresh.dispose);
  return refresh;
});
