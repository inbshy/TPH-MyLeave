/// User-facing message for network failures talking to Supabase.
String networkErrorMessage(Object error) {
  final text = error.toString().toLowerCase();

  if (text.contains('socketexception') ||
      text.contains('clientexception') ||
      text.contains('failed host lookup') ||
      text.contains('connection refused') ||
      text.contains('network is unreachable')) {
    return 'Cannot reach Supabase (network error).\n\n'
        '• Check internet connection\n'
        '• In test.env.example, set a valid SUPABASE_URL '
        '(https://YOUR_PROJECT.supabase.co, no spaces after =)\n'
        '• Confirm the Supabase project is active in the dashboard\n'
        '• Restart the app after saving the env file';
  }

  if (text.contains('your-project.supabase.co') ||
      text.contains('your-supabase-anon-key')) {
    return 'Supabase is not configured. Edit test.env.example with your real '
        'SUPABASE_URL and SUPABASE_ANON_KEY, then restart the app.';
  }

  return error.toString().replaceFirst('Exception: ', '');
}
