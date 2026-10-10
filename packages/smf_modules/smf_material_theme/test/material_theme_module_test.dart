@TestOn('vm')
library;

import 'dart:io';
import 'dart:math' as math;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
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
import 'package:yaml/yaml.dart';

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

/// The import of the file of the themes that takes the page transition of
/// iOS from the cupertino library of Flutter.
const _cupertinoImport = "import 'package:flutter/cupertino.dart' "
    'show CupertinoPageTransitionsBuilder;';

/// The top-level variables of [unit], by name.
Map<String, VariableDeclarationList> _variablesOf(CompilationUnit unit) => {
      for (final declaration
          in unit.declarations.whereType<TopLevelVariableDeclaration>())
        declaration.variables.variables.single.name.lexeme:
            declaration.variables,
    };

/// The pubspec of [app].
YamlMap _pubspecOf(RenderedApp app) =>
    loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;

/// The file of the brick of the module that the app gets at [path], as it
/// is in the package.
File _brickFile(String path) => File('bricks/material_theme/__brick__/$path');

/// Finds the calls of `ColorScheme.fromSeed` in a file.
final class _FromSeedCalls extends RecursiveAstVisitor<void> {
  final List<MethodInvocation> calls = [];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    if ('${node.target}.${node.methodName}' == 'ColorScheme.fromSeed') {
      calls.add(node);
    }
    super.visitMethodInvocation(node);
  }
}

