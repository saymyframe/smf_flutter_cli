@TestOn('vm')
library;

import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_get_it/smf_get_it.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:smf_shared_preferences/bundles/shared_preferences_bundle.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';
import 'package:smf_shared_preferences/src/agents.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/dart_app.dart';

/// The modules of the tests: flutter_core, which creates the app, this
/// module, and get_it, a DI container, which registers the preferences in
/// the apps that have it.
const List<SmfModule> _modules = [
  FlutterCoreModule(),
  SharedPreferencesModule(),
  GetItModule(),
];

/// The path of the file of the module.
const _implementation = 'lib/core/preferences/shared_app_preferences.dart';

/// The owners of the code of the preferences: the template of the role and
/// this module.
final Set<ContributionOrigin> _preferences = {
  const RoleTemplateOrigin(preferencesRole),
  const ModuleOrigin(SharedPreferencesModule.id),
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

/// The pubspec of [app] without the dependency on shared_preferences.
Map<String, Object?> _pubspecWithoutPackage(RenderedApp app) {
  final pubspec = _yamlOf(app.files['pubspec.yaml']!.text);
  final dependencies = {
    ...pubspec['dependencies']! as Map<String, Object?>,
  }..remove('shared_preferences');
  return {...pubspec, 'dependencies': dependencies};
}

/// The modules that provide [role] in the app of [result], whichever they
/// are.
Set<ModuleId> _providersOf(ContractResult result, Role role) => {
      for (final module in result.resolution!.providersOf(role)) module.id,
    };

/// The registrations of the DI role in the app of [result], as the provider
/// of the role gets them to render.
List<RoleData<DiRegistration>> _registrationsOf(ContractResult result) =>
    diRole.graphOf(diRole.hookInput(result.hook!)).registrations;

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

/// The code that the modules and the templates of the roles put into the
/// phases of start-up in the app of [result], phase after phase, each as
/// its contributor and its code: what `bootstrap()` runs, whichever module
/// provides the app entry.
List<String> _startUpOf(ContractResult result) => [
      for (final phase in const [
        AppEntryRole.bootstrapEarly,
        AppEntryRole.bootstrapPlatform,
        AppEntryRole.bootstrapDi,
        AppEntryRole.bootstrapLate,
      ])
        ..._contributionsTo(result, phase),
    ];

/// Whether [a] and [b] are the same bytes.
bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var index = 0; index < a.length; index++) {
    if (a[index] != b[index]) return false;
  }
  return true;
}

/// The notes of the guide for coding agents of [app], in the order they
/// were contributed, each as its contributor, the heading of its section
/// and the note.
List<(ContributionOrigin, String, AgentNote)> _agentNotesOf(RenderedApp app) =>
    [
      for (final collected
          in app.socketOrders[AppEntryRole.agentSections]?.contributions ??
              const <Collected>[])
        if (collected.contribution case final SocketContribution note)
          (collected.origin, note.entryKey!, note.entryValue! as AgentNote),
    ];

/// The inline code of [markdown]: what stands between two backticks.
Set<String> _codeOf(String markdown) => {
      for (final match in RegExp('`([^`]+)`').allMatches(markdown)) match[1]!,
    };

/// Checks that [app] is [without] but for the files of the preferences, the
/// dependency on shared_preferences, the section of the preferences in the
/// guide for coding agents, and one file of each of the modules [changedBy],
/// whichever they are: the provider of the app entry renders the start-up,
/// which now opens the preferences, into a file of its own, and a DI
/// container the registration of the preferences.
void _expectTheAppWithout(
  RenderedApp app,
  RenderedApp without, {
  required Set<ModuleId> changedBy,
}) {
  expect(
    app.files.keys.toSet(),
    {...without.files.keys, PreferencesRole.file, _implementation},
  );
  expect(
    app.files[PreferencesRole.file]!.owner,
    const RoleTemplateOrigin(preferencesRole),
  );
  expect(
    app.files[_implementation]!.owner,
    const ModuleOrigin(SharedPreferencesModule.id),
  );
  // The guide has the notes of the app without the preferences, and in the
  // section of the preferences what the role says and what the module adds.
  final notes = _agentNotesOf(app);
  expect(
    notes.where((note) => !_preferences.contains(note.$1)),
    _agentNotesOf(without),
  );
  expect(
    [
      for (final (origin, heading, note) in notes)
        if (_preferences.contains(origin)) (origin, heading, note.isOfRole),
    ],
    unorderedEquals([
      (
        const ModuleOrigin(SharedPreferencesModule.id),
        preferencesRole.description,
        false,
      ),
      (
        const RoleTemplateOrigin(preferencesRole),
        preferencesRole.description,
        true,
      ),
    ]),
  );
  final changed = <ModuleId>[];
  for (final MapEntry(key: path, value: file) in without.files.entries) {
    if (path == 'pubspec.yaml' || path == AppEntryRole.agentsFile) continue;
    expect(app.files[path]!.owner, file.owner, reason: path);
    if (file.owner case ModuleOrigin(:final module)
        when changedBy.contains(module)) {
      if (!_sameBytes(app.files[path]!.bytes, file.bytes)) changed.add(module);
      continue;
    }
    expect(app.files[path]!.bytes, file.bytes, reason: path);
  }
  expect(changed, unorderedEquals(changedBy));
  expect(
    _pubspecWithoutPackage(app),
    _yamlOf(without.files['pubspec.yaml']!.text),
  );
}

