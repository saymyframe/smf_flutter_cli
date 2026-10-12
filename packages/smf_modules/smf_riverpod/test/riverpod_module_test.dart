import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:smf_riverpod/src/agents.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: this one, and flutter_core, which creates the
/// app it becomes a part of.
const List<SmfModule> _modules = [FlutterCoreModule(), RiverpodModule()];

const _widgets = ImportRef('package:flutter/widgets.dart');

/// A module that requires the state management role and wraps the root
/// widget, as a module with variants for the providers of the role may do.
/// Its id comes before `riverpod`.
final class _StateUser extends SmfModule {
  const _StateUser();

  static const id = ModuleId('a_state_user');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Uses the state management',
        kind: ModuleKinds.infrastructure,
        requires: {stateManagementRole},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => const [
        SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap('RepaintBoundary(child: ', ')', imports: [_widgets]),
        ),
      ];
}

/// A module that depends on this one and wraps the root widget. Its id
/// comes before `riverpod`.
final class _RiverpodUser extends SmfModule {
  const _RiverpodUser();

  static const id = ModuleId('a_riverpod_user');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Uses Riverpod',
        kind: ModuleKinds.infrastructure,
        dependsOn: {RiverpodModule.id},
      );

  @override
  List<Contribution> contribute(ModuleContext context) => const [
        SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap('KeyedSubtree(child: ', ')', imports: [_widgets]),
        ),
      ];
}

/// A module with a variant for this one, as a module with screens has,
/// which wraps the root widget in a `Consumer` that reads providers. Its id
/// comes before `riverpod`.
final class _VariantUser extends SmfModule {
  const _VariantUser();

  static const id = ModuleId('a_variant_user');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Reads providers',
        // Infrastructure has no variants; a kind is data.
        kind: ModuleKind(id: 'with_variants', label: 'With variants'),
        variants: Variants(
          role: stateManagementRole,
          byProvider: {RiverpodModule.id: _withRiverpod},
        ),
      );

  static List<Contribution> _withRiverpod(ModuleContext context) => const [
        PubspecContribution.hosted('flutter_riverpod', 'any'),
        SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            'Consumer(builder: (context, ref, child) => child!, child: ',
            ')',
            imports: [
              ImportRef(
                'package:flutter_riverpod/flutter_riverpod.dart',
                show: ['Consumer'],
              ),
            ],
          ),
        ),
      ];
}

