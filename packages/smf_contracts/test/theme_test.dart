@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/bundles/theme_role_bundle.dart';
import 'package:smf_contracts/bundles/theme_role_setting_bundle.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

/// The file of the mode, as code imports it.
const _themeMode = ImportRef.app('core/theme/theme_mode.dart');

/// The file of the themes of the provider, as code imports it.
const _appTheme = ImportRef.app('core/theme/app_theme.dart');

/// The file of the texts of the app, as code imports it.
const _appTexts = ImportRef.app('core/l10n/l10n.dart');

/// The file of the fake implementation of the preferences in the test app.
const _fakeFile = ImportRef.app('fakes/fake_preferences.dart');

/// The template of the role as its owner, as the pipeline names it.
const _template = RoleTemplateOrigin(themeRole);

/// A text of the entry of the settings screen: its name, its getter among
/// the texts of the app, its English text and its Ukrainian one.
typedef _Text = ({String name, String getter, String en, String uk});

/// The texts of the entry of the settings screen, in the order of the
/// template.
const List<_Text> _texts = [
  (name: 'title', getter: 'themeTitle', en: 'Theme', uk: 'Тема'),
  (name: 'system', getter: 'themeSystem', en: 'System', uk: 'Системна'),
  (name: 'light', getter: 'themeLight', en: 'Light', uk: 'Світла'),
  (name: 'dark', getter: 'themeDark', en: 'Dark', uk: 'Темна'),
];

/// The roles of an app with the theme role and its preferences: with a
/// settings screen if [settings], and with the localization role if
/// [localized].
Set<Role> _rolesOf({required bool settings, required bool localized}) => {
      preferencesRole,
      if (settings) settingsScreenRole,
      if (localized) localizationRole,
    };

/// What the template of the role contributes, in every app and in some.
List<Contribution> _contributions() =>
    themeRole.template.contribute(testContext);

/// The data that the template gives [role], as the pipeline hands it to
/// the hooks of that role: with the template as its origin.
List<RoleData<Object>> _dataFor(Role role) => [
      for (final contribution in _contributions())
        if (contribution case final RoleData<Object> data
            when data.role == role)
          data.withOrigin(_template),
    ];

/// Preferences of the test app that read and write a text, which is all
/// that the theme mode needs, over a map that stands for the disk: each
/// open reads the map anew, and a write takes a moment, and fails when the
/// test says so. Any other read or write throws.
const _fakePreferences = r'''
import '../core/preferences/app_preferences.dart';

/// What the preferences have saved.
final Map<String, Object> disk = {};

/// The writes of the app that were saved, each with the open of the
/// preferences that got it: the first, the second.
final List<String> writes = [];

/// Whether a write fails once it took its moment: its future has an error.
bool writesFail = false;

/// Whether a write throws at once, before it returns a future.
bool writesThrow = false;

int _opens = 0;

AppPreferences createFakePreferences() => FakePreferences(++_opens);

final class FakePreferences implements AppPreferences {
  FakePreferences(this._open) : _values = Map.of(disk);

  final int _open;
  final Map<String, Object> _values;

  @override
  String? getString(String key) => switch (_values[key]) {
        final String value => value,
        _ => null,
      };

  @override
  Future<void> setString(String key, String value) {
    if (writesThrow) throw StateError('The write throws.');
    return _write(key, value);
  }

  Future<void> _write(String key, String value) async {
    await Future<void>.delayed(Duration.zero);
    if (writesFail) throw StateError('The write fails.');
    _values[key] = value;
    disk[key] = value;
    writes.add('open $_open: $key = $value');
  }

  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}
''';

