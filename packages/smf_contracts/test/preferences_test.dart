@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'dart_files.dart';
import 'role_support.dart';
import 'support.dart';

/// The file of the fake implementation of the preferences in the test app.
const _fakeFile = ImportRef.app('fakes/fake_preferences.dart');

/// The file of the restorers of the test app.
const _restorersFile = ImportRef.app('fakes/restorers.dart');

/// The implementation of the preferences of the test app: one that opens
/// asynchronously, or one created with the app.
RoleImplementation _implementation({required bool async}) => async
    ? const RoleImplementation.async(
        type: TypeRef('FakePreferences', import: _fakeFile),
        init: FactoryRef('openFakePreferences', import: _fakeFile),
      )
    : const RoleImplementation(
        type: TypeRef('FakePreferences', import: _fakeFile),
        create: FactoryRef('createFakePreferences', import: _fakeFile),
      );

/// The [_implementation] as the data of the provider of the test app.
RoleData<Object> _data({required bool async}) => dataOf(
      preferencesRole,
      _implementation(async: async),
      module: 'fake_preferences',
    );

/// The restorers that two modules of the test app put into the socket of the
/// role: a function, and a function expression that calls another.
const List<SocketContribution> _restorers = [
  SocketContribution.item(
    PreferencesRole.restorers,
    Fragment('restoreFirst', imports: [_restorersFile]),
  ),
  SocketContribution.item(
    PreferencesRole.restorers,
    Fragment(
      '(preferences) => restoreSecond(preferences)',
      imports: [_restorersFile],
    ),
  ),
];

/// A fake implementation of the preferences over a map that stands for the
/// disk: each open reads the map anew.
const _fakePreferences = '''
import '../core/preferences/app_preferences.dart';

/// What the preferences have saved.
final Map<String, Object> disk = {};

/// How many times the preferences were opened.
int opened = 0;

/// Whether the preferences fail to open.
bool openFails = false;

Future<AppPreferences> openFakePreferences() async {
  await Future<void>.delayed(Duration.zero);
  return createFakePreferences();
}

AppPreferences createFakePreferences() {
  if (openFails) throw StateError('The preferences do not open.');
  opened++;
  return FakePreferences(Map.of(disk));
}

final class FakePreferences implements AppPreferences {
  FakePreferences(this._values);

  final Map<String, Object> _values;

  T? _get<T>(String key) => switch (_values[key]) {
        final T value => value,
        _ => null,
      };

  Future<void> _set(String key, Object value) async {
    _values[key] = value;
    disk[key] = value;
  }

  @override
  String? getString(String key) => _get(key);

  @override
  bool? getBool(String key) => _get(key);

  @override
  int? getInt(String key) => _get(key);

  @override
  double? getDouble(String key) => _get(key);

  @override
  List<String>? getStringList(String key) => switch (_values[key]) {
        final List<String> list => List.of(list),
        _ => null,
      };

  @override
  Future<void> setString(String key, String value) => _set(key, value);

  @override
  Future<void> setBool(String key, bool value) => _set(key, value);

  @override
  Future<void> setInt(String key, int value) => _set(key, value);

  @override
  Future<void> setDouble(String key, double value) => _set(key, value);

  @override
  Future<void> setStringList(String key, List<String> value) =>
      _set(key, List.of(value));

  @override
  Future<void> remove(String key) async {
    _values.remove(key);
    disk.remove(key);
  }
}
''';

/// The restorers of the test app, which note what they read and the
/// preferences they got, and throw after that when told.
const _restorersText = r'''
import '../core/preferences/app_preferences.dart';

/// What the restorers read, in the order they ran.
final List<String> restored = [];

/// The preferences that the restorers got, in the order they ran.
final List<AppPreferences> got = [];

/// Whether the restorers throw once they noted what they read.
bool restorersThrow = false;

void restoreFirst(AppPreferences preferences) => _restore('first', preferences);

void restoreSecond(AppPreferences preferences) =>
    _restore('second', preferences);

void _restore(String name, AppPreferences preferences) {
  restored.add('$name: ${preferences.getInt('fake.count')}');
  got.add(preferences);
  if (restorersThrow) throw StateError('The $name restorer throws.');
}
''';

