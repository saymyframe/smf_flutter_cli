import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: this one, and flutter_core, which creates the
/// app it becomes a part of.
const List<SmfModule> _modules = [FlutterCoreModule(), BlocModule()];

/// The app of [modules] that the contract harness renders, which has no
/// errors.
Future<RenderedApp> _appOf(List<ModuleId> modules) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  final app = result.app;
  if (result.errors.isNotEmpty || app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return app;
}

/// The pubspec of [app] as plain maps and lists.
Map<String, Object?> _pubspecOf(RenderedApp app) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(app.files['pubspec.yaml']!.text))!
      as Map<String, Object?>;
}

void main() {
  const module = BlocModule();

  group('BlocModule', () {
    test('is infrastructure that provides the state management', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('bloc'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {stateManagementRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the provider of the app entry', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the app with BLoC and the app without it', () {
      expect(
        results.map((result) => result.contractCase.name),
        containsAll(['flutter_core', 'bloc']),
      );
    });

    test('finds no errors in any app, rendered code included', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });
  });

  group('an app with BLoC', () {
    late RenderedApp withBloc;
    late RenderedApp without;

    setUpAll(() async {
      withBloc = await _appOf(const [BlocModule.id]);
      without = await _appOf(const [FlutterCoreModule.id]);
    });

    test('depends on flutter_bloc 9', () {
      expect(_pubspecOf(withBloc)['dependencies'], {
        'flutter': {'sdk': 'flutter'},
        'flutter_bloc': '^9.1.1',
      });
    });

    test('is the app without BLoC but for that dependency', () {
      expect(withBloc.files.keys, orderedEquals(without.files.keys));
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (path == 'pubspec.yaml') continue;
        expect(withBloc.files[path]!.bytes, file.bytes, reason: path);
        expect(withBloc.files[path]!.owner, file.owner, reason: path);
      }

      final pubspec = _pubspecOf(withBloc);
      final dependencies = {...pubspec['dependencies']! as Map<String, Object?>}
        ..remove('flutter_bloc');
      expect(
        {...pubspec, 'dependencies': dependencies},
        _pubspecOf(without),
      );
    });
  });
}