/// The parsed file at [path] of [app].
CompilationUnit _unitOf(RenderedApp app, String path) =>
    parseString(content: app.files[path]!.text).unit;

/// The methods of the class [name] in [unit], by name.
Map<String, MethodDeclaration> _methodsOf(CompilationUnit unit, String name) {
  final declaration =
      unit.declarations.whereType<ClassDeclaration>().singleWhere(
            (declaration) => declaration.namePart.typeName.lexeme == name,
          );
  return {
    for (final member in declaration.body.members)
      if (member is MethodDeclaration) member.name.lexeme: member,
  };
}

/// Starts the app with what an earlier launch saved, saves, reads and
/// removes values through the preferences of the app, starts it again, and
/// sends back what the preferences read and what reached the platform.
///
/// It imports only the file of the preferences role, which needs nothing
/// but the stand-ins for Flutter's foundation library and for
/// shared_preferences.
const _script = r'''
import 'dart:isolate';

import 'package:contract_app/core/preferences/app_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// [value] with its type, such as `double 2.0`: an int and a double of the
/// same number are equal, and so are lists of any type with equal items.
String typed(Object? value) => '${value.runtimeType} $value';

Future<void> main(List<String> arguments, SendPort port) async {
  final result = <String, Object?>{};
  platformPreferences['theme.mode'] = 'dark';
  // Lists in the forms that the platforms return them in when the
  // preferences are opened: a list of objects, as iOS does, and a list that
  // casts each item to a text as it is read, as Android does; and one of
  // each with an item that is no text.
  platformPreferences['ios.list'] = <Object?>['a', 'b'];
  platformPreferences['android.list'] = <Object?>['a', 'b'].cast<String>();
  platformPreferences['ios.mixed'] = <Object?>['a', 1];
  platformPreferences['android.mixed'] = <Object?>['a', 1].cast<String>();
  await initPreferences();
  final preferences = createAppPreferences();
  result['implementation'] = '${preferences.runtimeType}';
  result['saved by an earlier launch'] = preferences.getString('theme.mode');
  result['lists as the platforms return them'] = {
    for (final key in const [
      'ios.list',
      'android.list',
      'ios.mixed',
      'android.mixed',
    ])
      key: () {
        try {
          return typed(preferences.getStringList(key));
        } on Error catch (error) {
          return 'threw $error';
        }
      }(),
  };

  await preferences.setString('a.text', 'text');
  await preferences.setBool('a.flag', true);
  await preferences.setInt('a.count', 3);
  await preferences.setDouble('a.ratio', 1.5);
  // A whole number, saved as a double.
  await preferences.setDouble('a.whole', 2);
  final given = ['a', 'b'];
  await preferences.setStringList('a.list', given);
  result['read back'] = [
    typed(preferences.getString('a.text')),
    typed(preferences.getBool('a.flag')),
    typed(preferences.getInt('a.count')),
    typed(preferences.getDouble('a.ratio')),
    typed(preferences.getDouble('a.whole')),
    typed(preferences.getStringList('a.list')),
  ];
  result['on the platform'] = {
    for (final key in const [
      'a.text',
      'a.flag',
      'a.count',
      'a.ratio',
      'a.whole',
      'a.list',
    ])
      key: typed(platformPreferences[key]),
  };

  // A number is read only as the type that it was saved as.
  result['a number as the other type of numbers'] = [
    preferences.getDouble('a.count'),
    preferences.getInt('a.whole'),
  ];

  // A read of a key with a value of another type, which the reads of
  // shared_preferences throw on.
  try {
    result['as another type'] = [
      preferences.getInt('a.text'),
      preferences.getString('a.flag'),
      preferences.getBool('a.count'),
      preferences.getStringList('a.ratio'),
      preferences.getDouble('a.list'),
      preferences.getString('a.missing'),
    ];
  } on Error catch (error) {
    result['as another type'] = 'threw $error';
  }

  // The lists of the caller and of the preferences.
  given.add('c');
  final read = preferences.getStringList('a.list')!..add('d');
  result['a list of their own'] = [
    preferences.getStringList('a.list'),
    !identical(platformPreferences['a.list'], given),
    read,
  ];

  await preferences.remove('a.count');
  result['removed'] = [
    preferences.getInt('a.count'),
    platformPreferences.containsKey('a.count'),
  ];

  // The next start opens the preferences anew.
  await initPreferences();
  final next = createAppPreferences();
  result['the next start'] = [
    !identical(next, preferences),
    created,
    typed(next.getString('a.text')),
    typed(next.getStringList('a.list')),
    typed(next.getDouble('a.whole')),
    next.getInt('a.whole'),
    next.getInt('a.count'),
  ];
  port.send(result);
}
''';

