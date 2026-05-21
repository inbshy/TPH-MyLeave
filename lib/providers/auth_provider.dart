import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:tph_myleave/features/auth/auth_controller.dart';
import 'package:tph_myleave/services/auth_service.dart';

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final authProvider =
    StateNotifierProvider<AuthController, AuthState>((ref) {
  final auth = ref.watch(authServiceProvider);
  return AuthController(auth);
});


