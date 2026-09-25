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
    path == 'lego_core.dart' || path.startsWith('src/lego/core/');

bool _isLego(String path) =>
    path == 'lego.dart' ||
    path == 'lego_core.dart' ||
    path.startsWith('src/lego/');

String _relative(File file) => file.path
    .substring(file.path.lastIndexOf('lib${Platform.pathSeparator}') + 4)
    .replaceAll(Platform.pathSeparator, '/');

void main() {
  // The lego model is introduced next to the older API. These tests keep
  // the two apart, and the core free of concrete roles, until the old API
  // is removed.
  final files = _dartFiles('lib');
  final core = files.where((file) => _isCore(_relative(file))).toList();
  final lego = files.where((file) => _isLego(_relative(file))).toList();
  final old = files.where((file) => !_isLego(_relative(file))).toList();

  test('finds the files of both APIs', () {
    expect(core, isNotEmpty);
    expect(lego.length, greaterThan(core.length));
    expect(old, isNotEmpty);
  });

  test('the core depends on no concrete role and no old API', () {
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

  test('the lego model does not use the old API or the engine', () {
    for (final file in lego) {
      for (final uri in _directives(file)) {
        final target = _target(file, uri);
        expect(
          target == null || _isLego(target),
          isTrue,
          reason: '${_relative(file)} refers to the old API: $uri',
        );
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

  test('the old API does not use the lego model', () {
    for (final file in old) {
      for (final uri in _directives(file)) {
        final target = _target(file, uri);
        expect(
          target == null || !_isLego(target),
          isTrue,
          reason: '${_relative(file)} refers to the lego model: $uri',
        );
      }
    }
  });
}