/// Starts the test app, starts it again with restorers that throw, and
/// then with preferences that do not open, and sends back what happened.
///
/// It imports only the file of the role and the fakes, which need nothing
/// but Dart and the stand-in for Flutter's foundation library.
const _script = '''
import 'dart:isolate';

import 'package:flutter/foundation.dart';
import 'package:my_app/core/preferences/app_preferences.dart';
import 'package:my_app/fakes/fake_preferences.dart';
import 'package:my_app/fakes/restorers.dart';

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};
  try {
    createAppPreferences();
    result['before the start'] = 'preferences';
  } on Error {
    result['before the start'] = 'no preferences';
  }

  disk['fake.count'] = 1;
  await initPreferences();
  final first = createAppPreferences();
  result['the start'] = [...restored];
  result['the restorers got the preferences of the app'] =
      got.every((preferences) => identical(preferences, first));
  result['the app has the same preferences each time'] =
      identical(createAppPreferences(), first);
  result['opened at the start'] = opened;

  restored.clear();
  got.clear();
  await first.setInt('fake.count', 2);
  restorersThrow = true;
  await initPreferences();
  final second = createAppPreferences();
  result['the next start'] = [...restored];
  result['the restorers got the preferences opened anew'] =
      !identical(second, first) &&
          got.every((preferences) => identical(preferences, second));
  result['opened at the next start'] = opened;
  result['printed'] = [...debugPrinted];

  restored.clear();
  restorersThrow = false;
  openFails = true;
  try {
    await initPreferences();
    result['a failed open'] = 'initPreferences() completed';
  } on StateError catch (error) {
    result['a failed open'] = error.message;
  }
  result['restored after a failed open'] = [...restored];
  port.send(result);
}
''';

/// What the app prints when the restorer [name] of the test app throws.
String _printedFor(String name) =>
    'A restorer of the preferences failed: Bad state: The $name restorer '
    'throws.';

/// What [_script] sends back from the app of a template that works.
final Map<String, Object?> _expected = {
  'before the start': 'no preferences',
  'the start': ['first: 1', 'second: 1'],
  'the restorers got the preferences of the app': true,
  'the app has the same preferences each time': true,
  'opened at the start': 1,
  // Both restorers throw, and each still ran, with what was saved.
  'the next start': ['first: 2', 'second: 2'],
  'the restorers got the preferences opened anew': true,
  'opened at the next start': 2,
  'printed': [_printedFor('first'), _printedFor('second')],
  'a failed open': 'The preferences do not open.',
  'restored after a failed open': <Object?>[],
};

/// The file of the role in the test app, rendered with an implementation
/// that opens asynchronously, or one created with the app, and the
/// restorers, and what its template puts into other sockets.
Future<RenderedTemplate> _rendered({required bool async}) => renderTemplate(
      preferencesRole,
      data: [_data(async: async)],
      fromModules: _restorers,
    );

/// The files of the test app with the file of the role [code].
DartFiles _appWith(String code) => DartFiles.write({
      PreferencesRole.file: code,
      'lib/fakes/fake_preferences.dart': _fakePreferences,
      'lib/fakes/restorers.dart': _restorersText,
    });

/// The top-level functions of [unit], by name.
Map<String, FunctionDeclaration> _functionsOf(CompilationUnit unit) => {
      for (final function in unit.declarations.whereType<FunctionDeclaration>())
        function.name.lexeme: function,
    };

/// The top-level variables of [unit], by name, each as its declaration.
Map<String, String> _variablesOf(CompilationUnit unit) => {
      for (final declaration
          in unit.declarations.whereType<TopLevelVariableDeclaration>())
        for (final variable in declaration.variables.variables)
          variable.name.lexeme: declaration.toSource(),
    };

/// The statements of the body of [function].
List<String> _statementsOf(FunctionDeclaration function) => [
      for (final statement
          in (function.functionExpression.body as BlockFunctionBody)
              .block
              .statements)
        '$statement',
    ];

