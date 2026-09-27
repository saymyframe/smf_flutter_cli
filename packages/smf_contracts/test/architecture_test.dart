@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// The URIs of the import, export and part directives of a Dart file.
List<String> _directives(File file) {
  final directive = RegExp(
    r'''^\s*(?:import|export|part)\s+['"]([^'"]+)['"]''',
    multiLine: true,
  );
  return [
    for (final match in directive.allMatches(file.readAsStringSync()))
      match.group(1)!,
  ];
}

List<File> _dartFiles(String directory) => Directory(directory)
    .listSync(recursive: true)
    .whereType<File>()
    .where((file) => file.path.endsWith('.dart'))
    .toList();

/// Where the URI of a directive in [file] points, relative to `lib/`, or
/// `null` for a URI outside this package.
String? _target(File file, String uri) {
  const package = 'package:smf_contracts/';
  if (uri.startsWith(package)) return uri.substring(package.length);
  if (uri.contains(':')) return null;
  final segments = [...file.parent.uri.pathSegments.where((s) => s.isNotEmpty)];
  for (final segment in uri.split('/')) {
    if (segment == '..') {
      segments.removeLast();
    } else if (segment != '.') {
      segments.add(segment);
    }
  }
  final lib = segments.lastIndexOf('lib');
  return segments.sublist(lib + 1).join('/');
}

bool _isCore(String path) =>
    path == 'lego_core.dart' || path.startsWith('src/core/');

String _relative(File file) => file.path
    .substring(file.path.lastIndexOf('lib${Platform.pathSeparator}') + 4)
    .replaceAll(Platform.pathSeparator, '/');

void main() {
  // The core of the module model knows no concrete role, so the pipeline,
  // which imports only the core, cannot depend on one either.
  final files = _dartFiles('lib');
  final core = files.where((file) => _isCore(_relative(file))).toList();

  test('finds the core and the roles', () {
    expect(core, isNotEmpty);
    expect(files.length, greaterThan(core.length));
  });

  test('the core depends on no concrete role', () {
    for (final file in core) {
      for (final uri in _directives(file)) {
        final target = _target(file, uri);
        if (target == null) continue;
        expect(
          _isCore(target),
          isTrue,
          reason: '${_relative(file)} refers to $uri outside the core',
        );
      }
    }
  });

  test('neither the engine nor mustachex', () {
    for (final file in files) {
      for (final uri in _directives(file)) {
        expect(
          uri,
          isNot(
            anyOf(
              startsWith('package:smf_contribution_engine/'),
              startsWith('package:mustachex/'),
            ),
          ),
          reason: '${_relative(file)} must not use $uri',
        );
      }
    }
  });
}
