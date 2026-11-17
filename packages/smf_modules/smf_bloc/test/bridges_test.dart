import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_bloc/src/agents.dart';
import 'package:smf_bloc/src/bridges.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_material_theme/smf_material_theme.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';

/// The modules of the tests: this one, flutter_core, which creates the app
/// it becomes a part of, the theme and the languages of the app, whose
/// templates give the state management role a value each that a controller
/// keeps, and the preferences that both require.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  BlocModule(),
  MaterialThemeModule(),
  GenL10nModule(),
  SharedPreferencesModule(),
];

/// The widgets library of Flutter.
const _widgets = 'package:flutter/widgets.dart';

/// The library of BLoC that the code of the module imports.
const _bloc = 'package:flutter_bloc/flutter_bloc.dart';

/// The path of the file of the cubits that follow those values.
const _bridges = 'lib/core/state/shared_state_cubits.dart';

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
///
/// The harness builds no case of such an app itself: the templates of the
/// theme and of the languages only feed the state management role, and a
/// feeder gets no case for a role that it feeds.
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

/// The widgets that this module puts around the root widget of the app of
/// [result], from the outermost, each as the code that opens it: its
/// contributions to the root wrappers of the app entry, which the provider
/// of the app entry renders around the root widget, whichever module it is.
List<String> _ownRootWrappersOf(ContractResult result) => [
      for (final collected in result
              .app!.socketOrders[AppEntryRole.rootWrappers]?.contributions ??
          const <Collected>[])
        if (collected.origin == const ModuleOrigin(BlocModule.id))
          (collected.contribution as SocketContribution).fragment!.code,
    ];