/// A script for the test app that runs [body] and sends back `result`, what
/// the body noted. The body has `key`, the key of the mode in the
/// preferences, and `heard()`, the modes that the listeners of the
/// controller were told of since it last asked.
///
/// It imports only the files of the two roles and the fake, which need
/// nothing but Dart and the stand-ins for Flutter's libraries.
String _scriptOf(String body) => '''
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:my_app/core/preferences/app_preferences.dart';
import 'package:my_app/core/theme/theme_mode.dart';
import 'package:my_app/fakes/fake_preferences.dart';

class Child extends Widget {
  const Child();
}

/// A context below [scope], or below no inherited widget, which notes the
/// types of the inherited widgets that it is asked for.
final class Below implements BuildContext {
  Below(this.scope);

  final InheritedWidget? scope;

  final List<String> asked = [];

  @override
  T? dependOnInheritedWidgetOfExactType<T extends InheritedWidget>({
    Object? aspect,
  }) {
    asked.add('\$T');
    return switch (scope) {
      final T scope => scope,
      _ => null,
    };
  }
}

Future<void> main(List<String> arguments, SendPort port) async {
  const key = '${ThemeRole.modeKey}';
  final result = <String, Object?>{};
  final told = <String>[];
  themeModeController
      .addListener(() => told.add(themeModeController.mode.name));
  List<String> heard() {
    final modes = [...told];
    told.clear();
    return modes;
  }

$body
  port.send(result);
}
''';

/// Selects modes before the app opened its preferences and after.
final String _choices = _scriptOf('''
  result['at first'] = themeModeController.mode.name;

  await themeModeController.select(ThemeMode.dark);
  result['a choice before the preferences are open'] = {
    'mode': themeModeController.mode.name,
    'heard': heard(),
    'saved': disk[key],
    'writes': [...writes],
  };

  await initPreferences();
  result['the start with nothing saved'] = {
    'mode': themeModeController.mode.name,
    'heard': heard(),
    'saved': disk[key],
  };

  await themeModeController.select(ThemeMode.dark);
  result['the choice of the mode that the app is in'] = {
    'heard': heard(),
    'saved': disk[key],
  };

  final saved = themeModeController.select(ThemeMode.light);
  result['a choice whose write is on its way'] = {
    'mode': themeModeController.mode.name,
    'heard': heard(),
    'saved': disk[key],
  };
  await saved;
  result['a choice whose future completed'] = {'saved': disk[key]};
  result['writes'] = [...writes];
''');

/// Starts the app again and again, each time with something else saved,
/// and selects a mode after the last start.
final String _starts = _scriptOf('''
  Future<Map<String, Object?>> start(Object? saved) async {
    if (saved == null) {
      disk.remove(key);
    } else {
      disk[key] = saved;
    }
    await initPreferences();
    return {'mode': themeModeController.mode.name, 'heard': heard()};
  }

  result['with dark saved'] = await start('dark');
  result['with dark saved again'] = await start('dark');
  result['with light saved'] = await start('light');
  result['with nothing saved'] = await start(null);
  result['with no name of a mode saved'] = await start('sepia');
  result['with a number saved'] = await start(2);
  result['with system saved'] = await start('system');

  await themeModeController.select(ThemeMode.dark);
  result['writes'] = [...writes];
  result['printed'] = [...debugPrinted];
''');

/// Starts the app for the first time with the mode that it is in saved, so
/// that the start changes nothing, and selects a mode after that.
final String _startWithTheModeSaved = _scriptOf('''
  disk[key] = 'system';
  await initPreferences();
  result['the start'] = {
    'mode': themeModeController.mode.name,
    'heard': heard(),
  };

  await themeModeController.select(ThemeMode.dark);
  result['a choice after it'] = {'saved': disk[key], 'writes': [...writes]};
''');

/// Selects modes with preferences that fail to save them, as a future with
/// an error and as a throw, and starts the app again after that.
final String _failedWrites = _scriptOf('''
  Future<Map<String, Object?>> choice(ThemeMode mode) async {
    String? error;
    try {
      await themeModeController.select(mode);
    } on StateError catch (failure) {
      error = failure.message;
    }
    return {
      'error': error,
      'mode': themeModeController.mode.name,
      'heard': heard(),
      'saved': disk[key],
    };
  }

  await initPreferences();
  result['a write that is saved'] = await choice(ThemeMode.dark);

  writesFail = true;
  result['a write that fails'] = await choice(ThemeMode.light);
  writesFail = false;
  result['the same choice again'] = await choice(ThemeMode.light);

  writesThrow = true;
  result['a write that throws'] = await choice(ThemeMode.system);
  writesThrow = false;

  await initPreferences();
  result['the next start'] = {
    'mode': themeModeController.mode.name,
    'heard': heard(),
  };
''');

