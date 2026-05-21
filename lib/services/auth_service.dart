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

  Future<void> resetPasswordForEmail(String email) =>
      _client.auth.resetPasswordForEmail(email.trim());

  /// Returns the `users` row for the given auth user id, or null if missing.
  Future<Map<String, dynamic>?> fetchUserProfile(String userId) async {
    final currentId = currentUser?.id;
    if (currentId != null && currentId == userId) {
      final fromRpc = await _fetchOwnProfileViaRpc();
      if (fromRpc != null) return fromRpc;
    }

    final rows = await _client
        .from(AppConstants.tableUsers)
        .select()
        .eq('id', userId)
        .limit(1);

    if (rows.isEmpty) return null;
    return Map<String, dynamic>.from(rows.first);
  }

  /// Uses DB function `get_my_profile()` (security definer) to avoid RLS recursion.
  Future<Map<String, dynamic>?> _fetchOwnProfileViaRpc() async {
    try {
      final data = await _client.rpc('get_my_profile');
      if (data == null) return null;
      if (data is Map<String, dynamic>) return data;
      if (data is Map) return Map<String, dynamic>.from(data);
      return null;
    } on PostgrestException catch (e) {
      // Function not deployed yet — fall back to direct table read.
      if (e.code == 'PGRST202' ||
          e.message.contains('get_my_profile') ||
          e.message.contains('Could not find the function')) {
        return null;
      }
      rethrow;
    }
  }

  /// Creates or updates `users` + `employees` rows. Requires an active auth session.
  Future<int> createEmployeeProfile({
    required String userId,
    required String name,
    required String email,
    required int companyId,
  }) async {
    final existing = await fetchUserProfile(userId);

    if (existing != null) {
      await _client.from(AppConstants.tableUsers).update({
        'name': name.trim(),
        'email': email.trim(),
        'company_id': companyId,
      }).eq('id', userId);

      final employeeId = existing['employee_id'] as int;
      try {
        await _client.from(AppConstants.tableEmployees).update({
          'name': name.trim(),
          'company_id': companyId,
        }).eq('user_id', userId);
      } catch (_) {
        await _client.from(AppConstants.tableEmployees).insert({
          'user_id': userId,
          'employee_id': employeeId,
          'company_id': companyId,
          'name': name.trim(),
          'role': AppConstants.roleEmployee,
        });
      }
      return employeeId;
    }

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

    try {
      await _client.from(AppConstants.tableEmployees).insert({
        'user_id': userId,
        'employee_id': employeeId,
        'company_id': companyId,
        'name': name.trim(),
        'role': AppConstants.roleEmployee,
      });
    } catch (_) {}

    return employeeId;
  }
}
