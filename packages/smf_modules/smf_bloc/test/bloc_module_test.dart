import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_bloc/src/agents.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: this one, and flutter_core, which creates the
/// app it becomes a part of.
const List<SmfModule> _modules = [FlutterCoreModule(), BlocModule()];

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

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

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
    late ContractResult result;
    late RenderedApp withBloc;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [BlocModule.id]);
      withBloc = result.app!;
      without = (await _resultOf(const [FlutterCoreModule.id])).app!;
    });

    test(
        'gets flutter_bloc and its note for coding agents from it, and '
        'nothing else', () {
      final contributions = [
        for (final collected in result.collection!.ofModule(BlocModule.id))
          collected.contribution,
      ];

      expect(contributions, hasLength(2));
      final dependency = contributions.first as PubspecDependency;
      expect(dependency.package, 'flutter_bloc');
      expect(dependency.constraint, '^9.1.1');
      expect(dependency.dev, isFalse);
      final note = contributions.last as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, stateManagementRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });

    test(
        'has the section of the state management in its guide for coding '
        'agents, which is the note of the module', () {
      const bloc = ModuleOrigin(BlocModule.id);
      final notes = withBloc.entriesOf(AppEntryRole.agentSections);

      // The role has no template, so the module says all of the section.
      expect(stateManagementRole.template, isNull);
      expect(
        notes.where((note) => note.$1 != bloc),
        without.entriesOf(AppEntryRole.agentSections),
      );
      expect(
        notes.where((note) => note.$1 == bloc),
        [(bloc, 'State management', AgentNote(agentNote))],
      );
      expect(
        withBloc.files[AppEntryRole.agentsFile]!.text,
        endsWith('\n## State management\n\n$agentNote'),
      );
      // The package of the module, whose classes the note names.
      expect(agentNote, startsWith('With `flutter_bloc`:\n'));
      expect(_pubspecOf(withBloc)['dependencies'], contains('flutter_bloc'));
    });

    test(
        'tells in its note how a screen with state, state that several '
        'screens read and an awaited call are written, with these names of '
        'the package and no other code', () {
      // The paths of the note are for the rule of the app entry role,
      // which finds each of them in every app that the harness renders.
      final code = _codeOf(agentNote).where((span) => !span.contains('/'));

      expect(code.toSet(), {
        'flutter_bloc',
        // What holds the state of a screen, what provides it, and what
        // builds the view of the screen from it.
        'Cubit',
        'BlocProvider',
        'BlocBuilder',
        // Where the provider of state that several screens read goes, and
        // how a widget reads that state.
        'runApp()',
        'context.watch',
        // What a cubit minds after a call that it awaited.
        'await',
        'isClosed',
        'emit()',
      });
      // No file of this app is written with the package, so none shows
      // these names. A module with screens writes such code in its variant
      // for this one, and the tests of a registry with such a module look
      // up there each name that the note gives.
      expect(
        [
          for (final file in withBloc.files.values)
            if (file.isText && file.text.contains('package:flutter_bloc/'))
              file.path,
        ],
        isEmpty,
      );
    });

    test('depends on flutter_bloc 9', () {
      expect(_pubspecOf(withBloc)['dependencies'], {
        'flutter': {'sdk': 'flutter'},
        'flutter_bloc': '^9.1.1',
      });
    });

    test(
        'is the app without BLoC but for that dependency and the section of '
        'the guide for coding agents', () {
      expect(withBloc.files.keys, orderedEquals(without.files.keys));
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (path == 'pubspec.yaml' || path == AppEntryRole.agentsFile) continue;
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
