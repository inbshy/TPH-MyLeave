import 'package:flutter/foundation.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

import 'local_env_io.dart' if (dart.library.html) 'local_env_stub.dart'
    as local_env;

/// Loads Supabase credentials from bundled [test.env.example], with optional
/// local overrides from a gitignored `test.env` when running on desktop.
class EnvConfig {
  EnvConfig._();

  static const _exampleFile = 'test.env.example';
  static const _placeholderUrl = 'your-project.supabase.co';
  static const _placeholderKey = 'your-supabase-anon-key';

  static Future<void> load() async {
    final overrides = await _readLocalOverrides();
    await dotenv.load(
      fileName: _exampleFile,
      mergeWith: overrides,
    );
  }

  static String get supabaseUrl {
    final url = dotenv.env['SUPABASE_URL']?.trim() ?? '';
    if (url.isEmpty) {
      throw _missingEnv(
        'SUPABASE_URL is empty. Edit test.env.example (or test.env) in the project root.',
      );
    }
    if (url.contains(_placeholderUrl)) {
      throw _missingEnv(
        'SUPABASE_URL is still a placeholder. Open test.env.example and set your '
        'real Supabase project URL (Dashboard → Project Settings → API).',
      );
    }
    final uri = Uri.tryParse(url);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw _missingEnv(
        'SUPABASE_URL is invalid: "$url". Use https://YOUR_PROJECT.supabase.co '
        'with no spaces after =.',
      );
    }
    return url;
  }

  static String get supabaseAnonKey {
    final key = dotenv.env['SUPABASE_ANON_KEY']?.trim() ?? '';
    if (key.isEmpty) {
      throw _missingEnv(
        'SUPABASE_ANON_KEY is empty. Edit test.env.example (or test.env) in the project root.',
      );
    }
    if (key == _placeholderKey) {
      throw _missingEnv(
        'SUPABASE_ANON_KEY is still a placeholder. Open test.env.example and set your '
        'anon/public key from Supabase Dashboard → Project Settings → API.',
      );
    }
    return key;
  }

  static Future<Map<String, String>> _readLocalOverrides() async {
    if (kIsWeb) return {};
    return local_env.readLocalEnvOverrides();
  }

  static Exception _missingEnv(String message) => Exception(message);
}