/// What the contract harness finds for the app of [modules] among
/// [registry], which has no errors and is rendered.
Future<ContractResult> _resultOf(
  List<ModuleId> modules, {
  List<SmfModule> registry = _modules,
}) async {
  final result = await ContractHarness(ModuleRegistry(registry)).check(
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

/// The widgets that the modules of the app of [result] put around its root
/// widget, from the outermost, each as its contributor and the code that
/// opens it: the contributions to the root wrappers of the app entry, which
/// its provider renders around the root widget in `runApp()`, whichever
/// module it is.
List<String> _rootWrappersOf(ContractResult result) => [
      for (final collected in result
              .app!.socketOrders[AppEntryRole.rootWrappers]?.contributions ??
          const <Collected>[])
        [
          '${collected.origin}:',
          (collected.contribution as SocketContribution).fragment!.code,
        ].join(' '),
    ];

/// The imports that the pipeline adds for the code of this module to the
/// files of [app], each as the owner of its file and the import.
List<String> _importsOfModuleIn(RenderedApp app) => [
      for (final file in app.files.values)
        for (final added in file.addedImports)
          if (added.contributor == const ModuleOrigin(RiverpodModule.id))
            [
              '${file.owner}:',
              added.import.uri,
              'as ${added.import.prefix}',
              'show ${added.import.show.join(', ')}',
            ].join(' '),
    ];

/// Whether the pipeline put code of this module into [file], whose imports
/// it added to the file.
bool _holdsCodeOfModule(RenderedFile file) => file.addedImports
    .any((added) => added.contributor == const ModuleOrigin(RiverpodModule.id));

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

void main() {
  const module = RiverpodModule();

  group('RiverpodModule', () {
    test('is infrastructure that provides the state management', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('riverpod'));
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

    test('builds the app with Riverpod and the app without it', () {
      expect(
        results.map((result) => result.contractCase.name),
        containsAll(['flutter_core', 'riverpod']),
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

  group('an app with Riverpod', () {
    late ContractResult result;
    late ContractResult resultWithout;
    late RenderedApp withRiverpod;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [RiverpodModule.id]);
      withRiverpod = result.app!;
      resultWithout = await _resultOf(const [FlutterCoreModule.id]);
      without = resultWithout.app!;
    });

    test(
        'gets flutter_riverpod, the ProviderScope and its note for coding '
        'agents from it, and nothing else', () {
      final contributions = [
        for (final collected in result.collection!.ofModule(RiverpodModule.id))
          collected.contribution,
      ];

      expect(contributions, hasLength(3));
      final dependency = contributions.first as PubspecDependency;
      expect(dependency.package, 'flutter_riverpod');
      expect(dependency.constraint, '^3.4.3');
      expect(dependency.dev, isFalse);
      final wrapper = contributions[1] as SocketContribution;
      expect(wrapper.socket, AppEntryRole.rootWrappers);
      expect(wrapper.fragment!.code, 'ProviderScope(child: ');
      expect(wrapper.fragment!.closing, ')');
      final note = contributions.last as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, stateManagementRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });

    test(
        'has the section of the state management in its guide for coding '
        'agents, which is the note of the module', () {
      const riverpod = ModuleOrigin(RiverpodModule.id);
      final notes = withRiverpod.entriesOf(AppEntryRole.agentSections);

      // The role has no template, so the module says all of the section.
      expect(stateManagementRole.template, isNull);
      expect(
        notes.where((note) => note.$1 != riverpod),
        without.entriesOf(AppEntryRole.agentSections),
      );
      expect(
        notes.where((note) => note.$1 == riverpod),
        [(riverpod, 'State management', AgentNote(agentNote))],
      );
      expect(
        withRiverpod.files[AppEntryRole.agentsFile]!.text,
        endsWith('\n## State management\n\n$agentNote'),
      );
      // The package of the module, without a generator of providers, and
      // the scope that the module puts around the root widget.
      expect(agentNote, startsWith('With `flutter_riverpod`:\n'));
      final pubspec = _pubspecOf(withRiverpod);
      expect(pubspec['dependencies'], contains('flutter_riverpod'));
      for (final packages in [
        pubspec['dependencies'],
        pubspec['dev_dependencies'],
      ]) {
        expect(
          (packages! as Map<String, Object?>).keys,
          everyElement(isNot(anyOf(contains('generator'), 'build_runner'))),
        );
      }
      expect(_rootWrappersOf(result).single, contains('ProviderScope('));
      expect(agentNote, contains('`ProviderScope` is around the root widget'));
    });

    test(
        'tells in its note how a screen with state, state that several '
        'screens read and an awaited call are written, with these names of '
        'the package and no other code', () {
      // The paths of the note are for the rule of the app entry role,
      // which finds each of them in every app that the harness renders.
      final code = _codeOf(agentNote).where((span) => !span.contains('/'));

      expect(code.toSet(), {
        'flutter_riverpod',
        // What holds the state of a screen for as long as the screen
        // lasts, and how the widget of the screen reads it.
        'NotifierProvider.autoDispose',
        'Notifier',
        'ConsumerWidget',
        'ref.watch',
        // What holds state that several screens read, and what it lasts as
        // long as.
        'autoDispose',
        'NotifierProvider',
        'ProviderScope',
        // What a notifier minds around a call that it awaits.
        'await',
        'ref.mounted',
        'state',
        'ref',
        // Where the scope is.
        'runApp()',
      });
      // Of this app, only the file with the scope is written with the
      // package, so no file shows the other names. A module with screens
      // writes such code in its variant for this one, and the tests of a
      // registry with such a module look up there each name that the note
      // gives.
      final withPackage = [
        for (final file in withRiverpod.files.values)
          if (file.isText && file.text.contains('package:flutter_riverpod/'))
            file,
      ];
      expect(withPackage, hasLength(1));
      expect(_holdsCodeOfModule(withPackage.single), isTrue);
    });

    test('runs the app inside a ProviderScope', () {
      expect(_rootWrappersOf(result), ['riverpod: ProviderScope(child: ']);
      expect(_rootWrappersOf(resultWithout), isEmpty);
      // Only the name of the scope, in the file of the app entry that wraps
      // the root widget, whichever module provides the app entry.
      final entry = result.resolution!.providersOf(appEntryRole).single.id;
      expect(_importsOfModuleIn(withRiverpod), [
        [
          '$entry:',
          'package:flutter_riverpod/flutter_riverpod.dart',
          'as null show ProviderScope',
        ].join(' '),
      ]);
    });

    test('depends on flutter_riverpod 3', () {
      expect(_pubspecOf(withRiverpod)['dependencies'], {
        'flutter': {'sdk': 'flutter'},
        'flutter_riverpod': '^3.4.3',
      });
    });

    test(
        'is the app without Riverpod but for the scope, the dependency and '
        'the section of the guide for coding agents', () {
      expect(withRiverpod.files.keys, orderedEquals(without.files.keys));
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        // The file that holds the scope, which the test above checks.
        if (path == 'pubspec.yaml' ||
            path == AppEntryRole.agentsFile ||
            _holdsCodeOfModule(withRiverpod.files[path]!)) {
          continue;
        }
        expect(withRiverpod.files[path]!.bytes, file.bytes, reason: path);
        expect(withRiverpod.files[path]!.owner, file.owner, reason: path);
      }

      final pubspec = _pubspecOf(withRiverpod);
      final dependencies = {
        ...pubspec['dependencies']! as Map<String, Object?>,
      }..remove('flutter_riverpod');
      expect(
        {...pubspec, 'dependencies': dependencies},
        _pubspecOf(without),
      );
    });

    test(
        'has the root wrappers of modules that can use Riverpod inside the '
        'ProviderScope', () async {
      final result = await _resultOf(
        const [_StateUser.id, _RiverpodUser.id, _VariantUser.id],
        registry: const [
          ..._modules,
          _StateUser(),
          _RiverpodUser(),
          _VariantUser(),
        ],
      );

      expect(
        result.resolution!.module(_VariantUser.id)!.variant,
        RiverpodModule.id,
      );
      expect(_rootWrappersOf(result), [
        'riverpod: ProviderScope(child: ',
        'a_riverpod_user: KeyedSubtree(child: ',
        'a_state_user: RepaintBoundary(child: ',
        [
          'a_variant_user (riverpod):',
          'Consumer(builder: (context, ref, child) => child!, child: ',
        ].join(' '),
      ]);
    });
  });
}