/// How bright the colour [argb] is, from 0 for black to 1 for white, as
/// WCAG 2 defines the relative luminance of a colour.
double _luminanceOf(int argb) {
  double channel(int shift) {
    final value = ((argb >> shift) & 0xFF) / 255;
    return value <= 0.03928
        ? value / 12.92
        : math.pow((value + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * channel(16) + 0.7152 * channel(8) + 0.0722 * channel(0);
}

/// The contrast of the colours [a] and [b], from 1 for the same colour to
/// 21 for black on white, as WCAG 2 defines it. A text is readable on its
/// background from 4.5.
double _contrastOf(int a, int b) {
  final brighter = math.max(_luminanceOf(a), _luminanceOf(b));
  final darker = math.min(_luminanceOf(a), _luminanceOf(b));
  return (brighter + 0.05) / (darker + 0.05);
}

/// Creates the two themes of the app with a context of the script, and
/// sends back what each is: its brightness, whether its colours derive from
/// the seed colour of the file, whether it is of Material 3, the colours
/// that the file sets and the colour of an error, the font and the weight
/// of each of its text styles, of the text of its buttons and of the text
/// of a mistake of its fields, and the look of its fields.
///
/// It imports only the file of the themes, which needs nothing but the
/// stand-ins for Flutter's material and cupertino libraries.
final _script = '''
import 'dart:isolate';

import 'package:contract_app/core/theme/app_theme.dart';
import 'package:flutter/material.dart';

class Root implements BuildContext {}

List<Object?> font(TextStyle? style) => [
  style?.fontFamily,
  style?.fontWeight?.value,
];

/// The line around a field: the radius of its corners, its colour and its
/// width, or nothing for a border that is no outline.
List<Object?>? outline(InputBorder? border) => border is OutlineInputBorder
    ? [
        border.borderRadius.top.x,
        border.borderRadius.bottom.x,
        border.borderSide.color.value,
        border.borderSide.width,
      ]
    : null;

/// An icon of a field: its colour in a field as it is, in one with a
/// mistake, in one with a mistake and the focus, and in one that is
/// disabled, and the least width and height of its box.
Map<String, Object?> icon(Color? color, BoxConstraints? box) => {
  for (final MapEntry(key: name, value: states) in const {
    'enabled': <WidgetState>{},
    'mistake': {WidgetState.error},
    'mistake with the focus': {WidgetState.error, WidgetState.focused},
    'disabled': {WidgetState.disabled},
  }.entries)
    name: WidgetStateProperty.resolveAs(color, states)?.value,
  'box': [box?.minWidth, box?.minHeight],
};

Map<String, Object?> fields(InputDecorationThemeData fields) => {
  'filled': fields.filled,
  'fill': fields.fillColor?.value,
  'padding': switch (fields.contentPadding) {
    final EdgeInsets padding => [padding.left, padding.top],
    _ => null,
  },
  'lines': {
    'border': outline(fields.border),
    'enabled': outline(fields.enabledBorder),
    'disabled': outline(fields.disabledBorder),
    'focus': outline(fields.focusedBorder),
    'mistake': outline(fields.errorBorder),
    'mistake with the focus': outline(fields.focusedErrorBorder),
  },
  'mistake': {
    'colour': fields.errorStyle?.color?.value,
    'lines': fields.errorMaxLines,
  },
  'icons': {
    'start': icon(fields.prefixIconColor, fields.prefixIconConstraints),
    'end': icon(fields.suffixIconColor, fields.suffixIconConstraints),
  },
};

Map<String, Object?> described(ThemeData theme) => {
  'brightness': [theme.brightness.name, theme.colorScheme.brightness.name],
  'derives from the seed': identical(theme.colorScheme.seed, seedColor),
  'material 3': theme.useMaterial3,
  'colours': {
    for (final MapEntry(key: name, value: color)
        in theme.colorScheme.set.entries)
      name: color.value,
  },
  'error': theme.colorScheme.error.value,
  'text styles': {
${textStyles.map((name) => "    '$name': font(theme.textTheme.$name),").join('\n')}
  },
  'buttons': {
    'filled': font(theme.filledButtonTheme.style?.textStyle),
    'text': font(theme.textButtonTheme.style?.textStyle),
    'segmented': font(theme.segmentedButtonTheme.style?.textStyle),
  },
  'texts of fields': {
    'mistake': font(theme.inputDecorationTheme.errorStyle),
  },
  'fields': fields(theme.inputDecorationTheme),
};

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
        'contributes its brick, with the file of the themes and the files of '
        'the font with their licence, the font and its licence for the '
        'pubspec of the app, and its note for coding agents, and nothing '
        'else: no package, no data of a role and no code for a socket', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(3));
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(materialThemeBundle));
      expect(brick.bundle.name, 'material_theme');
      expect(
        {for (final file in brick.bundle.files) file.path},
        {
          ThemeRole.appThemeFile,
          ...MaterialThemeModule.fontFiles.values,
          MaterialThemeModule.fontLicenseFile,
        },
      );
      expect(brick.vars, isEmpty);
      expect(brick.when, isEmpty);
      final pubspec = contributions[1] as PubspecFlutter;
      expect(pubspec.assets, [MaterialThemeModule.fontLicenseFile]);
      final font = pubspec.fonts.single;
      expect(font.family, MaterialThemeModule.fontFamily);
      expect(
        {for (final file in font.assets) file.weight: file.asset},
        MaterialThemeModule.fontFiles,
      );
      expect(font.assets.map((file) => file.style), everyElement(isNull));
      // The files and the licence are in the directory of the font.
      for (final file in [
        ...pubspec.assets,
        ...font.assets.map((file) => file.asset),
      ]) {
        expect(file, startsWith('${MaterialThemeModule.fontDirectory}/'));
      }
      // The other flags of the section are for the app entry to set.
      expect(pubspec.generate, isFalse);
      expect(pubspec.usesMaterialDesign, isFalse);
      expect(pubspec.when, isEmpty);
      final note = contributions[2] as SocketContribution;
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
        'flutter_core with router, localization',
        'flutter_core with router',
        // The app of the provider of the localization alone.
        'flutter_core with localization',
        'flutter_core',
        'shared_preferences',
        // The settings screen reads its title from the texts of the app, and
        // the localization has its setting on that screen: one app.
        'settings with localization',
        'settings',
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
        'files of the font with their licence, the file of the theme mode, '
        'the section of the theme in the guide for coding agents, and what '
        'the root of the app, the preferences and the pubspec need for '
        'them: it adds no package', () {
      final ofModule = [
        ThemeRole.appThemeFile,
        ...MaterialThemeModule.fontFiles.values,
        MaterialThemeModule.fontLicenseFile,
      ];
      expect(
        withTheme.files.keys.toSet(),
        {...without.files.keys, ThemeRole.themeModeFile, ...ofModule},
      );
      for (final path in ofModule) {
        expect(
          withTheme.files[path]!.owner,
          const ModuleOrigin(MaterialThemeModule.id),
          reason: path,
        );
      }
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
        // The pubspec gets the font, which is checked below.
        if (path == 'pubspec.yaml') continue;
        if (!_sameBytes(withTheme.files[path]!.bytes, file.bytes)) {
          changed.add(file.owner);
        }
      }
      expect(changed, {
        for (final id in appEntry) ModuleOrigin(id),
        const RoleTemplateOrigin(preferencesRole),
      });
      // The pubspec has the packages of the app without the theme. Its
      // section of Flutter differs, by the font and its licence alone.
      final pubspec = _pubspecOf(withTheme);
      final before = _pubspecOf(without);
      expect(
        {...pubspec}..remove('flutter'),
        {...before}..remove('flutter'),
      );
      expect(
        {...pubspec['flutter'] as YamlMap}
          ..remove('fonts')
          ..remove('assets'),
        {...before['flutter'] as YamlMap},
      );
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
      late Map<Object?, Object?> sent;

      setUpAll(() async {
        unit = _themesOf(withTheme);
        functions = _functionsOf(unit);
        final app = DartApp.write(withTheme);
        try {
          sent = (await app.run(_script))! as Map<Object?, Object?>;
        } finally {
          app.delete();
        }
      });

      /// What the script sent of the theme [name], `light` or `dark`.
      Map<Object?, Object?> themeOf(String name) =>
          sent[name]! as Map<Object?, Object?>;

      /// The colours that the file sets in the theme [name], by their
      /// names in the colour scheme.
      Map<String, int> coloursOf(String name) =>
          (themeOf(name)['colours']! as Map<Object?, Object?>)
              .cast<String, int>();

      test(
          'has the seed colour, the two colours that go with it, the family '
          'of the font, the two functions of the role, which take the '
          'context of the root, and the functions that build the colours, '
          'the text styles and both themes, and imports only the material '
          'library of Flutter and, from its cupertino library, the page '
          'transition of iOS', () {
        expect(
          [
            for (final directive in unit.directives) '$directive',
          ],
          const [
            _cupertinoImport,
            "import 'package:flutter/material.dart';",
          ],
        );
        final variables = _variablesOf(unit);
        expect(
          {
            for (final MapEntry(key: name, value: variable)
                in variables.entries)
              name: '${variable.isConst ? 'const ' : ''}${variable.type}',
          },
          {
            'seedColor': 'const Color',
            '_deepGreen': 'const Color',
            '_cream': 'const Color',
            '_fontFamily': 'const String',
          },
        );
        expect(
          '${variables['seedColor']!.variables.single.initializer}',
          'Color(0xFF15803D)',
        );
        // The family that the pubspec of the app declares.
        expect(
          '${variables['_fontFamily']!.variables.single.initializer}',
          "'${MaterialThemeModule.fontFamily}'",
        );
        expect(functions.keys, [
          ThemeRole.createLightTheme.name,
          ThemeRole.createDarkTheme.name,
          '_schemeOf',
          '_textThemeOf',
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
          'call, whose colours derive from the seed colour', () {
        expect(sent['seed'], 0xFF15803D);
        expect(sent['created anew'], isTrue);
        for (final name in const ['light', 'dark']) {
          final theme = themeOf(name);
          expect(theme['brightness'], [name, name], reason: name);
          expect(theme['derives from the seed'], isTrue, reason: name);
          expect(theme['material 3'], isTrue, reason: name);
        }
      });

      test(
          'gives every text style of both themes, the text of their buttons '
          'and the text of a mistake of their fields the font that the '
          'pubspec of the app declares, in a weight that the app has a file '
          'of', () {
        for (final name in const ['light', 'dark']) {
          final theme = themeOf(name);
          final styles = theme['text styles']! as Map<Object?, Object?>;
          final buttons = theme['buttons']! as Map<Object?, Object?>;
          final fields = theme['texts of fields']! as Map<Object?, Object?>;
          expect(styles.keys, textStyles, reason: name);
          expect(buttons.keys, ['filled', 'text', 'segmented'], reason: name);
          expect(fields.keys, ['mistake'], reason: name);
          for (final MapEntry(key: style, value: font)
              in {...styles, ...buttons, ...fields}.entries) {
            final [family, weight] = font! as List<Object?>;
            expect(
              family,
              MaterialThemeModule.fontFamily,
              reason: '$name: $style',
            );
            expect(
              MaterialThemeModule.fontFiles.keys,
              contains(weight),
              reason: '$name: $style',
            );
          }
        }
      });

      test(
          'sets the same colours in both themes, with the deep green and the '
          'cream as the primary colour and the colour of what stands on it, '
          'the other way round in the dark theme', () {
        final light = coloursOf('light');
        final dark = coloursOf('dark');

        // Every colour that the stand-in for the colour scheme has.
        expect(light.keys, unorderedEquals(schemeColors));
        expect(dark.keys, unorderedEquals(schemeColors));
        expect(
          (light['primary'], light['onPrimary']),
          (0xFF0F3326, 0xFFF1F1E8),
        );
        expect(
          (dark['primary'], dark['onPrimary']),
          (light['onPrimary'], light['primary']),
        );
        // The accent of the light theme is the seed colour.
        expect(light['secondary'], sent['seed']);
      });

      test(
          'keeps a text readable in both themes, with a contrast of 4.5 to 1 '
          'or more: what stands on a colour, the text on every surface, and '
          'the accent on the surface', () {
        const surfaces = [
          'surface',
          'surfaceContainerLowest',
          'surfaceContainerLow',
          'surfaceContainer',
          'surfaceContainerHigh',
          'surfaceContainerHighest',
        ];
        // The colour that `onPrimary` stands on is `primary`.
        String below(String on) => on[2].toLowerCase() + on.substring(3);

        for (final name in const ['light', 'dark']) {
          final colours = coloursOf(name);
          final pairs = [
            for (final on in colours.keys)
              if (on.startsWith('on') && colours.containsKey(below(on)))
                (on, below(on)),
            for (final surface in surfaces) ...[
              ('onSurface', surface),
              ('onSurfaceVariant', surface),
            ],
            ('secondary', 'surface'),
          ];
          expect(
            pairs,
            containsAll(const [
              ('onPrimary', 'primary'),
              ('onPrimaryContainer', 'primaryContainer'),
              ('onSecondary', 'secondary'),
              ('onSecondaryContainer', 'secondaryContainer'),
              ('onTertiary', 'tertiary'),
              ('onTertiaryContainer', 'tertiaryContainer'),
              ('onInverseSurface', 'inverseSurface'),
            ]),
            reason: name,
          );
          for (final (text, background) in pairs) {
            expect(
              _contrastOf(colours[text]!, colours[background]!),
              greaterThanOrEqualTo(4.5),
              reason: '$name: $text on $background',
            );
          }
        }
      });

      test(
          'gives a text field of each theme its look in the colours of that '
          'theme: a filled box with a padding and corners of 16, and a '
          'hairline around it that is of the primary colour and wider with '
          'the focus and of the colour of an error with a mistake; the '
          'text of a mistake in that colour, on as many lines as it needs, '
          'up to five; and an icon at its start or its end that keeps its '
          'colour with a mistake, is as dim as the text in a field that is '
          'disabled, and stands as far from the edge as the padding is '
          'wide', () {
        for (final name in const ['light', 'dark']) {
          final colours = coloursOf(name);
          final error = themeOf(name)['error']! as int;
          final fields = themeOf(name)['fields']! as Map<Object?, Object?>;

          expect(fields['filled'], isTrue, reason: name);
          expect(fields['fill'], colours['surfaceContainerLow'], reason: name);
          expect(fields['padding'], [16, 18], reason: name);
          // The corners at the top and at the bottom, the colour of the
          // line and its width.
          final hairline = [16, 16, colours['outlineVariant'], 1];
          expect(
            fields['lines'],
            {
              'border': hairline,
              'enabled': hairline,
              'disabled': hairline,
              'focus': [16, 16, colours['primary'], 1.5],
              'mistake': [16, 16, error, 1],
              'mistake with the focus': [16, 16, error, 1.5],
            },
            reason: name,
          );
          expect(
            fields['mistake'],
            {'colour': error, 'lines': 5},
            reason: name,
          );
          // The text of a field that is disabled, as Material dims it: the
          // colour of a text on the surface at 38 % of its opacity.
          final dim = (colours['onSurface']! & 0x00FFFFFF) | (0x61 << 24);
          final icon = {
            'enabled': colours['onSurfaceVariant'],
            'mistake': colours['onSurfaceVariant'],
            'mistake with the focus': colours['onSurfaceVariant'],
            'disabled': dim,
            // A box of 56 leaves 16 on each side of an icon of 24, which
            // is the padding of the field.
            'box': [56, 48],
          };
          expect(fields['icons'], {'start': icon, 'end': icon}, reason: name);
        }
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

    group('the font', () {
      test(
          'is declared in the pubspec of the app, its family with a file '
          'for each weight, and has its licence among the assets of the '
          'app', () {
        final flutter = _pubspecOf(withTheme)['flutter'] as YamlMap;

        expect(flutter['fonts'], [
          {
            'family': MaterialThemeModule.fontFamily,
            'fonts': [
              for (final MapEntry(key: weight, value: file)
                  in MaterialThemeModule.fontFiles.entries)
                {'asset': file, 'weight': weight},
            ],
          },
        ]);
        expect(flutter['assets'], [MaterialThemeModule.fontLicenseFile]);
      });

      test(
          'has its files in the app as they are in the package, byte for '
          'byte, and not as text', () {
        for (final path in MaterialThemeModule.fontFiles.values) {
          final file = withTheme.files[path]!;

          expect(file.isText, isFalse, reason: path);
          expect(
            _sameBytes(file.bytes, _brickFile(path).readAsBytesSync()),
            isTrue,
            reason: path,
          );
        }
      });

      test(
          'comes with its licence, the SIL Open Font License of the authors '
          'of the font', () {
        final licence =
            withTheme.files[MaterialThemeModule.fontLicenseFile]!.text;

        expect(licence, startsWith('Copyright 2024 The Geist Project Authors'));
        expect(licence, contains('SIL OPEN FONT LICENSE Version 1.1'));
      });

      test(
          'has its licence in the notices of the package too, which '
          'publishes the font in the bundle of its brick', () {
        // Git may check a text file out with the line endings of Windows.
        String read(File file) =>
            file.readAsStringSync().replaceAll('\r\n', '\n');

        expect(
          read(File('NOTICE')),
          contains(read(_brickFile(MaterialThemeModule.fontLicenseFile))),
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
          'that creates both themes, those of their colours and of their '
          'text styles, the seed colour, the family of the font, the '
          'brightness that tells the two themes apart and the two functions '
          'of the role; and the files of the font with their licence, and '
          'the pubspec that declares them', () {
        final index = DartFileIndexer.index(
          ThemeRole.appThemeFile,
          withTheme.files[ThemeRole.appThemeFile]!.text,
        );

        // The seed colour and the family of the font, and the functions
        // that create the theme and the colours of the brightness that they
        // get.
        for (final name in const ['seedColor', '_fontFamily']) {
          expect(
            index.declaration(name)?.kind,
            DeclarationKind.variable,
            reason: name,
          );
        }
        for (final name in const ['_themeOf', '_schemeOf']) {
          final function = index.declaration(name)!;
          expect(function.kind, DeclarationKind.function, reason: name);
          expect(
            [for (final parameter in function.parameters) parameter.name],
            ['brightness'],
            reason: name,
          );
        }
        expect(
          index.declaration('_textThemeOf')?.kind,
          DeclarationKind.function,
        );
        // The function of the themes creates the one theme of the file that
        // has the themes of the components, with the colours and the text
        // styles of the two others and with the font.
        expect(
          index
              .invocationsOf('ThemeData', within: '_themeOf')
              .single
              .namedArguments,
          containsAll(['colorScheme', 'fontFamily', 'textTheme', 'cardTheme']),
        );
        for (final name in const ['_schemeOf', '_textThemeOf']) {
          expect(
            [
              for (final call in index.invocationsOf(name))
                call.enclosingDeclaration,
            ],
            ['_themeOf'],
            reason: name,
          );
        }
        // The colours are those of the one colour scheme of the file, which
        // derives from the seed colour and takes the brightness that the
        // function gets, as the note tells to keep. A copy for each
        // brightness sets most of them, such as the primary colour and the
        // colour of what stands on it.
        final fromSeed = _FromSeedCalls();
        _themesOf(withTheme).accept(fromSeed);
        final scheme = fromSeed.calls.single;
        expect(
          scheme.thisOrAncestorOfType<FunctionDeclaration>()!.name.lexeme,
          '_schemeOf',
        );
        expect(
          {
            for (final argument
                in scheme.argumentList.arguments.whereType<NamedArgument>())
              argument.name.lexeme: '${argument.argumentExpression}',
          },
          {
            'seedColor': 'seedColor',
            'brightness': 'brightness',
            'dynamicSchemeVariant': 'DynamicSchemeVariant.fidelity',
          },
        );
        final copies =
            index.invocationsOf('copyWith', within: '_schemeOf').toList();
        expect(copies, hasLength(2));
        for (final copy in copies) {
          expect(copy.namedArguments, containsAll(['primary', 'onPrimary']));
        }
        // Both functions of the role return what the function of the themes
        // creates.
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
          '_schemeOf',
          '_textThemeOf',
          'cardTheme',
          'brightness',
          'ColorScheme.fromSeed',
          'seedColor',
          'onPrimary',
          'primary',
          '_fontFamily',
          'brightness: brightness',
          // The two functions, as the note of the role writes them.
          '${ThemeRole.createLightTheme.name}(context)',
          '${ThemeRole.createDarkTheme.name}(context)',
        ];
        // The files of the app that the note names: those of the module,
        // and the pubspec.
        const files = [
          ThemeRole.appThemeFile,
          '${MaterialThemeModule.fontDirectory}/',
          MaterialThemeModule.fontLicenseFile,
          'pubspec.yaml',
        ];
        for (final name in [...names, ...files]) {
          expect(agentNote, contains('`$name`'), reason: name);
        }
        for (final weight in MaterialThemeModule.fontFiles.keys) {
          expect(agentNote, contains('$weight'), reason: '$weight');
        }
        // The note names no other code.
        expect(_codeOf(agentNote), {...names, ...files});
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
        'has the file of the themes and the files of the font of the app '
        'without them, and no other file of the module', () {
      final ofModule = {
        for (final file in result.app!.files.values)
          if (file.owner == const ModuleOrigin(MaterialThemeModule.id))
            file.path: file,
      };

      expect(ofModule.keys.toSet(), {
        ThemeRole.appThemeFile,
        ...MaterialThemeModule.fontFiles.values,
        MaterialThemeModule.fontLicenseFile,
      });
      for (final MapEntry(key: path, value: file) in ofModule.entries) {
        expect(
          _sameBytes(file.bytes, plain.files[path]!.bytes),
          isTrue,
          reason: path,
        );
      }
    });
  });
}
