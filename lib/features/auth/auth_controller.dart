import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tph_myleave/services/auth_service.dart';

class AuthState {
  final User? user;
  final String? role;
  final String? error;
  final bool isLoading;
  final bool hasProfile;

  AuthState({
    this.user,
    this.role,
    this.error,
    this.isLoading = false,
    this.hasProfile = false,
  });

  bool get isAuthenticated => user != null;

  AuthState copyWith({
    User? user,
    String? role,
    String? error,
    bool? isLoading,
    bool? hasProfile,
    bool clearRole = false,
    bool clearError = false,
  }) {
    return AuthState(
      user: user ?? this.user,
      role: clearRole ? null : (role ?? this.role),
      error: clearError ? null : (error ?? this.error),
      isLoading: isLoading ?? this.isLoading,
      hasProfile: hasProfile ?? this.hasProfile,
    );
  }
}

class AuthController extends StateNotifier<AuthState> {
  AuthController(this._auth) : super(AuthState()) {
    _init();
  }

  final AuthService _auth;

  static const String _noProfileMessage =
      'No employee profile for this account. Use "Register employee" on the login '
      'screen, or contact your administrator.';

  Future<void> _init() async {
    final session = _auth.currentSession;
    if (session?.user != null) {
      await _refreshProfile(session!.user.id);
      if (!state.hasProfile) {
        await _rejectSessionWithoutProfile();
      }
    }

    _auth.client.auth.onAuthStateChange.listen((data) async {
      final u = data.session?.user;
      if (u != null) {
        await _refreshProfile(u.id);
        if (!state.hasProfile) {
          await _rejectSessionWithoutProfile();
        }
      } else if (data.event == AuthChangeEvent.signedOut) {
        state = AuthState();
      }
    });
  }

  Future<void> _rejectSessionWithoutProfile() async {
    await _auth.signOut();
    state = AuthState(error: _noProfileMessage);
  }

  Future<void> _refreshProfile(String userId) async {
    try {
      final profile = await _auth.fetchUserProfile(userId);
      final hasProfile = profile != null;
      final role = hasProfile ? _parseRole(profile['role']) : null;

      state = AuthState(
        user: _auth.currentUser,
        role: role,
        hasProfile: hasProfile,
        error: state.error,
        isLoading: state.isLoading,
      );
    } on PostgrestException catch (e) {
      state = AuthState(
        user: _auth.currentUser,
        role: state.role,
        hasProfile: false,
        error: _profileLoadError(e),
        isLoading: false,
      );
    } catch (e) {
      state = AuthState(
        user: _auth.currentUser,
        role: state.role,
        hasProfile: false,
        error: 'Could not load profile: $e',
        isLoading: false,
      );
    }
  }

  static String _profileLoadError(PostgrestException e) {
    final message = e.message.toLowerCase();
    if (message.contains('infinite recursion') ||
        (message.contains('policy') && message.contains('users')) ||
        message.contains('get_my_profile')) {
      return 'Could not load profile (database security policy).\n\n'
          'In Supabase → SQL Editor, open and run the whole file:\n'
          'supabase/fix_login_profile.sql\n\n'
          'Then hot restart the app and sign in again.';
    }
    return 'Could not load profile: ${e.message}';
  }

  static String? _parseRole(Object? raw) {
    if (raw == null) return null;
    final s = raw.toString().trim().toLowerCase();
    return s.isEmpty ? null : s;
  }

  Future<void> refreshProfile() async {
    final user = _auth.currentUser;
    if (user == null) return;
    await _refreshProfile(user.id);
  }

  Future<void> signIn({
    required String email,
    required String password,
  }) async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final res = await _auth.signInWithPassword(
        email: email.trim(),
        password: password,
      );

      if (res.session == null) {
        state = AuthState(
          error:
              'No active session. If you just registered, confirm your email first, '
              'then sign in again.\n\n'
              'For testing: Supabase → Authentication → Providers → Email → '
              'turn off "Confirm email".',
          isLoading: false,
        );
        return;
      }

      if (res.user == null) {
        state = state.copyWith(
          error: 'Invalid email or password.',
          isLoading: false,
        );
        return;
      }

      await _refreshProfile(res.user!.id);

      if (_auth.currentUser == null) {
        state = state.copyWith(
          error: 'Sign-in failed. Please try again.',
          isLoading: false,
        );
        return;
      }

      if (state.error != null &&
          (state.error!.startsWith('Could not load profile') ||
              state.error!.contains('database security policy'))) {
        await _auth.signOut();
        state = state.copyWith(isLoading: false);
        return;
      }

      if (!state.hasProfile) {
        await _rejectSessionWithoutProfile();
        state = state.copyWith(isLoading: false);
        return;
      }

      state = state.copyWith(isLoading: false, clearError: true);
    } on AuthException catch (e) {
      state = AuthState(
        error: e.message,
        isLoading: false,
      );
    } catch (e) {
      state = AuthState(
        error: e.toString(),
        isLoading: false,
      );
    }
  }

  Future<void> signUp(String email, String password) async {
    try {
      state = state.copyWith(isLoading: true, clearError: true);
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

  Future<void> signOut() async {
    await _auth.signOut();
    state = AuthState();
  }
}
