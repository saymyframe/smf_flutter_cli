@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_gen_l10n/smf_gen_l10n.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_material_theme/bundles/material_theme_bundle.dart';
import 'package:smf_material_theme/smf_material_theme.dart';
import 'package:smf_material_theme/src/agents.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:test/test.dart';

import 'support/dart_app.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, shared_preferences, in which the app remembers the theme mode,
/// the settings screen, which shows the entry of the mode, with go_router,
/// which renders its route, and gen_l10n, which reads the texts of the
/// entry in the language of the app.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  GoRouterModule(),
  SharedPreferencesModule(),
  SettingsModule(),
  GenL10nModule(),
  MaterialThemeModule(),
];

/// The owners of the code of the theme: the template of the role and this
/// module.
final Set<ContributionOrigin> _theme = {
  const RoleTemplateOrigin(themeRole),
  const ModuleOrigin(MaterialThemeModule.id),
};

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

/// The modules that provide [role] in the app of [result], whichever they
/// are.
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

/// The contributions to [socket] in the app of [result], those of the
/// render hooks of the roles included, in the order they were rendered,
/// each as its contributor and its code.
List<String> _contributionsTo(ContractResult result, SocketRef socket) => [
      for (final collected in result.app!.socketOrders[socket]?.contributions ??
          const <Collected>[])
        _described(collected),
    ];

/// The contribution [collected] to a socket as its contributor and its code.
String _described(Collected collected) {
  final contribution = collected.contribution as SocketContribution;
  return '${collected.origin}: ${contribution.fragment!.code}';
}

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// Whether [a] and [b] are the same bytes.
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// The parsed file of the themes of [app].
CompilationUnit _themesOf(RenderedApp app) =>
    parseString(content: app.files[ThemeRole.appThemeFile]!.text).unit;

/// The top-level functions of [unit], by name.
Map<String, FunctionDeclaration> _functionsOf(CompilationUnit unit) => {
      for (final function in unit.declarations.whereType<FunctionDeclaration>())
        function.name.lexeme: function,
    };

/// Creates the two themes of the app with a context of the script, and
/// sends back what each is: its brightness, whether its colours derive from
/// the seed colour of the file, and whether it is of Material 3.
///
/// It imports only the file of the themes, which needs nothing but the
/// stand-in for Flutter's material library.
const _script = '''
import 'dart:isolate';

import 'package:contract_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class Root implements BuildContext {}

List<Object?> described(ThemeData theme) => [
  theme.brightness.name,
  theme.colorScheme.brightness.name,
  identical(theme.colorScheme.seed, seedColor),
  theme.useMaterial3,
];

void main(List<String> arguments, SendPort port) {
  final context = Root();
  port.send({
    'seed': seedColor.value,
    'light': described(createLightTheme(context)),
    'dark': described(createDarkTheme(context)),
    // The root of the app calls them each time it builds.
    'created anew': !identical(
      createLightTheme(context),
      createLightTheme(context),
    ),
  });
}
''';