void main() {
  const module = SharedPreferencesModule();

  group('SharedPreferencesModule', () {
    test('is infrastructure that provides the preferences role', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('shared_preferences'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {preferencesRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.effectiveUses, {diRole});
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
    });

    test(
        'contributes its brick, shared_preferences, its implementation of '
        'the preferences, which opens asynchronously, and its note for '
        'coding agents, and nothing else', () {
      final contributions = module.contribute(ContractHarness.defaultContext);

      expect(contributions, hasLength(4));
      final note = contributions[3] as SocketContribution;
      expect(note.socket, AppEntryRole.agentSections);
      expect(note.entryKey, preferencesRole.description);
      expect(note.entryValue, AgentNote(agentNote));
      expect(note.when, isEmpty);
      final brick = contributions[0] as BrickContribution;
      expect(brick.bundle, same(sharedPreferencesBundle));
      expect(brick.bundle.name, 'shared_preferences');
      expect(
        [for (final file in brick.bundle.files) file.path],
        [_implementation],
      );
      final dependency = contributions[1] as PubspecDependency;
      expect(dependency.package, 'shared_preferences');
      expect(dependency.constraint, '^2.5.5');
      expect(dependency.dev, isFalse);
      final data = contributions[2] as RoleData<Object>;
      expect(data.role, preferencesRole);
      final implementation = data.value as RoleImplementation;
      expect(implementation.isAsync, isTrue);
      expect(implementation.type.name, 'SharedAppPreferences');
      expect(implementation.init!.name, 'openSharedAppPreferences');
      expect(implementation.init!.deps, isEmpty);
      expect(
        implementation.type.import,
        const ImportRef.app('core/preferences/shared_app_preferences.dart'),
      );
      expect(implementation.init!.import, implementation.type.import);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the apps of the preferences with a DI container and without',
        () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core',
        'shared_preferences with di',
        'shared_preferences',
        'get_it',
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

    test(
        'renders code of the preferences that type-checks with '
        'shared_preferences', () async {
      final withPreferences = [
        for (final result in results)
          if (result.app!.files.containsKey(_implementation)) result,
      ];
      expect(withPreferences, hasLength(2));
      for (final result in withPreferences) {
        final app = DartApp.write(result.app!);
        try {
          expect(
            await app.analysisProblems(_preferences),
            isEmpty,
            reason: '${result.contractCase}',
          );
        } finally {
          app.delete();
        }
      }
    });
  });

  group('an app without a DI container', () {
    late ContractResult result;
    late RenderedApp withPreferences;
    late ContractResult resultWithout;

    setUpAll(() async {
      result = await _resultOf(const [SharedPreferencesModule.id]);
      withPreferences = result.app!;
      resultWithout = await _resultOf(const [FlutterCoreModule.id]);
    });

    test(
        'is the app without the preferences but for the role, its '
        'implementation, shared_preferences and the start-up', () {
      // Its native files are those of the app without it: the module sets
      // up nothing of the platforms.
      _expectTheAppWithout(
        withPreferences,
        resultWithout.app!,
        changedBy: _providersOf(result, appEntryRole),
      );
      expect(
        _yamlOf(withPreferences.files['pubspec.yaml']!.text)['dependencies'],
        {
          'flutter': {'sdk': 'flutter'},
          'shared_preferences': '^2.5.5',
        },
      );
    });

    test(
        'opens the preferences in the platform phase of the start-up, which '
        'awaits them', () {
      const open = 'role:preferences: await initPreferences();';
      expect(_startUpOf(resultWithout), isEmpty);
      expect(_startUpOf(result), [open]);
      expect(_contributionsTo(result, AppEntryRole.bootstrapPlatform), [open]);
    });

    test(
        'opens the implementation of the module in initPreferences(), and '
        'gets no restorer from it', () {
      final file = withPreferences.files[PreferencesRole.file]!;
      final init = _unitOf(withPreferences, PreferencesRole.file)
          .declarations
          .whereType<FunctionDeclaration>()
          .singleWhere((function) => function.name.lexeme == 'initPreferences');
      final body = init.functionExpression.body as BlockFunctionBody;

      expect(
        '${body.block.statements.first}',
        '_appPreferences = await impl0.openSharedAppPreferences();',
      );
      expect(
        [
          for (final added in file.addedImports)
            (added.import.uri, added.import.prefix, '${added.contributor}'),
        ],
        [
          (
            'package:contract_app/core/preferences/shared_app_preferences.dart',
            'impl0',
            'role:preferences',
          ),
        ],
      );
      expect(_contributionsTo(result, PreferencesRole.restorers), isEmpty);
    });

    group('the implementation', () {
      late CompilationUnit unit;
      late Map<String, MethodDeclaration> methods;

      setUpAll(() {
        unit = _unitOf(withPreferences, _implementation);
        methods = _methodsOf(unit, 'SharedAppPreferences');
      });

      test(
          'is the preferences on a SharedPreferencesWithCache that read '
          'every value that is saved', () {
        final declaration =
            unit.declarations.whereType<ClassDeclaration>().single;
        expect(
          '${declaration.implementsClause!.interfaces.single}',
          'AppPreferences',
        );
        final factory =
            unit.declarations.whereType<FunctionDeclaration>().single;
        expect(factory.name.lexeme, 'openSharedAppPreferences');
        expect('${factory.returnType}', 'Future<AppPreferences>');
        expect(factory.functionExpression.parameters!.parameters, isEmpty);
        final body = factory.functionExpression.body as ExpressionFunctionBody;
        // No allow list: the module does not know the keys of the others.
        const create = 'SharedPreferencesWithCache.create';
        const options = 'const SharedPreferencesWithCacheOptions()';
        expect(
          '${body.expression}',
          'SharedAppPreferences(await $create(cacheOptions: $options))',
        );
        expect(
          [
            for (final directive
                in unit.directives.whereType<ImportDirective>())
              '$directive',
          ],
          [
            "import 'package:shared_preferences/shared_preferences.dart';",
            "import 'app_preferences.dart';",
          ],
        );
      });

      test(
          'implements every method of the preferences with the parameters '
          'of the interface', () {
        final interface = _methodsOf(
          _unitOf(withPreferences, PreferencesRole.file),
          'AppPreferences',
        );

        expect(
          {
            for (final MapEntry(key: name, value: method) in methods.entries)
              if (!name.startsWith('_'))
                name: '${method.returnType} ${method.parameters}',
          },
          {
            for (final MapEntry(key: name, value: method) in interface.entries)
              name: '${method.returnType} ${method.parameters}',
          },
        );
      });
    });

    test(
        'reads what is saved when the app starts, lists in the form that '
        'each platform returns them in, saves each value under its key and '
        'with its type, returns null for a value of another type, a number '
        'of the other type of numbers too, keeps lists of its own, and reads '
        'at the next start what was saved', () async {
      final app = DartApp.write(withPreferences);
      final Map<Object?, Object?> sent;
      try {
        sent = (await app.run(_script))! as Map<Object?, Object?>;
      } finally {
        app.delete();
      }

      expect(sent, {
        'implementation': 'SharedAppPreferences',
        'saved by an earlier launch': 'dark',
        // A list with an item that is no text is no list of texts, and its
        // read does not throw, as that of the list of Android would.
        'lists as the platforms return them': {
          'ios.list': 'List<String> [a, b]',
          'android.list': 'List<String> [a, b]',
          'ios.mixed': 'Null null',
          'android.mixed': 'Null null',
        },
        'read back': [
          'String text',
          'bool true',
          'int 3',
          'double 1.5',
          'double 2.0',
          'List<String> [a, b]',
        ],
        'on the platform': {
          'a.text': 'String text',
          'a.flag': 'bool true',
          'a.count': 'int 3',
          'a.ratio': 'double 1.5',
          'a.whole': 'double 2.0',
          'a.list': 'List<String> [a, b]',
        },
        // Neither an int as a double, nor a double as an int, a whole
        // number too.
        'a number as the other type of numbers': [null, null],
        // The reads of shared_preferences throw on these.
        'as another type': [null, null, null, null, null, null],
        // Neither a change of the list that was saved nor one of the list
        // that was read changes what the preferences have, and the package
        // did not get the list of the caller.
        'a list of their own': [
          ['a', 'b'],
          true,
          ['a', 'b', 'd'],
        ],
        'removed': [null, false],
        'the next start': [
          true,
          2,
          'String text',
          'List<String> [a, b]',
          'double 2.0',
          null,
          null,
        ],
      });
      // What the note of the module tells coding agents of the numbers.
      expect(
        agentNote,
        contains(
          '`getDouble()` returns `null` for a key with an `int`, and '
          '`getInt()` for a key with a `double`.',
        ),
      );
    });

    group('the note of the module for coding agents', () {
      test(
          'is in the section of the preferences of the guide, after what '
          'the role says', () {
        final ofRole = [
          for (final (origin, _, note) in _agentNotesOf(withPreferences))
            if (origin == const RoleTemplateOrigin(preferencesRole)) note.text,
        ].single;

        expect(agentNote, startsWith('With `shared_preferences`:\n'));
        expect(
          withPreferences.files[AppEntryRole.agentsFile]!.text,
          contains(
            '\n## ${preferencesRole.description}\n'
            '\n'
            '$ofRole\n'
            '\n'
            '${agentNote.trim()}\n',
          ),
        );
      });

      test(
          'names the file of the module, the only one of the app that '
          'imports the package, and what the roles of the app declare', () {
        final code = _codeOf(agentNote);

        expect(
          code,
          containsAll([
            _implementation,
            'AppPreferences',
            'getDouble()',
            'getInt()',
            // The function that the app entry role requires of its provider.
            '${AppEntryRole.bootstrap.name}()',
          ]),
        );
        expect(
          [
            for (final file in withPreferences.files.values)
              if (file.path.endsWith('.dart') &&
                  file.text.contains('package:shared_preferences/'))
                file.path,
          ],
          [_implementation],
        );
        expect(
          _methodsOf(
            _unitOf(withPreferences, PreferencesRole.file),
            'AppPreferences',
          ).keys,
          containsAll(['getDouble', 'getInt']),
        );
      });

      test(
          'tells a test of the app to set the platform side that the app '
          'test of the module sets', () {
        const platform = 'SharedPreferencesAsyncPlatform.instance = '
            'InMemorySharedPreferencesAsync.empty()';
        const package = 'shared_preferences_platform_interface';
        final mocks = parseString(
          content: File(
            'app_tests/shared_preferences/test/shared_preferences_mocks.dart',
          ).readAsStringSync(),
        ).unit;

        expect(_codeOf(agentNote), containsAll([platform, package]));
        final function =
            mocks.declarations.whereType<FunctionDeclaration>().single;
        final body = function.functionExpression.body as BlockFunctionBody;
        expect(
          [for (final statement in body.block.statements) '$statement'],
          ['$platform;'],
        );
        expect(
          [
            for (final directive
                in mocks.directives.whereType<ImportDirective>())
              directive.uri.stringValue,
          ],
          everyElement(startsWith('package:$package/')),
        );
      });
    });
  });

  group('an app with a DI container', () {
    late ContractResult result;
    late RenderedApp withPreferences;
    late RenderedApp without;

    setUpAll(() async {
      result = await _resultOf(
        const [SharedPreferencesModule.id, GetItModule.id],
      );
      withPreferences = result.app!;
      without = (await _resultOf(const [GetItModule.id])).app!;
    });

    test(
        'is the app of the container without the preferences but for the '
        'role, its implementation, shared_preferences, the start-up and the '
        'registration', () {
      _expectTheAppWithout(
        withPreferences,
        without,
        changedBy: {
          ..._providersOf(result, appEntryRole),
          ..._providersOf(result, diRole),
        },
      );
      // The preferences are open before the container is filled.
      expect(_startUpOf(result), [
        'role:preferences: await initPreferences();',
        'role:di: await registerDependencies();',
      ]);
    });

    test('registers the preferences in the container, which creates them', () {
      // The contract harness, which found no errors in the app, checks that
      // the provider of the role creates them with their factory.
      final registrations = [
        for (final data in _registrationsOf(result))
          if (data.origin == const RoleTemplateOrigin(preferencesRole))
            data.value,
      ];
      expect(registrations, hasLength(1));
      final registration = registrations.single;
      expect(registration.type.name, 'AppPreferences');
      expect(registration.create.name, 'createAppPreferences');
      expect(registration.create.deps, isEmpty);
      expect(registration.lifetime, DiLifetime.lazySingleton);
    });
  });
}