/// Asks the scope for the controller, from a context below the scope and
/// from one below none.
final String _scope = _scriptOf('''
  final below = Below(
    ThemeModeScope(notifier: themeModeController, child: const Child()),
  );
  result['below the scope'] = {
    'the controller of the app':
        identical(ThemeModeScope.of(below), themeModeController),
    'asked of the context': below.asked,
  };

  final outside = Below(null);
  try {
    ThemeModeScope.of(outside);
    result['below no scope'] = 'a controller';
  } on TypeError {
    result['below no scope'] = 'no controller';
  }
  result['asked of the context below no scope'] = outside.asked;
''');

/// The files of the test app: the file of the mode, as the template of the
/// role generates it, the file of the preferences role with the restorer
/// that the template puts into its socket, and the fake preferences.
Future<DartFiles> _app() async {
  final theme = await renderTemplate(
    themeRole,
    present: _rolesOf(settings: false, localized: false),
  );
  final preferences = await renderTemplate(
    preferencesRole,
    data: [
      dataOf(
        preferencesRole,
        const RoleImplementation(
          type: TypeRef('FakePreferences', import: _fakeFile),
          create: FactoryRef('createFakePreferences', import: _fakeFile),
        ),
        module: 'fake_preferences',
      ),
    ],
    fromModules: [
      for (final contribution in theme.elsewhere)
        if (contribution.socket == PreferencesRole.restorers) contribution,
    ],
  );
  return DartFiles.write({
    ...theme.files,
    ...preferences.files,
    'lib/fakes/fake_preferences.dart': _fakePreferences,
  });
}

/// The calls in a file by the name of what they call, such as the widgets
/// that a build method creates, each as its node.
final class _Calls extends RecursiveAstVisitor<void> {
  final Map<String, List<MethodInvocation>> byName = {};

  @override
  void visitMethodInvocation(MethodInvocation node) {
    byName.putIfAbsent(node.methodName.name, () => []).add(node);
    super.visitMethodInvocation(node);
  }
}

/// The named arguments of [call], each as its code.
Map<String, String> _argumentsOf(MethodInvocation call) => {
      for (final argument in call.argumentList.arguments)
        if (argument case NamedArgument(:final name, :final argumentExpression))
          name.lexeme: argumentExpression.toSource(),
    };

/// Whether [node] is inside a constant: a creation, a list, a set or a map
/// with `const`, or a constant variable.
bool _inConstant(AstNode node) {
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    final constant = switch (parent) {
      InstanceCreationExpression(:final keyword?) => keyword.lexeme == 'const',
      TypedLiteral(:final constKeyword) => constKeyword != null,
      VariableDeclarationList(:final isConst) => isConst,
      _ => false,
    };
    if (constant) return true;
  }
  return false;
}

