// Validates frontend env files before dev run or production build.
// Usage:
//   dart run tool/validate_env.dart              # checks .env for dev
//   dart run tool/validate_env.dart --production # checks env.production.json

import 'dart:convert';
import 'dart:io';

final _placeholderPatterns = [
  RegExp(r'^your[_-]', caseSensitive: false),
  RegExp(r'^YOUR_', caseSensitive: false),
  RegExp(r'your_key_here', caseSensitive: false),
  RegExp(r'your_firebase', caseSensitive: false),
  RegExp(r'your_production', caseSensitive: false),
  RegExp(r'your-key@', caseSensitive: false),
  RegExp(r'yourdomain\.com', caseSensitive: false),
  RegExp(r'^placeholder$', caseSensitive: false),
  RegExp(r'CHANGE_ME', caseSensitive: false),
];

void main(List<String> args) {
  final production = args.contains('--production');
  final projectRoot = Directory.current.path.endsWith('tool')
      ? Directory.current.parent
      : Directory.current;

  final manifest = _loadManifest(projectRoot);
  final errors = <String>[];
  final warnings = <String>[];

  if (production) {
    _validateProduction(projectRoot, manifest, errors, warnings);
  } else {
    _validateDev(projectRoot, manifest, errors, warnings);
  }

  _checkGitignore(projectRoot, warnings);

  for (final warning in warnings) {
    stderr.writeln('WARNING: $warning');
  }

  if (errors.isNotEmpty) {
    for (final error in errors) {
      stderr.writeln('ERROR: $error');
    }
    stderr.writeln('');
    stderr.writeln('See frontend/env.manifest.json and .env.example');
    exit(1);
  }

  stdout.writeln(
    production
        ? 'env.production.json OK for release build'
        : 'Dev env OK (.env)',
  );
}

Map<String, dynamic> _loadManifest(Directory projectRoot) {
  final file = File('${projectRoot.path}/env.manifest.json');
  if (!file.existsSync()) {
    stderr.writeln('WARNING: missing ${file.path}');
    return {};
  }
  return jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
}

void _validateProduction(
  Directory projectRoot,
  Map<String, dynamic> manifest,
  List<String> errors,
  List<String> warnings,
) {
  final path = '${projectRoot.path}/env.production.json';
  final file = File(path);
  if (!file.existsSync()) {
    errors.add(
      'Missing env.production.json — copy env.production.example.json and fill values',
    );
    return;
  }

  Map<String, dynamic> data;
  try {
    data = jsonDecode(file.readAsStringSync()) as Map<String, dynamic>;
  } catch (e) {
    errors.add('env.production.json is not valid JSON: $e');
    return;
  }

  final requiredKeys = _requiredProductionKeys(manifest);
  for (final key in requiredKeys) {
    final raw = data[key];
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) {
      errors.add('env.production.json missing required key: $key');
      continue;
    }
    if (_looksLikePlaceholder(value)) {
      errors.add('env.production.json $key still has placeholder value');
    }
  }

  if (data['APP_ENV']?.toString() != 'production') {
    errors.add(
      'APP_ENV must be "production" in env.production.json — '
      'otherwise the app probes localhost/LAN and may ignore meatvo.com',
    );
  }

  final apiBase = data['API_BASE_URL']?.toString().trim() ?? '';
  if (apiBase.contains('192.168.') ||
      apiBase.contains('127.0.0.1') ||
      apiBase.contains('10.0.2.2')) {
    errors.add('env.production.json API_BASE_URL must be your public domain, not a LAN IP');
  }

  for (final forbidden in _neverInClient(manifest)) {
    if (data.containsKey(forbidden)) {
      errors.add('env.production.json must not contain server secret: $forbidden');
    }
  }
}

void _validateDev(
  Directory projectRoot,
  Map<String, dynamic> manifest,
  List<String> errors,
  List<String> warnings,
) {
  final path = '${projectRoot.path}/.env';
  final file = File(path);
  if (!file.existsSync()) {
    errors.add('Missing .env — copy .env.example → .env');
    return;
  }

  final parsed = _parseDotEnv(file);
  if (!(parsed['GOOGLE_MAPS_API_KEY'] ?? '').isNotEmpty ||
      _looksLikePlaceholder(parsed['GOOGLE_MAPS_API_KEY'] ?? '')) {
    warnings.add('GOOGLE_MAPS_API_KEY missing or placeholder in .env — maps may fail');
  }

  for (final forbidden in _neverInClient(manifest)) {
    if (parsed.containsKey(forbidden) && (parsed[forbidden] ?? '').isNotEmpty) {
      errors.add('.env must not contain server secret: $forbidden');
    }
  }
}

List<String> _requiredProductionKeys(Map<String, dynamic> manifest) {
  final fromManifest = <String>[];
  final variables = manifest['variables'];
  if (variables is Map<String, dynamic>) {
    for (final entry in variables.entries) {
      final meta = entry.value;
      if (meta is Map<String, dynamic> && meta['required'] == 'production') {
        fromManifest.add(entry.key);
      }
    }
  }
  if (fromManifest.isNotEmpty) return fromManifest;

  return [
    'API_BASE_URL',
    'APP_ENV',
    'CASHFREE_ENV',
    'GOOGLE_MAPS_API_KEY',
    'FIREBASE_API_KEY',
    'FIREBASE_APP_ID',
    'FIREBASE_PROJECT_ID',
    'FIREBASE_MESSAGING_SENDER_ID',
    'FIREBASE_STORAGE_BUCKET',
  ];
}

List<String> _neverInClient(Map<String, dynamic> manifest) {
  final list = manifest['never_in_client'];
  if (list is List) return list.map((e) => e.toString()).toList();
  return [];
}

Map<String, String> _parseDotEnv(File file) {
  final parsed = <String, String>{};
  for (final rawLine in file.readAsLinesSync()) {
    final line = rawLine.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final eq = line.indexOf('=');
    if (eq <= 0) continue;
    parsed[line.substring(0, eq).trim()] = line.substring(eq + 1).trim();
  }
  return parsed;
}

bool _looksLikePlaceholder(String value) {
  if (value.isEmpty) return true;
  return _placeholderPatterns.any((p) => p.hasMatch(value));
}

void _checkGitignore(Directory projectRoot, List<String> warnings) {
  final productionFile = File('${projectRoot.path}/env.production.json');
  if (!productionFile.existsSync()) return;

  try {
    final result = Process.runSync(
      'git',
      ['check-ignore', '-q', 'env.production.json'],
      workingDirectory: projectRoot.path,
      runInShell: true,
    );
    if (result.exitCode != 0) {
      warnings.add(
        'env.production.json is not gitignored — add to frontend/.gitignore and run: git rm --cached frontend/env.production.json',
      );
    }
  } catch (_) {
    // git not available
  }
}
