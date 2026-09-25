@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// The URIs of the import, export and part directives of the Dart files in
/// `lib/`, by file.
Map<String, List<String>> _directives() {
  final directive = RegExp(
    r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  return {
    for (final file in Directory('lib').listSync(recursive: true))
      if (file is File && file.path.endsWith('.dart'))
        file.path: [
          for (final match in directive.allMatches(file.readAsStringSync()))
            match.group(1)!,
        ],
  };
}

void main() {
  // The pipeline knows no concrete role and no module, and reaches the
  // machine only through the seams of SmfHost.
  final directives = _directives();

  test('finds the files of the pipeline', () {
    expect(directives, isNotEmpty);
  });

  test('imports only the core of the lego model from smf_contracts', () {
    for (final MapEntry(key: file, value: uris) in directives.entries) {
      for (final uri in uris) {
        if (!uri.startsWith('package:smf_contracts/')) continue;
        expect(
          uri,
          'package:smf_contracts/lego_core.dart',
          reason: '$file imports $uri',
        );
      }
    }
  });

  test('does not touch dart:io', () {
    for (final MapEntry(key: file, value: uris) in directives.entries) {
      expect(uris, isNot(contains('dart:io')), reason: file);
    }
  });

  test('depends on no module package', () {
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dependencies = RegExp(r'^\s+(smf_[a-z_]+):', multiLine: true)
        .allMatches(pubspec)
        .map((match) => match.group(1))
        .toSet();

    expect(dependencies, {'smf_contracts'});
  });
}