void main() {
  group('the theme role', () {
    test(
        'takes one provider, requires the preferences, which remember the '
        'mode, and works with a settings screen and with the languages of '
        'the app', () {
      expect(themeRole.id, 'theme');
      expect(themeRole.presenceFlag, 'has_theme');
      expect('$themeRole', 'theme role');
      expect(themeRole.cardinality, RoleCardinality.atMostOne);
      expect(themeRole.requires, {preferencesRole});
      expect(themeRole.uses, {settingsScreenRole, localizationRole});
      // Modules give the role nothing: no data, no code for a socket.
      expect(themeRole.sockets, isEmpty);
      expect(themeRole.socketFamilies, isEmpty);
      expect(themeRole.options, isEmpty);
    });

    test(
        'guarantees the file of the mode in every app, and keeps the mode '
        'under a key of its own in the preferences', () {
      expect(ThemeRole.themeModeFile, 'lib/core/theme/theme_mode.dart');
      expect(themeRole.interface.files, [ThemeRole.themeModeFile]);
      // Only an app with a settings screen has the file of the entry, so
      // the role does not guarantee it.
      expect(
        ThemeRole.themeModeSettingFile,
        'lib/core/theme/theme_mode_setting.dart',
      );
      // <owner id>.<setting>, as the preferences role names its keys.
      expect(ThemeRole.modeKey, '${themeRole.id}.mode');
    });

    test(
        'requires the light theme and the dark theme from its provider, as '
        'functions without arguments that return a ThemeData', () {
      const file = 'lib/core/theme/app_theme.dart';
      expect(ThemeRole.appThemeFile, file);
      expect(
        themeRole.interface.symbols,
        [ThemeRole.createLightTheme, ThemeRole.createDarkTheme],
      );
      expect(
        [for (final symbol in themeRole.interface.symbols) '$symbol'],
        ['function createLightTheme()', 'function createDarkTheme()'],
      );
      for (final symbol in themeRole.interface.symbols) {
        expect(symbol.path, file);
        expect(symbol.importRef, _appTheme);
      }

      List<String> problems(List<IndexedDeclaration> declarations) => [
            for (final issue in themeRole.interface.checkSymbols({
              file: DartFileIndex(path: file, declarations: declarations),
            }))
              issue.message,
          ];
      IndexedDeclaration function(
        String name, {
        String type = 'ThemeData',
        List<IndexedParameter> parameters = const [],
      }) =>
          IndexedDeclaration(
            name: name,
            kind: DeclarationKind.function,
            type: type,
            parameters: parameters,
          );

      expect(
        problems([function('createLightTheme'), function('createDarkTheme')]),
        isEmpty,
      );
      expect(
        problems([function('createLightTheme')]),
        ['$file does not declare function createDarkTheme().'],
      );
      // Each of the two, next to the other as the role requires it.
      for (final (name, other) in [
        ('createLightTheme', 'createDarkTheme'),
        ('createDarkTheme', 'createLightTheme'),
      ]) {
        const where = 'in $file';
        expect(
          problems([function(name, type: 'ColorScheme'), function(other)]),
          ['function $name() $where must return ThemeData, not ColorScheme.'],
          reason: 'The return type of $name().',
        );
        expect(
          problems([
            function(
              name,
              parameters: const [
                IndexedParameter(
                  'seed',
                  kind: ParameterKind.requiredPositional,
                ),
              ],
            ),
            function(other),
          ]).join('\n'),
          'function $name() $where must not require more than 0 positional '
          'arguments.',
          reason: 'The parameters of $name().',
        );
      }
    });
  });

  group('the template of the theme role', () {
    test(
        'gives the root of the app the two themes of the provider and the '
        'mode of a scope that it puts around the root, in every app', () {
      final sockets = _contributions().whereType<SocketContribution>().toList();

      final wrapper = sockets
          .singleWhere((socket) => socket.socket == AppEntryRole.rootWrappers);
      expect(
        wrapper.fragment!.code,
        'ThemeModeScope(notifier: themeModeController, child: ',
      );
      expect(wrapper.fragment!.closing, ')');
      expect(wrapper.fragment!.imports, [_themeMode]);

      final args = [
        for (final socket in sockets)
          if (socket.socket == AppEntryRole.appArgs) socket,
      ];
      expect(
        [for (final arg in args) '${arg.argName}: ${arg.fragment!.code}'],
        [
          'theme: createLightTheme()',
          'darkTheme: createDarkTheme()',
          'themeMode: ThemeModeScope.of(context).mode',
        ],
      );
      expect(
        [for (final arg in args) arg.fragment!.imports],
        [
          [_appTheme],
          [_appTheme],
          [_themeMode],
        ],
      );
      for (final contribution in [wrapper, ...args]) {
        expect(contribution.when, isEmpty);
      }
    });

    test(
        'gives the preferences the restorer of the mode, in every app, since '
        'the role requires them', () {
      final restorer = _contributions()
          .whereType<SocketContribution>()
          .singleWhere((socket) => socket.socket == PreferencesRole.restorers);

      expect(restorer.fragment!.code, 'restoreThemeMode');
      expect(restorer.fragment!.imports, [_themeMode]);
      expect(restorer.when, isEmpty);
    });

    test('puts nothing else into a socket, and adds no package to the app', () {
      expect(_contributions().whereType<SocketContribution>(), hasLength(5));
      expect(_contributions().whereType<PubspecContribution>(), isEmpty);
    });

    test(
        'generates the file of the mode in every app, and the file of the '
        'entry of the settings screen only in an app with one', () async {
      final bricks = _contributions().whereType<BrickContribution>().toList();
      expect(
        [for (final brick in bricks) brick.bundle.name],
        [themeRoleBundle.name, themeRoleSettingBundle.name],
      );
      expect(
        [for (final brick in bricks) brick.when],
        [
          isEmpty,
          {settingsScreenRole},
        ],
      );

      for (final settings in [false, true]) {
        for (final localized in [false, true]) {
          final rendered = await renderTemplate(
            themeRole,
            present: _rolesOf(settings: settings, localized: localized),
          );

          expect(
            rendered.files.keys,
            [
              ThemeRole.themeModeFile,
              if (settings) ThemeRole.themeModeSettingFile,
            ],
            reason: 'settings: $settings, localized: $localized',
          );
          rendered.files.values.forEach(expectParses);
        }
      }
    });

    test(
        'gives the settings screen role one entry, the widget of the file '
        'that it generates for an app with a settings screen', () {
      final data = _dataFor(settingsScreenRole);
      final input = inputOf(
        settingsScreenRole,
        data: data,
        present: {routerRole},
      );

      expect(settingsScreenRole.template.validate(input), isEmpty);
      final entry = settingsScreenRole.entriesIn(input).single;
      expect(entry.widget.name, 'ThemeModeSetting');
      expect(entry.file, ThemeRole.themeModeSettingFile);
      expect(
        templatesOf(themeRoleSettingBundle).keys,
        [ThemeRole.themeModeSettingFile],
      );
      // The data needs no condition: it applies only with the role.
      expect(data.single.when, isEmpty);
    });

    test(
        'gives the localization role the texts of the entry, in English and '
        'in Ukrainian, only in an app with a settings screen', () {
      final data = _dataFor(localizationRole);
      // An app without a settings screen has no entry to read the texts, so
      // the role gets none of them there.
      expect(data.single.when, {settingsScreenRole});
      expect(
        localizationRole.textsIn(inputOf(localizationRole, data: data)),
        isEmpty,
      );
      final input = inputOf(
        localizationRole,
        data: data,
        present: {settingsScreenRole},
      );

      expect(localizationRole.template.validate(input), isEmpty);
      expect(
        [
          for (final text in localizationRole.textsIn(input))
            (
              name: text.text.name,
              getter: text.getter,
              en: text.text.en,
              uk: text.text.translations['uk'],
            ),
        ],
        _texts,
      );
      for (final text in localizationRole.textsIn(input)) {
        expect(text.text.languages, ['en', 'uk'], reason: text.text.name);
        expect(text.owner, _template);
      }
      expect(localizationRole.localesIn(input), ['en', 'uk']);
    });

    test(
        'reads the texts of the entry from the texts of the app in an app '
        'with the localization role, and writes them in English in an app '
        'without it', () {
      RoleOutput output({required bool localized}) => themeRole.template.render(
            inputOf(
              themeRole,
              present: _rolesOf(settings: true, localized: localized),
            ),
          );
      // The code of each fragment variable, and the imports that it needs.
      Map<String, Map<String, Object>> texts(RoleOutput output) => {
            for (final MapEntry(:key, :value) in output.vars.entries)
              if (value is Fragment)
                key: {'code': value.code, 'imports': value.imports},
          };

      final withRole = output(localized: true);
      expect(texts(withRole), {
        for (final text in _texts)
          'text_${text.name}': {
            'code': 'context.l10n.${text.getter}',
            'imports': [_appTexts],
          },
      });
      final without = output(localized: false);
      expect(texts(without), {
        for (final text in _texts)
          'text_${text.name}': {
            'code': "'${text.en}'",
            'imports': isEmpty,
          },
      });

      for (final rendered in [withRole, without]) {
        // The key of the mode, as the code of a text.
        expect(rendered.vars['mode_key'], "'theme.mode'");
        expect(rendered.vars, hasLength(_texts.length + 1));
        expect(rendered.fragments, isEmpty);
        expect(rendered.files, isEmpty);
      }
    });
  });

  group('the mode of the theme role', () {
    test(
        'is in code that type-checks, next to the preferences of the app, '
        'which take its restorer', () async {
      final app = await _app();
      addTearDown(app.delete);

      expect(await app.analysisProblems(), isEmpty);
    });

    test(
        'follows the device until the user selects another; a choice changes '
        'the mode at once and tells the listeners, and is saved by its name '
        'once the preferences are open, also when the app is in that mode '
        'already', () async {
      final app = await _app();
      addTearDown(app.delete);

      expect(await app.run(_choices), {
        'at first': 'system',
        'a choice before the preferences are open': {
          'mode': 'dark',
          'heard': ['dark'],
          'saved': null,
          'writes': <Object?>[],
        },
        // Nothing is saved, so the mode that the app is in stays, and the
        // listeners hear nothing.
        'the start with nothing saved': {
          'mode': 'dark',
          'heard': <Object?>[],
          'saved': null,
        },
        'the choice of the mode that the app is in': {
          'heard': <Object?>[],
          'saved': 'dark',
        },
        'a choice whose write is on its way': {
          'mode': 'light',
          'heard': ['light'],
          'saved': 'dark',
        },
        'a choice whose future completed': {'saved': 'light'},
        'writes': [
          'open 1: ${ThemeRole.modeKey} = dark',
          'open 1: ${ThemeRole.modeKey} = light',
        ],
      });
    });

    test(
        'is the saved one after a start of the app, and stays as it is when '
        'nothing is saved or when what is saved is no name of a mode; then '
        'the preferences opened last get the writes', () async {
      final app = await _app();
      addTearDown(app.delete);

      expect(await app.run(_starts), {
        'with dark saved': {
          'mode': 'dark',
          'heard': ['dark'],
        },
        'with dark saved again': {'mode': 'dark', 'heard': <Object?>[]},
        'with light saved': {
          'mode': 'light',
          'heard': ['light'],
        },
        'with nothing saved': {'mode': 'light', 'heard': <Object?>[]},
        'with no name of a mode saved': {'mode': 'light', 'heard': <Object?>[]},
        'with a number saved': {'mode': 'light', 'heard': <Object?>[]},
        'with system saved': {
          'mode': 'system',
          'heard': ['system'],
        },
        'writes': ['open 7: ${ThemeRole.modeKey} = dark'],
        // No restorer failed.
        'printed': <Object?>[],
      });
    });

    test(
        'is saved through the preferences of a start that found the mode of '
        'the app saved, and so changed nothing', () async {
      final app = await _app();
      addTearDown(app.delete);

      expect(await app.run(_startWithTheModeSaved), {
        'the start': {'mode': 'system', 'heard': <Object?>[]},
        'a choice after it': {
          'saved': 'dark',
          'writes': ['open 1: ${ThemeRole.modeKey} = dark'],
        },
      });
    });

    test(
        'changes at once also when the preferences fail to save it: the '
        'choice fails with their error, the same choice again saves it, and '
        'the next start has the mode that was saved last', () async {
      final app = await _app();
      addTearDown(app.delete);

      expect(await app.run(_failedWrites), {
        'a write that is saved': {
          'error': null,
          'mode': 'dark',
          'heard': ['dark'],
          'saved': 'dark',
        },
        'a write that fails': {
          'error': 'The write fails.',
          'mode': 'light',
          'heard': ['light'],
          'saved': 'dark',
        },
        // The app is in the mode already, and the choice still saves it.
        'the same choice again': {
          'error': null,
          'mode': 'light',
          'heard': <Object?>[],
          'saved': 'light',
        },
        'a write that throws': {
          'error': 'The write throws.',
          'mode': 'system',
          'heard': ['system'],
          'saved': 'light',
        },
        'the next start': {
          'mode': 'light',
          'heard': ['light'],
        },
      });
    });

    test(
        'comes from the scope around the context that asks for it, which '
        'rebuilds its widget when the mode changes; below no scope there is '
        'none', () async {
      final app = await _app();
      addTearDown(app.delete);

      expect(await app.run(_scope), {
        'below the scope': {
          'the controller of the app': true,
          // The context makes its widget depend on what it is asked for.
          'asked of the context': ['ThemeModeScope'],
        },
        'below no scope': 'no controller',
        'asked of the context below no scope': ['ThemeModeScope'],
      });
    });
  });

  group('the entry of the theme mode on the settings screen', () {
    /// The file of the entry in an app with a settings screen, parsed, with
    /// its calls.
    Future<(CompilationUnit, Map<String, List<MethodInvocation>>)> entry({
      required bool localized,
    }) async {
      final rendered = await renderTemplate(
        themeRole,
        present: _rolesOf(settings: true, localized: localized),
      );
      final unit = parseString(
        content: rendered.files[ThemeRole.themeModeSettingFile]!,
      ).unit;
      final calls = _Calls();
      unit.accept(calls);
      return (unit, calls.byName);
    }

    test(
        'is a widget that the settings screen creates as a constant, '
        'without arguments', () async {
      final (unit, _) = await entry(localized: false);

      final widget = unit.declarations.whereType<ClassDeclaration>().single;
      expect(
        widget.namePart.typeName.lexeme,
        settingsScreenRole
            .entriesIn(
              inputOf(
                settingsScreenRole,
                data: _dataFor(settingsScreenRole),
                present: {routerRole},
              ),
            )
            .single
            .widget
            .name,
      );
      expect(widget.extendsClause!.superclass.toSource(), 'StatelessWidget');
      final constructor =
          widget.body.members.whereType<ConstructorDeclaration>().single;
      expect(constructor.constKeyword, isNotNull);
      expect(constructor.name, isNull);
      expect(
        [
          for (final parameter in constructor.parameters.parameters)
            (parameter.name?.lexeme, parameter.isRequired),
        ],
        [('key', false)],
      );
    });

    test(
        'offers the three modes in a group whose choice is the mode of the '
        'app, and selects the one that the user picks', () async {
      final (_, calls) = await entry(localized: false);

      final group = calls['RadioGroup']!.single;
      expect(group.typeArguments!.toSource(), '<ThemeMode>');
      expect(_argumentsOf(group)['groupValue'], 'controller.mode');
      expect(calls['of']!.single.toSource(), 'ThemeModeScope.of(context)');
      expect(calls['select']!.single.toSource(), 'controller.select(mode)');
      expect(
        [
          for (final option in calls['RadioListTile']!)
            (
              option.typeArguments!.toSource(),
              _argumentsOf(option)['value'],
            ),
        ],
        [
          ('<ThemeMode>', 'ThemeMode.system'),
          ('<ThemeMode>', 'ThemeMode.light'),
          ('<ThemeMode>', 'ThemeMode.dark'),
        ],
      );
    });

    for (final localized in [true, false]) {
      final how = localized
          ? 'from the texts of the app, in an app with the localization role'
          : 'in English, in an app without the localization role';

      test('shows its title and the name of each mode $how', () async {
        final (unit, calls) = await entry(localized: localized);
        String code(_Text text) =>
            localized ? 'context.l10n.${text.getter}' : "'${text.en}'";

        final shown = calls['Text']!;
        for (final text in shown) {
          expect(
            _inConstant(text),
            isFalse,
            reason: 'The code that reads a text of the app is no constant: '
                '${text.toSource()}',
          );
        }
        // The title, and then the name of each mode.
        expect(
          [for (final text in shown) text.toSource()],
          [for (final text in _texts) 'Text(${code(text)})'],
        );
        expect(
          [
            for (final option in calls['RadioListTile']!)
              _argumentsOf(option)['title'],
          ],
          [for (final text in _texts.skip(1)) 'Text(${code(text)})'],
        );
        expect(
          [
            for (final directive
                in unit.directives.whereType<ImportDirective>())
              directive.uri.stringValue,
          ],
          [
            'package:flutter/material.dart',
            'theme_mode.dart',
            if (localized) _appTexts.resolveUri(testContext.appName),
          ],
        );
      });
    }
  });
}