void main() {
  group('an app with BLoC, the theme and the languages', () {
    late ContractResult result;
    late ContractResult withoutValues;
    late RenderedApp app;

    setUpAll(() async {
      result = await _resultOf(const [
        BlocModule.id,
        MaterialThemeModule.id,
        GenL10nModule.id,
        SharedPreferencesModule.id,
      ]);
      app = result.app!;
      withoutValues = await _resultOf(const [BlocModule.id]);
    });

    test(
        'gives the state management role the theme mode and the language, '
        'which the templates of their roles keep', () {
      final input = stateManagementRole.hookInput(result.hook!);

      expect(
        [
          for (final entry in stateManagementRole.sharedStateIn(input))
            '${entry.name} of ${entry.owner}',
        ],
        ['themeMode of role:theme', 'localizationLocale of role:localization'],
      );
      expect(stateManagementRole.bridgesIn(input), isA<BlocBridges>());
    });

    test(
        'tells coding agents where the cubits are and what provides them, '
        'after the note of the module, with names that the file of the '
        'cubits has', () {
      const bloc = ModuleOrigin(BlocModule.id);
      final notes = [
        for (final (from, heading, note)
            in app.entriesOf(AppEntryRole.agentSections))
          if (from == bloc) (heading, note),
      ];
      final note = bridgesAgentNote('ThemeModeCubit');

      expect(notes, [
        ('State management', AgentNote(agentNote)),
        ('State management', AgentNote(note)),
      ]);
      expect(_codeOf(note), {
        _bridges,
        AppEntryRole.mainFile,
        // The cubit of the first value of the app, as an example.
        'ThemeModeCubit',
        'SharedStateCubits',
        'context.watch',
      });
      expect(app.files[_bridges]!.text, contains('class SharedStateCubits '));
      expect(
        bridgesAgentNote('LocalizationLocaleCubit'),
        contains('such as `LocalizationLocaleCubit`, which'),
      );
    });

    test(
        'reads a cubit in the code that the test of the role builds, as a '
        'widget of the app reads it', () {
      final input = stateManagementRole.hookInput(result.hook!);
      final bridges = stateManagementRole.bridgesIn(input)!;
      final watch = bridges.watch(ThemeRole.modeState, '(value) => child');
      final name = RegExp(r'^name: (\S+)$', multiLine: true)
          .firstMatch(app.files['pubspec.yaml']!.text)![1]!;
      final code = [
        for (final import in watch.imports) import.toDirective(name),
        '',
        'final watcher = ${watch.code};',
      ].join('\n');

      expect(DartFileIndexer.errorsOf(code), isEmpty);
      expect(
        watch.code,
        [
          'Builder(builder: (context) => ((value) => child)',
          '(context.watch<bridges.ThemeModeCubit>().state))',
        ].join(),
      );
      expect(
        [for (final import in watch.imports) import.toDirective(name)],
        [
          "import '$_widgets' show Builder;",
          "import '$_bloc';",
          "import 'package:$name/${_bridges.substring(4)}' as bridges;",
        ],
      );
    });

    test(
        'has a cubit for the theme mode and one for the language, and the '
        'widget that provides them, in a file of the module that parses', () {
      final file = app.files[_bridges];
      expect(
        file,
        isNotNull,
        reason: 'The theme mode and the language that their controllers '
            'keep need cubits that follow them.',
      );
      expect(file!.owner, const ModuleOrigin(BlocModule.id));
      final (:index, :errors) = DartFileIndexer.parse(_bridges, file.text);
      expect(errors, isEmpty);
      expect(
        [for (final declaration in index.declarations) declaration.name],
        [
          'ThemeModeCubit',
          'LocalizationLocaleCubit',
          'SharedStateCubits',
          'ListenableCubit',
        ],
      );
      // Each cubit follows the listenable of its value, and the widget
      // creates each when it is first read.
      expect(
        file.text,
        allOf(
          contains(
            'final class ThemeModeCubit extends '
            'ListenableCubit<state0.ThemeMode> {\n'
            '  /// Creates the cubit, with the value that the controller '
            'has.\n'
            '  ThemeModeCubit() : super(state1.themeModeListenable());\n'
            '}',
          ),
          contains(
            'final class LocalizationLocaleCubit extends '
            'ListenableCubit<state2.Locale?> {\n'
            '  /// Creates the cubit, with the value that the controller '
            'has.\n'
            '  LocalizationLocaleCubit() : '
            'super(state3.localizationLocaleListenable());\n'
            '}',
          ),
          contains(
            '    providers: [\n'
            '      BlocProvider(create: (_) => ThemeModeCubit()),\n'
            '      BlocProvider(create: (_) => LocalizationLocaleCubit()),\n'
            '    ],\n',
          ),
        ),
      );
    });

    test(
        'imports the library of each type and function once, with a prefix '
        'of its own', () {
      final index = DartFileIndexer.index(_bridges, app.files[_bridges]!.text);
      final name = RegExp(r'^name: (\S+)$', multiLine: true)
          .firstMatch(app.files['pubspec.yaml']!.text)![1];

      expect(
        [
          for (final import in index.imports)
            '${import.uri} ${import.prefix ?? '-'} ${import.show.join(',')}',
        ],
        // In the order of their URIs, the app of the harness first.
        [
          'package:$name/core/l10n/app_locale.dart state3 ',
          'package:$name/core/theme/theme_mode.dart state1 ',
          'package:flutter/foundation.dart - ValueListenable',
          'package:flutter/material.dart state0 ',
          // Its own names come without a prefix, and the type of a value
          // with one, which can be of the same library.
          '$_widgets - BuildContext,StatelessWidget,Widget',
          '$_widgets state2 ',
          '$_bloc - BlocProvider,Cubit,MultiBlocProvider',
        ],
      );
    });

    test('provides the cubits around the root widget of the app', () {
      expect(_ownRootWrappersOf(result), ['SharedStateCubits(child: ']);
    });

    test(
        'has neither the file of the cubits, nor the widget, nor their note '
        'without values', () {
      expect(withoutValues.app!.files.keys, isNot(contains(_bridges)));
      expect(_ownRootWrappersOf(withoutValues), isEmpty);
      expect(
        [
          for (final (from, _, note)
              in withoutValues.app!.entriesOf(AppEntryRole.agentSections))
            if (from == const ModuleOrigin(BlocModule.id)) note,
        ],
        [AgentNote(agentNote)],
      );
    });
  });
}
