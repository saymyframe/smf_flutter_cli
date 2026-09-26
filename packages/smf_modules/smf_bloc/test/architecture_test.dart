@TestOn('vm')
library;

import 'dart:io';

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The libraries of smf_contracts that a module may use.
const _model = {
  'package:smf_contracts/lego.dart',
  'package:smf_contracts/lego_core.dart',
};

/// The URIs of the imports and exports of the Dart files in [directory], by
/// path relative to the package, as the parser of the analyzer reads them,
/// so that text in strings does not count.
Map<String, List<String>> _directivesIn(String directory) => {
      for (final file in Directory(directory).listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          file.path.replaceAll(Platform.pathSeparator, '/'): _directives(file),
    };

List<String> _directives(File file) {
  final index = DartFileIndexer.parse(file.path, file.readAsStringSync()).index;
  return [
    for (final directive in [...index.imports, ...index.exports]) directive.uri,
  ];
}

/// Whether [uri] is relative and, from the file at [path], stays in
/// [directory].
bool _staysIn(String directory, String path, String uri) =>
    !uri.contains(':') &&
    Uri.parse(path).resolve(uri).path.startsWith('$directory/');

/// The packages of the section [section] of the pubspec.
Set<String> _packagesOf(String section) {
  final pubspec = loadYaml(File('pubspec.yaml').readAsStringSync()) as YamlMap;
  return {...(pubspec[section] as YamlMap).keys.cast<String>()};
}

void main() {
  test('the module imports only lego.dart of smf_contracts and itself', () {
    for (final MapEntry(key: path, value: uris)
        in _directivesIn('lib').entries) {
      for (final uri in uris) {
        expect(
          _model.contains(uri) ||
              uri.startsWith('package:smf_bloc/') ||
              uri.startsWith('dart:') ||
              _staysIn('lib', path, uri),
          isTrue,
          reason: '$path imports $uri',
        );
      }
    }
  });

  test(
      'the tests import only lego.dart of smf_contracts, and reach no file '
      'outside test/ by a relative path', () {
    for (final MapEntry(key: path, value: uris)
        in _directivesIn('test').entries) {
      for (final uri in uris) {
        if (uri.startsWith('package:smf_contracts/')) {
          expect(_model, contains(uri), reason: path);
        } else if (!uri.contains(':')) {
          expect(_staysIn('test', path, uri), isTrue, reason: path);
        }
      }
    }
  });

  test('depends on no package but smf_contracts', () {
    expect(_packagesOf('dependencies'), {'smf_contracts'});
  });

  test('tests with no other module than the app entry of flutter_core', () {
    expect(
      _packagesOf('dev_dependencies').where((name) => name.startsWith('smf_')),
      unorderedEquals(['smf_flutter_core', 'smf_pipeline']),
    );
  });
}
