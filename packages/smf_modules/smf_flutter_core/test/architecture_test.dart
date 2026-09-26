@TestOn('vm')
library;

import 'dart:io';

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The URIs of the imports and exports of the Dart files of the package in
/// `lib/` and `test/`, by path relative to the package, as the parser of the
/// analyzer reads them, so that text in strings does not count.
Map<String, List<String>> _dartFiles() => {
      for (final directory in ['lib', 'test'])
        for (final file in Directory(directory).listSync(recursive: true))
          if (file is File && file.path.endsWith('.dart'))
            file.path.replaceAll(Platform.pathSeparator, '/'):
                _directives(file),
    };

List<String> _directives(File file) {
  final index = DartFileIndexer.parse(file.path, file.readAsStringSync()).index;
  return [
    for (final directive in [...index.imports, ...index.exports]) directive.uri,
  ];
}

void main() {
  final files = _dartFiles();

  test('uses only the lego model of smf_contracts', () {
    for (final MapEntry(key: path, value: uris) in files.entries) {
      for (final uri in uris) {
        if (!uri.startsWith('package:smf_contracts/')) continue;
        expect(uri, startsWith('package:smf_contracts/lego'), reason: path);
      }
    }
  });

  test('reaches neither the engine nor mustachex', () {
    for (final MapEntry(key: path, value: uris) in files.entries) {
      for (final uri in uris) {
        expect(
          uri,
          isNot(
            anyOf(
              startsWith('package:smf_contribution_engine/'),
              startsWith('package:mustachex/'),
            ),
          ),
          reason: path,
        );
      }
    }
  });

  test('depends on no other module package', () {
    // The module declares no dependsOn, so it needs no other module.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final dependencies = pubspec.substring(
      pubspec.indexOf('\ndependencies:'),
      pubspec.indexOf('\ndev_dependencies:'),
    );

    expect(
      RegExp(r'^\s+(smf_[a-z_]+):', multiLine: true)
          .allMatches(dependencies)
          .map((match) => match.group(1))
          .toSet(),
      {'smf_contracts'},
    );
  });

  test('tests with no module package, so that other modules can', () {
    // Modules render the apps of their tests with this module as a dev
    // dependency, which pub resolves when the package is analyzed on
    // pub.dev: a dev dependency back on a module would make a cycle.
    final pubspec = File('pubspec.yaml').readAsStringSync();
    final devDependencies =
        pubspec.substring(pubspec.indexOf('\ndev_dependencies:'));

    expect(
      RegExp(r'^\s+(smf_[a-z_]+):', multiLine: true)
          .allMatches(devDependencies)
          .map((match) => match.group(1))
          .toSet(),
      {'smf_pipeline'},
    );
  });
}