void main() {
  group('the preferences role', () {
    test(
        'takes one provider, works with a DI container, and has a socket of '
        'its implementation and one of the restorers of the modules', () {
      expect(preferencesRole.id, 'preferences');
      expect(preferencesRole.presenceFlag, 'has_preferences');
      expect('$preferencesRole', 'preferences role');
      expect(preferencesRole.cardinality, RoleCardinality.atMostOne);
      expect(preferencesRole.requires, isEmpty);
      expect(preferencesRole.uses, {diRole});
      expect(preferencesRole.sockets, const [
        PreferencesRole.implementations,
        PreferencesRole.restorers,
      ]);
      expect(
        PreferencesRole.implementations.tag,
        'smf_preferences__implementations',
      );
      expect(PreferencesRole.restorers.tag, 'smf_preferences__restorers');
      expect(PreferencesRole.restorers.kind, isA<FactoryListSocket>());
      expect(preferencesRole.interface.files, [
        'lib/core/preferences/app_preferences.dart',
      ]);
      expect(preferencesRole.interface.symbols, isEmpty);
      expect(
        [for (final rule in preferencesRole.moduleRules) rule.id],
        ['services.implementations'],
      );
      expect(
        [for (final rule in preferencesRole.structuralRules) rule.id],
        ['preferences.factory_calls', 'preferences.implementation_factories'],
      );
    });
  });

  group('the preferences template', () {
    test(
        'generates the interface of the preferences: a read of each type, a '
        'write of each type, and remove', () async {
      final rendered = await _rendered(async: true);
      final unit = parseString(
        content: rendered.files[PreferencesRole.file]!,
      ).unit;

      final interface = unit.declarations.whereType<ClassDeclaration>().single;
      expect(interface.namePart.typeName.lexeme, 'AppPreferences');
      expect(interface.interfaceKeyword, isNotNull);
      expect(interface.abstractKeyword, isNotNull);
      expect(
        [
          for (final member in interface.body.members)
            if (member is MethodDeclaration)
              '${member.returnType} ${member.name.lexeme}${member.parameters}',
        ],
        [
          'String? getString(String key)',
          'bool? getBool(String key)',
          'int? getInt(String key)',
          'double? getDouble(String key)',
          'List<String>? getStringList(String key)',
          'Future<void> setString(String key, String value)',
          'Future<void> setBool(String key, bool value)',
          'Future<void> setInt(String key, int value)',
          'Future<void> setDouble(String key, double value)',
          'Future<void> setStringList(String key, List<String> value)',
          'Future<void> remove(String key)',
        ],
      );
      final factory = _functionsOf(unit)['createAppPreferences']!;
      expect('${factory.returnType}', 'AppPreferences');
      expect(factory.functionExpression.parameters!.parameters, isEmpty);
      final body = factory.functionExpression.body as ExpressionFunctionBody;
      expect('${body.expression}', '_appPreferences');
    });

    test(
        'opens an implementation that starts asynchronously in '
        'initPreferences(), then calls the restorers, and awaits it in the '
        'platform phase of bootstrap()', () async {
      final rendered = await _rendered(async: true);
      final code = rendered.files[PreferencesRole.file]!;
      final unit = parseString(content: code).unit;

      final init = _functionsOf(unit)['initPreferences']!;
      expect('${init.returnType}', 'Future<void>');
      expect(init.functionExpression.parameters!.parameters, isEmpty);
      expect(_statementsOf(init), [
        '_appPreferences = await impl0.openFakePreferences();',
        '_restore(_appPreferences);',
      ]);
      // Not final: initPreferences() may run again.
      expect(
        _variablesOf(unit)['_appPreferences'],
        'late AppPreferences _appPreferences;',
      );
      expect(
        code,
        contains(
          "import 'package:my_app/fakes/fake_preferences.dart' as impl0;",
        ),
      );
      final start = rendered.elsewhere.single;
      expect(start.socket, AppEntryRole.bootstrapPlatform);
      expect(start.fragment!.code, 'await initPreferences();');
      expect(start.fragment!.imports, [
        const ImportRef.app('core/preferences/app_preferences.dart'),
      ]);
    });

    test(
        'opens an implementation created with the app in initPreferences() '
        'too, which bootstrap() awaits as well, so that the restorers run '
        'before the first frame with any provider', () async {
      final rendered = await _rendered(async: false);
      final unit = parseString(
        content: rendered.files[PreferencesRole.file]!,
      ).unit;

      final init = _functionsOf(unit)['initPreferences']!;
      expect('${init.returnType}', 'Future<void>');
      expect(_statementsOf(init), [
        '_appPreferences = impl0.createFakePreferences();',
        '_restore(_appPreferences);',
      ]);
      expect(
        _variablesOf(unit)['_appPreferences'],
        'late AppPreferences _appPreferences;',
      );
      final start = rendered.elsewhere.single;
      expect(start.socket, AppEntryRole.bootstrapPlatform);
      expect(start.fragment!.code, 'await initPreferences();');
    });

    test(
        'renders the restorers of the modules as a list of functions, in '
        'their order, with the imports of their files', () async {
      final rendered = await _rendered(async: true);
      final code = rendered.files[PreferencesRole.file]!;
      final unit = parseString(content: code).unit;

      expect(
        _variablesOf(unit)['_restorers'],
        'final List<void Function(AppPreferences preferences)> _restorers = '
        '[restoreFirst, (preferences) => restoreSecond(preferences)];',
      );
      expect(code, contains("import 'package:my_app/fakes/restorers.dart';"));

      // Without restorers, the list is empty, and the file still compiles.
      final without = await renderTemplate(
        preferencesRole,
        data: [_data(async: true)],
      );
      expect(
        _variablesOf(
          parseString(content: without.files[PreferencesRole.file]!).unit,
        )['_restorers'],
        'final List<void Function(AppPreferences preferences)> _restorers = '
        '[];',
      );
    });

    for (final async in [true, false]) {
      final how = async ? 'that starts asynchronously' : 'created with the app';

      test('generates code that type-checks, with an implementation $how',
          () async {
        final rendered = await _rendered(async: async);
        final app = _appWith(rendered.files[PreferencesRole.file]!);
        addTearDown(app.delete);

        expect(await app.analysisProblems(), isEmpty);
      });

      test(
          'with an implementation $how, gives the preferences to each '
          'restorer at the start and again at the next start, each on its '
          'own, and fails the start when the preferences do not open',
          () async {
        final rendered = await _rendered(async: async);
        final app = _appWith(rendered.files[PreferencesRole.file]!);
        addTearDown(app.delete);

        expect(await app.run(_script), _expected);
      });
    }

    test('starts an app without restorers too', () async {
      final rendered = await renderTemplate(
        preferencesRole,
        data: [_data(async: false)],
      );
      final app = _appWith(rendered.files[PreferencesRole.file]!);
      addTearDown(app.delete);

      expect(await app.analysisProblems(), isEmpty);
      expect(await app.run(_script), {
        ..._expected,
        'the start': <Object?>[],
        'the next start': <Object?>[],
        'printed': <Object?>[],
      });
    });
  });

  group('the sockets of the preferences role', () {
    /// The issues of the module rule of the role for a module that
    /// [provides] the role or uses it, with [contributions].
    List<SmfIssue> issuesOf(
      List<Contribution> contributions, {
      required bool provides,
    }) =>
        preferencesRole.checkModule(
          ModuleRuleRequest(
            hook: RoleHookRequest(
              data: [
                if (provides)
                  preferencesRole
                      .data(_implementation(async: true))
                      .withOrigin(const ModuleOrigin(ModuleId('vendor'))),
              ],
              presentRoles: {preferencesRole},
              context: testContext,
            ),
            module: ModuleDescriptor(
              id: const ModuleId('vendor'),
              description: 'Vendor',
              kind: ModuleKinds.infrastructure,
              providers: [
                if (provides) const RoleProvider.plain(preferencesRole),
              ],
              uses: {if (!provides) preferencesRole},
            ),
            contributions: contributions,
          ),
        );

    test(
        'take the restorers of the modules that use the role, and of its '
        'provider', () {
      for (final provides in [false, true]) {
        expect(
          issuesOf(_restorers, provides: provides),
          isEmpty,
          reason: provides ? 'a provider' : 'a module that uses the role',
        );
      }
    });

    test('take no code for the implementation, which the template renders', () {
      for (final provides in [false, true]) {
        final issue = issuesOf(
          const [
            SocketContribution.code(
              PreferencesRole.implementations,
              Fragment('late AppPreferences _appPreferences;'),
            ),
            ..._restorers,
          ],
          provides: provides,
        ).single;

        expect(
          issue.message,
          contains('socket preferences.implementations'),
        );
        expect(issue.hint, contains('RoleImplementation'));
        expect(issue.origin, const ModuleOrigin(ModuleId('vendor')));
      }
    });
  });
}
