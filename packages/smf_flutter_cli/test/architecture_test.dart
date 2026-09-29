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

/// The library of the tests that the matrix of CI adds to the apps of the
/// modules of `smf create` (`smfAppTests`), which only `tool/matrix.dart`,
/// the tests of the package and the app of several providers of the
/// fixture registry import. It names the modules whose app tests it
/// registers and the roles whose contract those tests check, so no library
/// of the binary, or of the matrix, imports it.
const _appTests = 'lib/matrix_app_tests.dart';

/// The path from the package of the library of the package that [uri]
/// names in the library at [path], or `null` if it names another.
String? _ownLibrary(String path, String uri) {
  const own = 'package:smf_flutter_cli/';
  if (uri.startsWith(own)) return 'lib/${uri.substring(own.length)}';
  if (Uri.parse(uri).hasScheme) return null;
  return Uri.parse(path).resolve(uri).path;
}

void main() {
  final libraries = _libraries();

  test('the binary knows no role, only the core of the module model', () {
    for (final MapEntry(key: path, value: uris) in libraries.entries) {
      if (path == _appTests) continue;
      for (final uri in uris) {
        if (!uri.startsWith('package:smf_contracts/')) continue;
        expect(uri, 'package:smf_contracts/core.dart', reason: path);
      }
    }
  });

  test(
      'only the list of the modules names the modules, and the tests of the '
      'apps of the matrix those whose app tests they register', () {
    expect(libraries['lib/src/modules.dart']!.where(_ofModule), isNotEmpty);
    for (final MapEntry(key: path, value: uris) in libraries.entries) {
      if (path == 'lib/src/modules.dart' || path == _appTests) continue;
      expect(uris.where(_ofModule), isEmpty, reason: path);
    }
  });

  test(
      'no library of the package imports the tests of the apps of the '
      'matrix, which name modules and roles', () {
    expect(libraries, contains(_appTests));
    for (final MapEntry(key: path, value: uris) in libraries.entries) {
      expect(
        [for (final uri in uris) _ownLibrary(path, uri)],
        isNot(contains(_appTests)),
        reason: path,
      );
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
