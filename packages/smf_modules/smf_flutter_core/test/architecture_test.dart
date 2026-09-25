@TestOn('vm')
library;

import 'dart:io';

import 'package:test/test.dart';

/// The model of modules that a file uses.
enum _Model {
  /// `package:smf_contracts/lego.dart` or `lego_core.dart`.
  lego,

  /// The older API of `package:smf_contracts/smf_contracts.dart`.
  old,
}

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

/// The directives of the Dart files of the package in `lib/` and `test/`,
/// by path relative to the package.
Map<String, List<String>> _dartFiles() => {
      for (final directory in ['lib', 'test'])
        for (final file in Directory(directory).listSync(recursive: true))
          if (file is File && file.path.endsWith('.dart'))
            file.path.replaceAll(Platform.pathSeparator, '/'):
                _directives(file),
    };

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

  final models = <String, Set<_Model>>{};
  Set<_Model> modelsOf(String path) {
    if (models[path] case final known?) return known;
    final found = models[path] = <_Model>{};
    for (final uri in files[path]!) {
      if (_modelOfUri(uri) case final model?) found.add(model);
      final target = _target(path, uri);
      if (target != null && files.containsKey(target)) {
        found.addAll(modelsOf(target));
      }
    }
    return found;
  }

  test('finds the lego module', () {
    expect(modelsOf('lib/smf_flutter_core.dart'), {_Model.lego});
    expect(modelsOf('lib/src/flutter_core_module.dart'), {_Model.lego});
  });

  test('no file reaches both the lego model and the older API', () {
    for (final path in files.keys) {
      expect(modelsOf(path), hasLength(lessThan(2)), reason: path);
    }
  });

  test('the lego module uses neither the engine nor mustachex', () {
    for (final MapEntry(key: path, value: uris) in files.entries) {
      if (!modelsOf(path).contains(_Model.lego)) continue;
      for (final uri in uris) {
        expect(
          uri,
          isNot(
            anyOf(
              startsWith('package:smf_contribution_engine/'),
              startsWith('package:mustachex/'),
            ),
          ),
          reason: '$path must not use $uri',
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
}
