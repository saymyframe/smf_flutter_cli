@TestOn('vm')
library;

import 'dart:io';

import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The model of modules that a file uses.
enum _Model {
  /// `package:smf_contracts/lego.dart` or `lego_core.dart`.
  lego,

  /// The older API of `package:smf_contracts/smf_contracts.dart`.
  old,
}

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

/// The path relative to the package of the file of this package that [uri]
/// in the file at [from] refers to, or `null` for a URI outside it.
String? _target(String from, String uri) {
  const package = 'package:smf_flutter_core/';
  if (uri.startsWith(package)) return 'lib/${uri.substring(package.length)}';
  if (uri.contains(':')) return null;
  return Uri.parse(from).resolve(uri).path;
}

/// The model [uri] belongs to, if it is a library of smf_contracts.
_Model? _modelOfUri(String uri) {
  if (!uri.startsWith('package:smf_contracts/')) return null;
  return uri.startsWith('package:smf_contracts/lego')
      ? _Model.lego
      : _Model.old;
}

void main() {
  // The package moves to the lego model while the CLI still uses the module
  // of the older model. These tests keep the two apart until the older
  // module is removed: no file reaches both models, through its own imports
  // or through the files of this package it imports or exports.
  final files = _dartFiles();

  /// The files of this package that [path] reaches through its imports and
  /// exports, [path] included.
  Set<String> reachable(String path) {
    final found = <String>{};
    final pending = [path];
    while (pending.isNotEmpty) {
      final next = pending.removeLast();
      if (!found.add(next)) continue;
      for (final uri in files[next]!) {
        final target = _target(next, uri);
        if (target != null && files.containsKey(target)) pending.add(target);
      }
    }
    return found;
  }

  Set<_Model> modelsOf(String path) => {
        for (final file in reachable(path))
          for (final uri in files[file]!)
            if (_modelOfUri(uri) case final model?) model,
      };

  test('finds the lego module', () {
    expect(modelsOf('lib/smf_flutter_core.dart'), {_Model.lego});
    expect(modelsOf('lib/src/flutter_core_module.dart'), {_Model.lego});
  });

  test('no file reaches both the lego model and the older API', () {
    for (final path in files.keys) {
      expect(modelsOf(path), hasLength(lessThan(2)), reason: path);
    }
  });

  test('the lego module reaches neither the engine nor mustachex', () {
    for (final path in files.keys) {
      if (!modelsOf(path).contains(_Model.lego)) continue;
      for (final file in reachable(path)) {
        for (final uri in files[file]!) {
          expect(
            uri,
            isNot(
              anyOf(
                startsWith('package:smf_contribution_engine/'),
                startsWith('package:mustachex/'),
              ),
            ),
            reason: '$path reaches $file, which uses $uri',
          );
        }
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
}
