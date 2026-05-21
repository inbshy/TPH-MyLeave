import 'dart:io';

Future<Map<String, String>> readLocalEnvOverrides() async {
  for (final name in ['test.env', '.env']) {
    try {
      final file = File(name);
      if (!file.existsSync()) continue;
      return _parseEnvContent(await file.readAsString());
    } catch (_) {
      continue;
    }
  }
  return {};
}

Map<String, String> _parseEnvContent(String content) {
  final map = <String, String>{};
  for (final line in content.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final eq = trimmed.indexOf('=');
    if (eq <= 0) continue;
    final key = trimmed.substring(0, eq).trim();
    final value = trimmed.substring(eq + 1).trim();
    if (key.isNotEmpty && value.isNotEmpty) {
      map[key] = value;
    }
  }
  return map;
}
