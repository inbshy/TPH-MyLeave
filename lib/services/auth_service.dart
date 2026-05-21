import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:tph_myleave/core/config/supabase_config.dart';
import 'package:tph_myleave/core/constants/app_constants.dart';

class AuthService {
  final SupabaseClient _client = SupabaseConfig.client;

  SupabaseClient get client => _client;

  User? get currentUser => _client.auth.currentUser;

  Session? get currentSession => _client.auth.currentSession;

  Future<AuthResponse> signInWithPassword({
    required String email,
    required String password,
  }) {
    return _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
  }

  Future<AuthResponse> signUp({
    required String email,
    required String password,
  }) {
    return _client.auth.signUp(email: email, password: password);
  }

  Future<void> signOut() => _client.auth.signOut();

  /// Returns the `users` row for the given auth user id, or null.
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    final row = await _client
        .from(AppConstants.tableUsers)
        .select()
        .eq('id', userId)
        .maybeSingle();
    return row;
  }

  /// Creates `users` + `employees` rows. Requires an active auth session (RLS).
  Future<int> createEmployeeProfile({
    required String userId,
    required String name,
    required String email,
    required int companyId,
  }) async {
    final profileRow = await _client
        .from(AppConstants.tableUsers)
        .insert({
          'id': userId,
          'name': name.trim(),
          'email': email.trim(),
          'role': AppConstants.roleEmployee,
          'staff_type': 'permanent',
          'company_id': companyId,
          'created_at': DateTime.now().toIso8601String(),
        })
        .select('employee_id')
        .single();

    final rawId = profileRow['employee_id'];
    final employeeId = rawId is int ? rawId : (rawId as num).toInt();

    await _client.from(AppConstants.tableEmployees).insert({
      'user_id': userId,
      'employee_id': employeeId,
      'company_id': companyId,
      'name': name.trim(),
      'role': AppConstants.roleEmployee,
    });

    return employeeId;
  }
}
