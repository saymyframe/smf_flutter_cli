@TestOn('vm')
library;

import 'package:smf_contracts/lego.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_core/src/preflight/flutterfire_cli.dart';
import 'package:smf_firebase_core/src/readme.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/flutterfire.dart';

/// The modules of the tests: flutter_core, which creates the app, and this
/// module.
const List<SmfModule> _modules = [FlutterCoreModule(), FirebaseCoreModule()];

/// The path of the options of the Firebase apps.
const _options = 'lib/firebase_options.dart';

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> _resultOf(List<ModuleId> modules) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

/// The pubspec [text] as plain maps and lists.
Map<String, Object?> _yamlOf(String text) {
  Object? plain(Object? node) => switch (node) {
        final YamlMap map => {
            for (final MapEntry(:key, :value) in map.entries)
              '$key': plain(value),
          },
        final YamlList list => [for (final item in list) plain(item)],
        _ => node,
      };
  return plain(loadYaml(text))! as Map<String, Object?>;
}

void main() {
  const module = FirebaseCoreModule();

  group('FirebaseCoreModule', () {
    test('is infrastructure without roles or dependencies', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('firebase_core'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.providers, isEmpty);
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the app entry', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, firebase_core, the initialization of '
        'Firebase at start-up and iOS 15', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(
        contributions.whereType<BrickContribution>().single.bundle.name,
        'firebase_core',
      );
      final dependency = contributions.whereType<PubspecDependency>().single;
      expect(dependency.package, 'firebase_core');
      expect(dependency.constraint, '^4.15.0');
      expect(dependency.dev, isFalse);

      final sockets = contributions.whereType<SocketContribution>().toList();
      final start = sockets
          .where((c) => c.socket == AppEntryRole.bootstrapPlatform)
          .single;
      expect(
        start.fragment!.code,
        'await Firebase.initializeApp(options: '
        'DefaultFirebaseOptions.currentPlatform);',
      );
      expect(start.fragment!.imports, const [
        ImportRef('package:firebase_core/firebase_core.dart'),
        ImportRef.app('firebase_options.dart'),
      ]);
      expect(start.when, isEmpty);
      final ios = sockets
          .where((c) => c.socket == AppEntryRole.iosDeploymentTarget)
          .single;
      expect(ios.entryValue, '15.0');
      expect(FirebaseCoreModule.minimumIosVersion, '15.0');
    });

    test(
        'configures Firebase with flutterfire after generation, for the '
        'platforms of the app', () {
      final step = module
          .contribute(ContractHarness.defaultContext)
          .whereType<PostGenStep>()
          .single;

      expect(step.tool, same(flutterfireTool));
      expect(step.tool.executable, 'dart');
      expect(
        step.tool.prefixArgs,
        ['pub', 'global', 'run', 'flutterfire_cli:flutterfire'],
      );
      expect(step.arguments, [
        'configure',
        '--platforms=android,ios',
        '--overwrite-firebase-options',
      ]);
      expect(AppEntryRole.platforms, ['android', 'ios']);
      expect(step.description, 'Configuring Firebase with flutterfire');
      // It asks for the Firebase project, reaches the account of the user,
      // and the app compiles without it.
      expect(step.interactive, isTrue);
      expect(step.external, isTrue);
      expect(step.skippable, isTrue);
      expect(step.when, isEmpty);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the app with Firebase and the one without', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core',
        'firebase_core',
      ]);
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

  group('an app with Firebase', () {
    late RenderedApp withFirebase;
    late RenderedApp without;

    setUpAll(() async {
      withFirebase = (await _resultOf(const [FirebaseCoreModule.id])).app!;
      without = (await _resultOf(const [FlutterCoreModule.id])).app!;
    });

    test(
        'is the app without Firebase but for its options, start-up, README '
        'and firebase_core', () {
      expect(
        withFirebase.files.keys.toSet(),
        {...without.files.keys, _options},
      );
      expect(
        withFirebase.files[_options]!.owner,
        const ModuleOrigin(FirebaseCoreModule.id),
      );
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (const {
          'pubspec.yaml',
          AppEntryRole.bootstrapFile,
          AppEntryRole.readmeFile,
        }.contains(path)) {
          continue;
        }
        expect(withFirebase.files[path]!.bytes, file.bytes, reason: path);
        expect(withFirebase.files[path]!.owner, file.owner, reason: path);
      }

      final pubspec = _yamlOf(withFirebase.files['pubspec.yaml']!.text);
      final dependencies = {
        ...pubspec['dependencies']! as Map<String, Object?>,
      };
      expect(dependencies.remove('firebase_core'), '^4.15.0');
      expect(
        {...pubspec, 'dependencies': dependencies},
        _yamlOf(without.files['pubspec.yaml']!.text),
      );
    });

    test('tells in the README how to configure Firebase', () {
      final readme = withFirebase.files[AppEntryRole.readmeFile]!;

      expect(readme.owner, const ModuleOrigin(FlutterCoreModule.id));
      expect(
        readme.text,
        '${without.files[AppEntryRole.readmeFile]!.text}'
        '\n'
        '## Firebase\n'
        '\n'
        '${readmeSection('flutterfire configure --platforms=android,ios '
            '--overwrite-firebase-options')}',
      );
      expect(
        readme.text,
        allOf(
          contains(
            '```bash\n'
            'dart pub global activate flutterfire_cli\n'
            'firebase login\n'
            'flutterfire configure --platforms=android,ios '
            '--overwrite-firebase-options\n'
            '```\n',
          ),
          contains('run `flutterfire` from `~/.pub-cache/bin`'),
        ),
      );
    });

    test('initializes Firebase with the options of the platform in bootstrap()',
        () {
      final file = withFirebase.files[AppEntryRole.bootstrapFile]!;
      final index = DartFileIndexer.index(file.path, file.text);

      final calls = index.invocations
          .where((call) => call.name == 'initializeApp')
          .toList();
      expect(calls, hasLength(1));
      expect(calls.single.target, 'Firebase');
      expect(calls.single.awaited, isTrue);
      expect(calls.single.enclosingDeclaration, 'bootstrap');
      expect(calls.single.namedArguments, ['options']);
      expect(
        file.text,
        contains(
          'await Firebase.initializeApp(options: '
          'DefaultFirebaseOptions.currentPlatform);',
        ),
      );
      expect(
        [
          for (final added in file.addedImports)
            (added.import.uri, '${added.contributor}'),
        ],
        [
          ('package:firebase_core/firebase_core.dart', 'firebase_core'),
          ('package:contract_app/firebase_options.dart', 'firebase_core'),
        ],
      );
    });

    test(
        'has the options that flutterfire writes for no platform, which name '
        'no Firebase project', () {
      final options = withFirebase.files[_options]!.text;

      expect(options, flutterfirePlaceholder);
      final index = DartFileIndexer.index(_options, options);
      final declarations = index.declarations;
      expect(declarations.map((d) => d.name), ['DefaultFirebaseOptions']);
      expect(options, isNot(contains('static const FirebaseOptions')));
      expect(
        'throw UnsupportedError('.allMatches(options),
        // The web, each of the five platforms of the switch, and the rest.
        hasLength(7),
      );
    });
  });
}
