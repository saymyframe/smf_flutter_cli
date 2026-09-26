@TestOn('vm')
library;

import 'dart:io';

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The URIs of the imports and exports of the Dart files of `lib/`, by path,
/// as the parser of the analyzer reads them.
Map<String, List<String>> _libraries() => {
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File && file.path.endsWith('.dart'))
          file.path.replaceAll(Platform.pathSeparator, '/'): _directives(file),
    };

List<String> _directives(File file) {
  final index = DartFileIndexer.parse(file.path, file.readAsStringSync()).index;
  return [
    for (final directive in [...index.imports, ...index.exports]) directive.uri,
  ];
}

/// Whether [uri] is a library of a module package: an SMF package that is
/// neither the contracts, the pipeline nor the CLI.
bool _ofModule(String uri) =>
    uri.startsWith('package:smf_') &&
    !['smf_contracts', 'smf_pipeline', 'smf_flutter_cli']
        .any((package) => uri.startsWith('package:$package/'));

void main() {
  final libraries = _libraries();

  test('the binary knows no role, only the core of the module model', () {
    for (final MapEntry(key: path, value: uris) in libraries.entries) {
      for (final uri in uris) {
        if (!uri.startsWith('package:smf_contracts/')) continue;
        expect(uri, 'package:smf_contracts/lego_core.dart', reason: path);
      }
    }
  });

  test('only the list of the modules names the modules', () {
    expect(libraries['lib/src/modules.dart']!.where(_ofModule), isNotEmpty);
    for (final MapEntry(key: path, value: uris) in libraries.entries) {
      if (path == 'lib/src/modules.dart') continue;
      expect(uris.where(_ofModule), isEmpty, reason: path);
    }
  });

  test('neither the engine nor mustachex', () {
    for (final MapEntry(key: path, value: uris) in libraries.entries) {
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
}
