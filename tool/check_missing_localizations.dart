import 'dart:convert';
import 'dart:io';

void main() {
  final dartDir = Directory('lib');

  if (!dartDir.existsSync()) {
    print('lib folder not found.');
    exit(1);
  }

  final usedKeys = <String>{};

  final dartFiles = dartDir
      .listSync(recursive: true)
      .whereType<File>()
      .where((file) => file.path.endsWith('.dart'));

  final translateRegex = RegExp(r'''translate\(['"]([^'"]+)['"]\)''');

  for (final file in dartFiles) {
    final content = file.readAsStringSync();

    for (final match in translateRegex.allMatches(content)) {
      final key = match.group(1);
      if (key != null && key.trim().isNotEmpty) {
        usedKeys.add(key.trim());
      }
    }
  }

  final enKeys = _readArbKeys('lib/l10n/app_en.arb');
  final trKeys = _readArbKeys('lib/l10n/app_tr.arb');

  _printSection(
    'Missing in app_tr.arb',
    usedKeys.where((key) => !trKeys.contains(key)).toList(),
  );

  _printSection(
    'Missing in app_en.arb',
    usedKeys.where((key) => !enKeys.contains(key)).toList(),
  );

  _printSection(
    'In app_en.arb but missing in app_tr.arb',
    enKeys.where((key) => !trKeys.contains(key)).toList(),
  );

  _printSection(
    'In app_tr.arb but missing in app_en.arb',
    trKeys.where((key) => !enKeys.contains(key)).toList(),
  );
}

Set<String> _readArbKeys(String path) {
  final file = File(path);

  if (!file.existsSync()) {
    print('ARB file not found: $path');
    exit(1);
  }

  try {
    final decoded = jsonDecode(file.readAsStringSync());

    if (decoded is! Map<String, dynamic>) {
      print('Invalid ARB format: $path');
      exit(1);
    }

    return decoded.keys.where((key) => !key.startsWith('@')).toSet();
  } catch (e) {
    print('Invalid JSON in $path');
    print(e);
    exit(1);
  }
}

void _printSection(String title, List<String> keys) {
  keys.sort();

  print('\n$title:');

  if (keys.isEmpty) {
    print('✅ None');
    return;
  }

  for (final key in keys) {
    print('- $key');
  }
}
