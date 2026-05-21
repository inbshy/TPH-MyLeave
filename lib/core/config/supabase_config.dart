import 'package:supabase_flutter/supabase_flutter.dart';

/// Shared Supabase client accessor. Initialization happens in [main.dart].
class SupabaseConfig {
  SupabaseConfig._();

  static SupabaseClient get client => Supabase.instance.client;
}
