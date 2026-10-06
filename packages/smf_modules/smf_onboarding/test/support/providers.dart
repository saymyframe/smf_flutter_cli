import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';

/// The brick [name] with the text files [files], each by its path in the
/// app.
MasonBundle _bundle(String name, Map<String, String> files) => MasonBundle(
      name: name,
      description: name,
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );

/// A provider of the preferences role for the tests, whose preferences keep
/// the settings in memory, in plain Dart: over `savedPreferences`, a map
/// that stands for the storage of a device, which each open of the
/// preferences reads anew and each write changes. While `writeError` is
/// set, a write fails with it and saves nothing.
///
/// So the code of the app that keeps a setting runs with the Dart SDK
/// alone, and a test sets what an earlier launch saved, and reads what
/// this one did.
final class MemoryPreferencesModule extends SmfModule {
  /// Creates the module.
  const MemoryPreferencesModule();

  /// The id of the module.
  static const id = ModuleId('memory_preferences');

  /// The path below `lib/` of the file of the preferences.
  static const file = 'core/preferences/memory_app_preferences.dart';

  static const _file = ImportRef.app(file);

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Preferences in memory (test)',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(preferencesRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(_bundle('memory_preferences', {'lib/$file': _code})),
        preferencesRole.data(
          const RoleImplementation(
            type: TypeRef('MemoryAppPreferences', import: _file),
            create: FactoryRef('createMemoryAppPreferences', import: _file),
          ),
        ),
      ];

  static const _code = '''
import 'app_preferences.dart';

/// What the device has saved: each open of the preferences reads it anew,
/// and each write changes it.
final Map<String, Object> savedPreferences = {};

/// What the writes fail with, or `null` while they save.
Object? writeError;

/// Opens the preferences with what [savedPreferences] have.
AppPreferences createMemoryAppPreferences() =>
    MemoryAppPreferences(Map.of(savedPreferences));

/// The preferences of the tests, in memory.
final class MemoryAppPreferences implements AppPreferences {
  /// Creates the preferences that have read [_values].
  MemoryAppPreferences(this._values);

  final Map<String, Object> _values;

  T? _read<T>(String key) => switch (_values[key]) {
    final T value => value,
    _ => null,
  };

  Future<void> _write(String key, Object value) async {
    // A write takes a moment, as that of a device does.
    await Future<void>.delayed(Duration.zero);
    if (writeError case final error?) throw error;
    _values[key] = value;
    savedPreferences[key] = value;
  }

  @override
  String? getString(String key) => _read<String>(key);

  @override
  bool? getBool(String key) => _read<bool>(key);

  @override
  int? getInt(String key) => _read<int>(key);

  @override
  double? getDouble(String key) => _read<double>(key);

  @override
  List<String>? getStringList(String key) => switch (_read<List<String>>(key)) {
    final list? => List.of(list),
    null => null,
  };

  @override
  Future<void> setString(String key, String value) => _write(key, value);

  @override
  Future<void> setBool(String key, bool value) => _write(key, value);

  @override
  Future<void> setInt(String key, int value) => _write(key, value);

  @override
  Future<void> setDouble(String key, double value) => _write(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _write(key, List.of(value));

  @override
  Future<void> remove(String key) async {
    await Future<void>.delayed(Duration.zero);
    if (writeError case final error?) throw error;
    _values.remove(key);
    savedPreferences.remove(key);
  }
}
''';
}

/// A feature for the tests with one route, `/<name>`, which can start the
/// app, and whose screen is `<Name>Screen`.
final class StartFeature extends SmfModule {
  /// Creates the feature [name].
  const StartFeature(this.name);

  /// The id of the feature and the name of its route.
  final String name;

  /// The id of the module.
  ModuleId get id => ModuleId(name);

  String get _screen => '${name[0].toUpperCase()}${name.substring(1)}Screen';

  String get _screenFile => 'features/$name/${name}_screen.dart';

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'The feature $name (test)',
        kind: ModuleKinds.feature,
      );

  @override
  List<Contribution> contribute(ModuleContext context) {
    final tag = RouterRole.screenAnnotations((feature: id, screen: _screen));
    return [
      BrickContribution(
        _bundle(name, {
          'lib/$_screenFile': [
            "import 'package:flutter/widgets.dart';",
            '',
            '/// A screen of the tests.',
            '{{{${tag.tag}}}}',
            'class $_screen extends StatelessWidget {',
            '  /// Creates the screen.',
            '  const $_screen({super.key});',
            '',
            '  @override',
            '  Widget build(BuildContext context) => const SizedBox();',
            '}',
            '',
          ].join('\n'),
        }),
      ),
      routerRole.data(
        RoutesData([
          Route(
            '/',
            name: name,
            screen: ScreenRef(_screen, import: ImportRef.app(_screenFile)),
            startCandidate: true,
          ),
        ]),
      ),
    ];
  }
}