void main() {
  const module = MaterialThemeModule();

  group('MaterialThemeModule', () {
    test(
        'is infrastructure that provides the theme role, and so requires '
        'the preferences and uses the settings screen and the localization '
        'as the role does', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('material_theme'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {themeRole});
      expect(descriptor.dependsOn, isEmpty);
      // Nothing of its own: what it requires and uses is what the role does.
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.effectiveRequires, {preferencesRole});
      expect(
        descriptor.effectiveUses,
        {settingsScreenRole, localizationRole},
      );
      expect(descriptor.variants, isNull);
      expect(descriptor.sockets, isEmpty);
      expect(descriptor.socketFamilies, isEmpty);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, with the file of the themes, and its note '
        'for coding agents, and nothing else: no package, no data of a '
        'role and no code for a socket', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(2));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(materialThemeBundle));
      expect(brick.bundle.name, 'material_theme');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [ThemeRole.appThemeFile],
      );
      expect(brick.vars, isEmpty);
      expect(brick.when, isEmpty);
      final note = contributions[1] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, themeRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
    });
  });

  group('the contract harness', () {
    late ContractHarness harness;
    late List<ContractResult> results;

    setUpAll(() async {
      harness = ContractHarness(ModuleRegistry(_modules));
      results = await harness.checkAll();
    });

    test(
        'builds the apps of the theme with a settings screen and with the '
        'localization, and without each, all with the preferences that the '
        'role requires', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core with router',
        'flutter_core',
        'shared_preferences',
        // The settings screen reads its title from the texts of the app, and
        // the localization has its setting on that screen: one app.
        'settings with localization',
        'settings',
        'gen_l10n',
        'material_theme with settings_screen, localization',
        'material_theme with settings_screen',
        'material_theme with localization',
        'material_theme',
      ]);
      for (final result in results) {
        if (!result.contractCase.name.startsWith('material_theme')) continue;
        expect(
          _providersOf(result, preferencesRole),
          isNotEmpty,
          reason: '${result.contractCase}',
        );
      }
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

    test(
        'checks the module with every provider of the roles that the theme '
        'role requires or uses', () async {
      expect(await harness.uncheckedProviders(), isEmpty);
    });

    test(
        'renders a file of the themes that type-checks against a stand-in '
        'for the material library of Flutter', () async {
      final withTheme = [
        for (final result in results)
          if (result.app!.files.containsKey(ThemeRole.appThemeFile)) result,
      ];
      expect(withTheme, hasLength(4));
      for (final result in withTheme) {
        final app = DartApp.write(result.app!);
        try {
          expect(
            await app.analysisProblems(
              {const ModuleOrigin(MaterialThemeModule.id)},
            ),
            isEmpty,
            reason: '${result.contractCase}',
          );
        } finally {
          app.delete();
        }
      }
    });
  });

  group('an app with the module', () {
    late ContractResult result;
    late RenderedApp withTheme;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(const [MaterialThemeModule.id]);
      withTheme = result.app!;
      // The preferences, which the role requires, are the only module that
      // the app gets with the theme.
      without = (await _resultOf(const [SharedPreferencesModule.id])).app!;
    });

    test(
        'is the app without the theme but for the file of the themes, the '
        'file of the theme mode, the section of the theme in the guide for '
        'coding agents, and what the root of the app and the preferences '
        'need to follow and to remember the mode: it adds no package', () {
      expect(
        withTheme.files.keys.toSet(),
        {
          ...without.files.keys,
          ThemeRole.themeModeFile,
          ThemeRole.appThemeFile,
        },
      );
      expect(
        withTheme.files[ThemeRole.appThemeFile]!.owner,
        const ModuleOrigin(MaterialThemeModule.id),
      );
      expect(
        withTheme.files[ThemeRole.themeModeFile]!.owner,
        const RoleTemplateOrigin(themeRole),
      );
      // The files that changed are those of the provider of the app entry,
      // whose root takes the themes and the mode, and the file of the
      // preferences role, which restores the mode.
      final appEntry = _providersOf(result, appEntryRole);
      final changed = <ContributionOrigin>{};
      for (final MapEntry(key: path, value: file) in without.files.entries) {
        if (path == AppEntryRole.agentsFile) continue;
        expect(withTheme.files[path]!.owner, file.owner, reason: path);
        if (!_sameBytes(withTheme.files[path]!.bytes, file.bytes)) {
          expect(path, isNot('pubspec.yaml'));
          changed.add(file.owner);
        }
      }
      expect(changed, {
        for (final id in appEntry) ModuleOrigin(id),
        const RoleTemplateOrigin(preferencesRole),
      });
      // The guide has the notes of the app without the theme, and in the
      // section of the theme what the role says and what the module adds.
      final notes = withTheme.entriesOf(AppEntryRole.agentSections);
      expect(
        notes.where((note) => !_theme.contains(note.$1)),
        without.entriesOf(AppEntryRole.agentSections),
      );
      expect(
        [
          for (final (origin, heading, note) in notes)
            if (_theme.contains(origin)) (origin, heading, note.isOfRole),
        ],
        unorderedEquals([
          (
            const ModuleOrigin(MaterialThemeModule.id),
            themeRole.description,
            false,
          ),
          (const RoleTemplateOrigin(themeRole), themeRole.description, true),
        ]),
      );
      expect(
        [
          for (final (origin, _, note) in notes)
            if (origin == const ModuleOrigin(MaterialThemeModule.id)) note,
        ],
        [AgentNote(agentNote)],
      );
    });

    test(
        'has the themes and the mode of the root of the app, the scope '
        'around it and the restorer of the mode from the role, and nothing '
        'of them from the module', () {
      expect(_contributionsTo(result, AppEntryRole.appArgs), [
        'role:theme: ${ThemeRole.createLightTheme.name}(context)',
        'role:theme: ${ThemeRole.createDarkTheme.name}(context)',
        'role:theme: AppThemeModeScope.of(context)',
      ]);
      for (final socket in const [
        AppEntryRole.rootWrappers,
        PreferencesRole.restorers,
      ]) {
        expect(
          _contributionsTo(result, socket),
          [startsWith('role:theme: ')],
          reason: '$socket',
        );
      }
    });

    group('the file of the themes', () {
      late CompilationUnit unit;
      late Map<String, FunctionDeclaration> functions;

      setUpAll(() {
        unit = _themesOf(withTheme);
        functions = _functionsOf(unit);
      });

      test(
          'has the seed colour, the two functions of the role, which take '
          'the context of the root, and the function that builds both '
          'themes, and imports only the material library of Flutter', () {
        expect(
          [
            for (final directive in unit.directives) '$directive',
          ],
          ["import 'package:flutter/material.dart';"],
        );
        final seed = unit.declarations
            .whereType<TopLevelVariableDeclaration>()
            .single
            .variables;
        expect(seed.isConst, isTrue);
        expect('${seed.type}', 'Color');
        expect(seed.variables.single.name.lexeme, 'seedColor');
        expect('${seed.variables.single.initializer}', 'Colors.deepPurple');
        expect(functions.keys, [
          ThemeRole.createLightTheme.name,
          ThemeRole.createDarkTheme.name,
          '_themeOf',
        ]);
        for (final required in const [
          ThemeRole.createLightTheme,
          ThemeRole.createDarkTheme,
        ]) {
          final function = functions[required.name]!;
          expect('${function.returnType}', required.returnType);
          expect(
            '${function.functionExpression.parameters}',
            '(BuildContext context)',
            reason: required.name,
          );
        }
        // Each is documented for the developer who edits the file.
        for (final declaration in unit.declarations) {
          expect(
            declaration.documentationComment,
            isNotNull,
            reason: '$declaration',
          );
        }
      });

      test(
          'creates a light and a dark Material 3 theme, each anew at every '
          'call, whose colours derive from the seed colour', () async {
        final app = DartApp.write(withTheme);
        final Map<Object?, Object?> sent;
        try {
          sent = (await app.run(_script))! as Map<Object?, Object?>;
        } finally {
          app.delete();
        }

        expect(sent, {
          // Colors.deepPurple, the seed of the app that `flutter create`
          // generates.
          'seed': 0xFF673AB7,
          'light': ['light', 'light', true, true],
          'dark': ['dark', 'dark', true, true],
          'created anew': true,
        });
      });

      test('is the file that the example of the package shows', () {
        // Git may check the example out with the line endings of Windows.
        final example = File('example/README.md')
            .readAsStringSync()
            .replaceAll('\r\n', '\n');
        final shown = RegExp(r'```dart\n([\s\S]*?)```').allMatches(example);

        expect(
          [for (final block in shown) block[1]],
          [withTheme.files[ThemeRole.appThemeFile]!.text],
        );
      });
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the theme of the guide, after what the '
          'role says', () {
        final ofRole = [
          for (final (origin, _, note)
              in withTheme.entriesOf(AppEntryRole.agentSections))
            if (origin == const RoleTemplateOrigin(themeRole)) note.text,
        ].single;

        expect(
          withTheme.files[AppEntryRole.agentsFile]!.text,
          contains(
            '\n## ${themeRole.description}\n'
            '\n'
            '${ofRole.trim()}\n'
            '\n'
            '${agentNote.trim()}\n',
          ),
        );
      });

      test(
          'names the file of the themes and what the file has: the function '
          'that creates both themes, the seed colour that their colours '
          'derive from, the brightness that tells the two apart, and the '
          'two functions of the role', () {
        final index = DartFileIndexer.index(
          ThemeRole.appThemeFile,
          withTheme.files[ThemeRole.appThemeFile]!.text,
        );

        // The seed colour, and the function that creates a theme of the
        // brightness that it gets.
        expect(index.declaration('seedColor')?.kind, DeclarationKind.variable);
        final themeOf = index.declaration('_themeOf')!;
        expect(themeOf.kind, DeclarationKind.function);
        expect(
          [for (final parameter in themeOf.parameters) parameter.name],
          ['brightness'],
        );
        // It creates the one ThemeData of the file, with the one colour
        // scheme, which derives from the seed colour.
        expect(
          [
            for (final call in index.invocationsOf('ThemeData'))
              call.enclosingDeclaration,
          ],
          ['_themeOf'],
        );
        expect(
          [
            for (final call in index.invocationsOf('fromSeed'))
              '${call.target}.${call.name} in ${call.enclosingDeclaration}',
          ],
          ['ColorScheme.fromSeed in _themeOf'],
        );
        // The colour scheme takes the seed colour and the brightness that
        // the function gets, which the note tells to keep.
        final created = (_functionsOf(_themesOf(withTheme))['_themeOf']!
                .functionExpression
                .body as ExpressionFunctionBody)
            .expression as MethodInvocation;
        final scheme = created.argumentList.arguments
            .whereType<NamedArgument>()
            .singleWhere((argument) => argument.name.lexeme == 'colorScheme')
            .argumentExpression as MethodInvocation;
        expect(
          {
            for (final argument
                in scheme.argumentList.arguments.whereType<NamedArgument>())
              argument.name.lexeme: '${argument.argumentExpression}',
          },
          {'seedColor': 'seedColor', 'brightness': 'brightness'},
        );
        // Both functions of the role return what it creates.
        expect(
          [
            for (final call in index.invocationsOf('_themeOf'))
              call.enclosingDeclaration,
          ],
          [ThemeRole.createLightTheme.name, ThemeRole.createDarkTheme.name],
        );

        final names = [
          '_themeOf',
          'ThemeData',
          'ColorScheme.fromSeed',
          'seedColor',
          'brightness',
          'brightness: brightness',
          // The two functions, as the note of the role writes them.
          '${ThemeRole.createLightTheme.name}(context)',
          '${ThemeRole.createDarkTheme.name}(context)',
        ];
        for (final name in names) {
          expect(agentNote, contains('`$name`'), reason: name);
        }
        expect(agentNote, contains('`${ThemeRole.appThemeFile}`'));
        // The note names no other code.
        expect(_codeOf(agentNote), {...names, ThemeRole.appThemeFile});
      });
    });
  });

  group('an app with a settings screen and the localization', () {
    late ContractResult result;
    late RenderedApp plain;

    setUpAll(() async {
      result = await _resultOf(
        const [MaterialThemeModule.id, SettingsModule.id, GenL10nModule.id],
      );
      plain = (await _resultOf(const [MaterialThemeModule.id])).app!;
    });

    test(
        'has the entry of the theme mode, which is the entry of the role: '
        'the module has no setting of its own', () {
      // The entries of the settings screen, each by its contributor. The
      // localization role has one of its own, the setting of the language.
      final entries = <ContributionOrigin?, List<String>>{};
      for (final data in settingsScreenRole.hookInput(result.hook!).data) {
        if (data.value is SettingsEntry) {
          (entries[data.origin] ??= []).add('${data.value}');
        }
      }

      expect(
        entries[const RoleTemplateOrigin(themeRole)],
        ['settings entry ThemeModeSetting'],
      );
      expect(
        entries.keys,
        isNot(contains(const ModuleOrigin(MaterialThemeModule.id))),
      );
      expect(
        result.app!.files[ThemeRole.themeModeSettingFile]!.owner,
        const RoleTemplateOrigin(themeRole),
      );
    });

    test(
        'has the texts of the entry as texts of the app, which are the '
        'texts of the role: the module has no text of its own', () {
      final owners = {
        for (final text in localizationRole.textsIn(
          localizationRole.hookInput(result.hook!),
        ))
          text.owner,
      };

      // The texts of the app are those of the templates of roles: the
      // theme role, and the localization role for its own setting.
      expect(owners, contains(const RoleTemplateOrigin(themeRole)));
      expect(
        owners,
        isNot(contains(const ModuleOrigin(MaterialThemeModule.id))),
      );
    });

    test(
        'has the file of the themes of the app without them, and no other '
        'file of the module', () {
      final ofModule = [
        for (final file in result.app!.files.values)
          if (file.owner == const ModuleOrigin(MaterialThemeModule.id)) file,
      ];

      expect(
        [for (final file in ofModule) file.path],
        [ThemeRole.appThemeFile],
      );
      expect(ofModule.single.text, plain.files[ThemeRole.appThemeFile]!.text);
    });
  });
}
