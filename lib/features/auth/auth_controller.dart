import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tph_myleave/services/auth_service.dart';

class AuthState {
  final User? user;
  final String? role;
  final String? error;
  final bool isLoading;

  AuthState({
    this.user,
    this.role,
    this.error,
    this.isLoading = false,
  });

  bool get isAuthenticated => user != null;

  /// Signed in to Auth but no row in `public.users` yet.
  bool get needsProfile => user != null && role == null;

  AuthState copyWith({
    User? user,
    String? role,
    String? error,
    bool? isLoading,
    bool clearRole = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      role: clearRole ? null : (role ?? this.role),
      error: error,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._auth) : super(AuthState()) {
    _init();
  }

  final AuthService _auth;

  Future<void> _init() async {
    final session = _auth.currentSession;
    if (session?.user != null) {
      await _refreshProfile(session!.user.id);
    }

    _auth.client.auth.onAuthStateChange.listen((data) async {
      final u = data.session?.user;
      if (u != null) {
        await _refreshProfile(u.id);
      } else {
        state = AuthState();
      }
    });
  }

  Future<void> _refreshProfile(String userId) async {
    final profile = await _auth.fetchUserProfile(userId);
    final role = _parseRole(profile?['role']);
    state = AuthState(
      user: _auth.currentUser,
      role: profile == null ? null : role,
      error: null,
      isLoading: state.isLoading,
    );
  }

  static String? _parseRole(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim().toLowerCase();
    return s.isEmpty ? null : s;
  }

  /// Reload role from `public.users` (e.g. after an admin changes it in Supabase).
  Future<void> refreshProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _refreshProfile(user.id);
  }

  /// Sign in; role is read from `public.users` in the backend.
  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    try {
      state = state.copyWith(isLoading: true, error: null);

      final res = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (res.user == null) {
        state = state.copyWith(
          error: 'Invalid email or password.',
          isLoading: false,
        );
        return;
      }

      await _refreshProfile(res.user!.id);
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      state = state.copyWith(isLoading: true, error: null);
      final res = await _auth.signUp(email: email.trim(), password: password);
      if (res.user == null) {
        state = state.copyWith(
          error: 'Sign up failed. Try again later.',
          isLoading: false,
        );
        return;
      }
      await _refreshProfile(res.user!.id);
      state = state.copyWith(isLoading: false);
    } on AuthException catch (e) {
      state = state.copyWith(error: e.message, isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> completeEmployeeProfile({
    required String name,
    required int companyId,
  }) async {
    final user = _auth.currentUser;
    if (user == null) {
      state = state.copyWith(error: 'Not signed in.');
      return;
    }

    try {
      state = state.copyWith(isLoading: true, error: null);
      await _auth.createEmployeeProfile(
        userId: user.id,
        name: name,
        email: user.email ?? '',
        companyId: companyId,
      );
      await _refreshProfile(user.id);
      state = state.copyWith(isLoading: false);
    } catch (e) {
      state = state.copyWith(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> signOut() async {
    await _auth.signOut();
    state = AuthState();
  }
}
