import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_material_theme/smf_material_theme.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:smf_riverpod/src/agents.dart';
import 'package:smf_riverpod/src/bridges.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';

/// The modules of the tests: this one, flutter_core, which creates the app
/// it becomes a part of, the theme and the languages of the app, whose
/// templates give the state management role a value each that a controller
/// keeps, and the preferences that both require.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  RiverpodModule(),
  MaterialThemeModule(),
  GenL10nModule(),
  SharedPreferencesModule(),
];

/// The library of Riverpod that the code of the module imports.
const _riverpod = 'package:flutter_riverpod/flutter_riverpod.dart';

/// The path of the file of the providers that follow those values.
const _bridges = 'lib/core/state/shared_state_providers.dart';

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

void main() {
  group('an app with Riverpod, the theme and the languages', () {
    late ContractResult result;
    late RenderedApp app;
    late RenderedApp withoutValues;

    setUpAll(() async {
      result = await _resultOf(const [
        RiverpodModule.id,
        MaterialThemeModule.id,
        GenL10nModule.id,
        SharedPreferencesModule.id,
      ]);
      app = result.app!;
      withoutValues = (await _resultOf(const [RiverpodModule.id])).app!;
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
      expect(stateManagementRole.bridgesIn(input), isA<RiverpodBridges>());
    });

    test(
        'has a provider for the theme mode and one for the language, in a '
        'file of the module that parses', () {
      final file = app.files[_bridges];
      expect(
        file,
        isNotNull,
        reason: 'The theme mode and the language that their controllers '
            'keep need providers that follow them.',
      );
      expect(file!.owner, const ModuleOrigin(RiverpodModule.id));
      final (:index, :errors) = DartFileIndexer.parse(_bridges, file.text);
      expect(errors, isEmpty);
      expect(
        [for (final declaration in index.declarations) declaration.name],
        [
          'themeModeProvider',
          'localizationLocaleProvider',
          'ListenableNotifier',
        ],
      );
      // Each provider is a NotifierProvider of the notifier that follows the
      // listenable of its value.
      expect(
        file.text,
        allOf(
          contains(
            'final NotifierProvider<ListenableNotifier<state0.ThemeMode>, '
            'state0.ThemeMode>\nthemeModeProvider = NotifierProvider(\n'
            '  () => ListenableNotifier(state1.themeModeListenable),\n);',
          ),
          contains(
            'final NotifierProvider<ListenableNotifier<state2.Locale?>, '
            'state2.Locale?>\nlocalizationLocaleProvider = NotifierProvider(\n'
            '  () => ListenableNotifier(state3.localizationLocaleListenable),\n'
            ');',
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
          'package:flutter/widgets.dart state2 ',
          '$_riverpod - Notifier,NotifierProvider',
        ],
      );
    });

    test(
        'tells coding agents where the providers are, after the note of the '
        'module, with names that the file of the providers has', () {
      const riverpod = ModuleOrigin(RiverpodModule.id);
      final notes = [
        for (final (from, heading, note)
            in app.entriesOf(AppEntryRole.agentSections))
          if (from == riverpod) (heading, note),
      ];
      final note = bridgesAgentNote('themeModeProvider');

      expect(notes, [
        ('State management', AgentNote(agentNote)),
        ('State management', AgentNote(note)),
      ]);
      expect(_codeOf(note), {
        _bridges,
        // The provider of the first value of the app, as an example.
        'themeModeProvider',
        'NotifierProvider',
        'ListenableNotifier',
        'ref.watch',
      });
      final text = app.files[_bridges]!.text;
      for (final name in ['NotifierProvider', 'ListenableNotifier']) {
        expect(text, contains(name));
      }
      // The provider of the first value of the app is the example.
      expect(
        bridgesAgentNote('localizationLocaleProvider'),
        contains('such as `localizationLocaleProvider`, each'),
      );
    });

    test(
        'reads a provider in the code that the test of the role builds, as '
        'a widget of the app reads it', () {
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
        'Consumer(builder: (context, ref, _) => '
        '((value) => child)(ref.watch(bridges.themeModeProvider)))',
      );
      expect(
        [for (final import in watch.imports) import.toDirective(name)],
        [
          "import '$_riverpod' show Consumer;",
          "import 'package:$name/${_bridges.substring(4)}' as bridges;",
        ],
      );
    });

    test(
        'has neither the file of providers nor their note without such '
        'values', () {
      expect(withoutValues.files.keys, isNot(contains(_bridges)));
      expect(
        [
          for (final (from, _, note)
              in withoutValues.entriesOf(AppEntryRole.agentSections))
            if (from == const ModuleOrigin(RiverpodModule.id)) note,
        ],
        [AgentNote(agentNote)],
      );
      expect(
        app.files.keys.toSet().difference(withoutValues.files.keys.toSet()),
        contains(_bridges),
      );
    });
  });
}
