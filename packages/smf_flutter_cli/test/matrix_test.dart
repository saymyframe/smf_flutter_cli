import 'package:file/memory.dart';
import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:test/test.dart';

/// A module whose contributions cannot be collected.
final class _Broken extends SmfModule {
  const _Broken();

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: ModuleId('broken'),
        description: 'Broken',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      throw StateError('broken');
}

/// A provider of the analytics role whose contributions cannot be
/// collected, so the matrix has no app with it.
final class _BrokenAnalytics extends SmfModule {
  const _BrokenAnalytics();

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: ModuleId('broken_analytics'),
        description: 'Broken analytics',
        kind: ModuleKinds.infrastructure,
        providers: [RoleProvider.plain(analyticsRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      throw StateError('broken');
}

void main() {
  test(
      'the matrix of the CLI has the app of flutter_core with and without the '
      'router, the app of the router with the layout, one for each state '
      'manager, the app of home, which gets the router, the app of the DI '
      'container, the app of the events with the DI container and without, '
      'the app of Firebase, the app of Crashlytics with the DI container and '
      'without, which gets Firebase, the apps of Firebase Analytics with and '
      'without the DI container and the router, which get Firebase, and one '
      'of every module for each state manager', () async {
    final (:apps, :failed) = await matrixOf(smfModules);
    String everyModule(String stateManager) => 'every module ($stateManager) '
        '(flutter_core, go_router, $stateManager, home, bottom_tabs, get_it, '
        'event_bus, firebase_core, firebase_crashlytics, firebase_analytics)';

    expect(failed, isEmpty);
    expect(apps.map((app) => '$app'), [
      'flutter_core with router (flutter_core, go_router)',
      'flutter_core (flutter_core)',
      'go_router with layout (go_router, bottom_tabs, flutter_core)',
      'bloc (bloc, flutter_core)',
      'riverpod (riverpod, flutter_core)',
      'home (home, flutter_core, go_router)',
      'get_it (get_it, flutter_core)',
      'event_bus with di (event_bus, get_it, flutter_core)',
      'event_bus (event_bus, flutter_core)',
      'firebase_core (firebase_core, flutter_core)',
      equals(
        'firebase_crashlytics with di (firebase_crashlytics, get_it, '
        'firebase_core, flutter_core)',
      ),
      equals(
        'firebase_crashlytics (firebase_crashlytics, firebase_core, '
        'flutter_core)',
      ),
      equals(
        'firebase_analytics with di, router (firebase_analytics, get_it, '
        'go_router, firebase_core, flutter_core)',
      ),
      equals(
        'firebase_analytics with di (firebase_analytics, get_it, '
        'firebase_core, flutter_core)',
      ),
      equals(
        'firebase_analytics with router (firebase_analytics, go_router, '
        'firebase_core, flutter_core)',
      ),
      equals(
        'firebase_analytics (firebase_analytics, firebase_core, flutter_core)',
      ),
      everyModule('bloc'),
      everyModule('riverpod'),
    ]);
  });

  test('the options of roles reach every app', () async {
    final (:apps, :failed) = await matrixOf(
      smfModules,
      roleOptions: {'flavor': 'dev'},
    );

    expect(failed, isEmpty);
    expect(apps, isNotEmpty);
    for (final app in apps) {
      expect(app.roleOptions, {'flavor': 'dev'}, reason: '$app');
      expect(
        app.createArguments('app_1', '/apps'),
        contains('--flavor=dev'),
        reason: '$app',
      );
    }
  });

  test('an app of the matrix names every module and asks nothing', () {
    const app = MatrixApp(
      'home with router',
      [ModuleId('flutter_core'), ModuleId('router'), ModuleId('home')],
      roleOptions: {'start': '/home', 'unset': null},
    );

    expect(app.createArguments('app_1', '/apps'), [
      'create',
      'app_1',
      '-m',
      'flutter_core,router,home',
      '--start=/home',
      '-o',
      '/apps',
      '--on-conflict',
      'replace',
      '--no-input',
      '--skip-external-setup',
      '--no-dart-fix',
      '--strict',
    ]);
  });

  group('runMatrix', () {
    late List<String> log;
    late List<List<String>> created;
    late List<String> tested;

    setUp(() {
      log = [];
      created = [];
      tested = [];
    });

    Future<int> run({
      List<SmfModule> modules = const [FlutterCoreModule()],
      int createCode = 0,
      List<LeftOut> leftOut = const [],
      List<SkippedStep> skippedSteps = const [],
      int analyzeCode = 0,
      List<MatrixAppTest> appTests = const [],
      Set<Role> testedRoles = const {},
      int testCode = 0,
      Set<String>? only,
    }) =>
        runMatrix(
          modules,
          directory: '/apps',
          appTests: MatrixAppTests(appTests, testedRoles: testedRoles),
          only: only,
          log: log.add,
          commands: MatrixCommands(
            create: (arguments, onCreated) async {
              created.add(arguments);
              if (createCode == 0) {
                onCreated(
                  GeneratedApp(
                    name: arguments[1],
                    path: '/apps/${arguments[1]}',
                    leftOut: leftOut,
                    skippedSteps: skippedSteps,
                  ),
                );
              }
              return createCode;
            },
            analyze: (directory) async => (analyzeCode, 'Analyzed $directory'),
            test: (generated, app, tests) async {
              tested.add(
                '${generated.name} (${app.name}): '
                '${[for (final test in tests) test.directory].join(', ')}',
              );
              return (testCode, 'Tested ${generated.path}');
            },
          ),
        );

    test('generates and analyzes every app', () async {
      expect(await run(), 0);

      expect(created.single.take(2), ['create', 'app_1']);
      expect(log, [
        '\n=== app_1: flutter_core (flutter_core)',
        'Analyzed /apps/app_1',
        '\n1 apps generated in /apps.',
      ]);
    });

    test(
        'fails when an app is not generated, is left without a module or '
        'has issues', () async {
      expect(await run(createCode: 1), 1);
      expect(
        log.last,
        'app_1 (flutter_core (flutter_core)): smf create exited with 1.',
      );

      expect(
        await run(leftOut: const [LeftOut(ModuleId('x'), 'broken')]),
        1,
      );
      expect(log.last, contains('smf create left out x.'));

      expect(await run(analyzeCode: 3), 1);
      expect(log.last, contains('flutter analyze exited with 3.'));
    });

    test('fails when a step failed, not when CI leaves it for later', () async {
      const later = SkippedStep(
        'Log in',
        'firebase login',
        'the run skips external setup',
      );
      expect(await run(skippedSteps: const [later]), 0);

      expect(
        await run(
          skippedSteps: const [
            later,
            SkippedStep(
              'Configure',
              'flutterfire configure',
              'it exited with code 1',
              failed: true,
            ),
          ],
        ),
        1,
      );
      expect(
        log.last,
        'app_1 (flutter_core (flutter_core)): the step Configure: '
        'flutterfire configure (it exited with code 1).',
      );
    });

    test('runs the tests that apply to an app once it passed the analysis',
        () async {
      final core = MatrixAppTest(
        '/tests/core',
        appliesTo: (app) => app.modules.contains(FlutterCoreModule.id),
      );
      final other = MatrixAppTest(
        '/tests/other',
        appliesTo: (app) => app.modules.contains(const ModuleId('other')),
      );

      expect(await run(appTests: [core]), 0);
      expect(tested, ['app_1 (flutter_core): /tests/core']);
      expect(log, [
        '\n=== app_1: flutter_core (flutter_core)',
        'Analyzed /apps/app_1',
        'Tested /apps/app_1',
        '\n1 apps generated in /apps.',
      ]);

      // Only the tests that apply to the app go into it.
      expect(await run(appTests: [core, other]), 1);
      expect(tested, hasLength(2));
      expect(tested.last, 'app_1 (flutter_core): /tests/core');

      expect(await run(appTests: [core], analyzeCode: 1), 1);
      expect(tested, hasLength(2));

      expect(await run(appTests: [core], testCode: 2), 1);
      expect(tested, hasLength(3));
      expect(
        log.last,
        'app_1 (flutter_core (flutter_core)): its tests failed with the exit '
        'code 2.',
      );
    });

    test('checks only the apps it is given, which keep their numbers',
        () async {
      const modules = [FlutterCoreModule(), BlocModule()];
      final bloc = MatrixAppTest(
        '/tests/bloc',
        appliesTo: (app) => app.modules.contains(BlocModule.id),
      );

      expect(
        await run(modules: modules, appTests: [bloc], only: {'bloc'}),
        0,
      );
      expect(created.single.take(2), ['create', 'app_2']);
      expect(tested, ['app_2 (bloc): /tests/bloc']);
      expect(log.last, '\n1 apps generated in /apps.');

      // Tests of an app that is not checked do not run, and are no problem.
      expect(
        await run(modules: modules, appTests: [bloc], only: {'flutter_core'}),
        0,
      );
      expect(created.last.take(2), ['create', 'app_1']);
      expect(tested, hasLength(1));
    });

    test('fails when it is given an app that the matrix does not have',
        () async {
      expect(await run(only: {'flutter_core', 'bloc'}), 1);

      expect(created, hasLength(1));
      expect(log.sublist(log.indexOf('Problems:') + 1), [
        'No app of the matrix is bloc.',
      ]);
    });

    test('fails when tests apply to no app', () async {
      final other = MatrixAppTest(
        '/tests/other',
        appliesTo: (app) => app.modules.contains(const ModuleId('other')),
      );

      expect(await run(appTests: [other]), 1);
      expect(tested, isEmpty);
      expect(log.last, 'The tests of /tests/other apply to no app.');
    });

    group('with tests of a role', () {
      const modules = [FlutterCoreModule(), BlocModule(), RiverpodModule()];

      /// The problems that the run logged.
      List<String> problems() => log.contains('Problems:')
          ? log.sublist(log.indexOf('Problems:') + 1)
          : [];

      /// Tests of the state management role in the apps that [appliesTo]
      /// accepts.
      MatrixAppTest stateTest(bool Function(MatrixApp app) appliesTo) =>
          MatrixAppTest(
            '/tests/state',
            appliesTo: appliesTo,
            roles: {stateManagementRole},
          );

      test('passes when they apply to an app of every provider of the role',
          () async {
        final byRole = stateTest(
          (app) => app.modules.any(
            (id) => modules.any(
              (module) =>
                  module.descriptor.id == id &&
                  module.descriptor.provides.contains(stateManagementRole),
            ),
          ),
        );

        expect(
          await run(
            modules: modules,
            appTests: [byRole],
            testedRoles: {stateManagementRole},
          ),
          0,
        );
        expect(problems(), isEmpty);
        expect(tested, isNotEmpty);
      });

      test(
          'fails when they leave out a provider of the role, as they do when '
          'they select the apps of another provider by its module', () async {
        final byModule = stateTest(
          (app) => app.modules.contains(BlocModule.id),
        );

        expect(await run(modules: modules, appTests: [byModule]), 1);
        expect(problems(), [
          equals(
            'The tests of /tests/state check the state management role, but '
            'apply to no app with riverpod, which provides it: a test of a '
            'role applies to the apps of every provider of the role, which '
            'it selects by the role.',
          ),
        ]);
      });

      test(
          'fails when no test checks a role that the matrix tests, for each '
          'provider of the role', () async {
        // Tests of what only one provider does name no role.
        final ofBloc = MatrixAppTest(
          '/tests/bloc',
          appliesTo: (app) => app.modules.contains(BlocModule.id),
        );

        expect(
          await run(
            modules: modules,
            appTests: [ofBloc],
            testedRoles: {stateManagementRole},
          ),
          1,
        );
        expect(problems(), [
          for (final id in ['bloc', 'riverpod'])
            equals(
              'No test of the state management role applies to an app with '
              '$id, which provides it: nothing checks at runtime that $id '
              'keeps the contract of the role.',
            ),
        ]);

        // A role that no module provides has nothing to check.
        expect(
          await run(modules: modules, testedRoles: {routerRole}),
          0,
        );
      });

      test(
          'leaves out a provider that the matrix has no app of, whose cases '
          'failed', () async {
        expect(
          await run(
            modules: const [FlutterCoreModule(), _BrokenAnalytics()],
            testedRoles: {analyticsRole},
          ),
          1,
        );
        // Only the cases that failed are problems.
        expect(problems(), [
          startsWith('broken_analytics: error [broken_analytics]'),
          startsWith('every module: error [broken_analytics]'),
        ]);
      });
    });

    test('fails when the contract harness finds errors in a case', () async {
      expect(
        await run(modules: const [FlutterCoreModule(), _Broken()]),
        1,
      );

      final problems = log.sublist(log.indexOf('Problems:') + 1);
      expect(problems, [
        startsWith('broken: error [broken]: broken failed to contribute'),
        startsWith('every module: error [broken]'),
      ]);
    });
  });

  test(
      'the matrix runs flutter, but dart analyze in place of flutter analyze '
      'in a directory whose path has letters beyond ASCII', () {
    expect(matrixCommand(['analyze'], '/tmp/SMF apps/app_1'), [
      'flutter',
      'analyze',
    ]);
    expect(matrixCommand(['analyze'], '/tmp/SMF apps застосунки é/app_1'), [
      'dart',
      'analyze',
      '--fatal-infos',
    ]);
    expect(
      matrixCommand(['test'], '/tmp/SMF apps застосунки é/app_1'),
      ['flutter', 'test'],
    );
    expect(
      matrixCommand(['pub', 'add', 'dev:x'], r'C:\застосунки\app_1'),
      ['flutter', 'pub', 'add', 'dev:x'],
    );
  });

  test('the tests of an app go into it with their placeholders filled', () {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/tests/core/test/core_test.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(
        "import 'package:{{app_name}}/app.dart';\n// {{screen}}\n",
      );
    fileSystem.file('/tests/core/.hidden/notes.txt')
      ..createSync(recursive: true)
      ..writeAsStringSync('{{nothing}}');
    fileSystem.file('/tests/core/lib/options.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('const options = 1;\n');
    fileSystem.file('/tests/more/test/more_test.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// {{app_name}}\n');
    fileSystem.file('/apps/app_1/lib/options.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('const options = 0;\n');
    const app = MatrixApp('home', [ModuleId('home')]);

    final added = addAppTests(
      [
        MatrixAppTest(
          '/tests/core',
          appliesTo: (app) => true,
          values: (app) => {'screen': '${app.modules.single}.home'},
        ),
        MatrixAppTest('/tests/more', appliesTo: (app) => true),
      ],
      app: app,
      directory: '/apps/app_1',
      packageName: 'my_app',
      fileSystem: fileSystem,
    );

    expect(added, [
      'lib/options.dart',
      'test/core_test.dart',
      'test/more_test.dart',
    ]);
    String read(String path) =>
        fileSystem.file('/apps/app_1/$path').readAsStringSync();
    expect(
      read('test/core_test.dart'),
      "import 'package:my_app/app.dart';\n// home.home\n",
    );
    expect(read('lib/options.dart'), 'const options = 1;\n');
    expect(read('test/more_test.dart'), '// my_app\n');
    expect(fileSystem.directory('/apps/app_1/.hidden').existsSync(), isFalse);
  });

  test('the tests of an app go into it only when their files fit', () {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/tests/core/test/core_test.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// {{app_name}} {{screen}}\n');
    fileSystem.file('/tests/more/test/core_test.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// more\n');
    const app = MatrixApp('home', [ModuleId('home')]);
    List<String> add(List<MatrixAppTest> tests) => addAppTests(
          tests,
          app: app,
          directory: '/apps/app_1',
          packageName: 'my_app',
          fileSystem: fileSystem,
        );
    // A problem reads as its message, also where it is printed.
    Matcher throwsProblem(String message) => throwsA(
          isA<MatrixAppTestException>()
              .having((error) => error.message, 'message', message)
              .having((error) => '$error', 'text', message),
        );

    expect(
      () => add([MatrixAppTest('/tests/core', appliesTo: (app) => true)]),
      throwsProblem(
        'The tests of /tests/core keep {{screen}} in test/core_test.dart: no '
        'value fills it.',
      ),
    );
    expect(
      () => add([
        MatrixAppTest(
          '/tests/core',
          appliesTo: (app) => true,
          values: (app) => {'screen': 'home.home'},
        ),
        MatrixAppTest('/tests/more', appliesTo: (app) => true),
      ]),
      throwsProblem(
        'The tests of /tests/core and /tests/more both have '
        'test/core_test.dart.',
      ),
    );
    expect(fileSystem.directory('/apps/app_1').existsSync(), isFalse);
  });

  group('runAppTests', () {
    late MemoryFileSystem fileSystem;
    late List<String> commands;
    const app = MatrixApp('home', [ModuleId('home')]);
    const generated = GeneratedApp(name: 'my_app', path: '/apps/app_1');

    setUp(() {
      fileSystem = MemoryFileSystem();
      fileSystem.file('/tests/core/test/core_test.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('// {{app_name}}\n');
      commands = [];
    });

    Future<(int, String)> run(
      List<MatrixAppTest> tests, {
      Map<String, int> codes = const {},
    }) =>
        runAppTests(
          generated,
          app,
          tests,
          fileSystem: fileSystem,
          flutter: (arguments, directory) async {
            final command = arguments.join(' ');
            commands.add('$directory: $command');
            return (codes[command] ?? 0, '[$command]');
          },
        );

    test('adds the tests, their dev dependencies, and runs them', () async {
      final (code, output) = await run([
        MatrixAppTest(
          '/tests/core',
          appliesTo: (app) => true,
          devDependencies: const ['mocks', 'more_mocks'],
        ),
      ]);

      expect(code, 0);
      expect(commands, [
        '/apps/app_1: pub add dev:mocks dev:more_mocks',
        '/apps/app_1: analyze',
        '/apps/app_1: test',
      ]);
      expect(
        output,
        'Added the tests test/core_test.dart.\n'
        '[pub add dev:mocks dev:more_mocks][analyze][test]',
      );
      expect(
        fileSystem.file('/apps/app_1/test/core_test.dart').readAsStringSync(),
        '// my_app\n',
      );
    });

    test('stops at the first command that fails, and names it', () async {
      final tests = [MatrixAppTest('/tests/core', appliesTo: (app) => true)];

      final (code, output) = await run(tests, codes: {'analyze': 3});

      expect(code, 3);
      expect(commands, ['/apps/app_1: analyze']);
      expect(output, endsWith('[analyze]\nflutter analyze exited with 3.'));
    });

    test('fails with a problem of the files of the tests', () async {
      final (code, output) = await run([
        MatrixAppTest(
          '/tests/core',
          appliesTo: (app) => true,
          values: (app) => {'app_name': '{{name}}'},
        ),
      ]);

      expect(code, 1);
      expect(output, contains('keep {{name}} in test/core_test.dart'));
      expect(commands, isEmpty);
    });
  });

  group('addAppTestsTo', () {
    late MemoryFileSystem fileSystem;
    late List<String> commands;
    const generated = GeneratedApp(name: 'start_app', path: '/apps/start_app');

    setUp(() {
      fileSystem = MemoryFileSystem();
      fileSystem.file('/tests/start/integration_test/start_test.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync("import 'package:{{app_name}}/main.dart';\n");
      commands = [];
    });

    Future<(int, String)> add(
      List<MatrixAppTest> tests, {
      Map<String, int> codes = const {},
    }) =>
        addAppTestsTo(
          generated,
          tests,
          fileSystem: fileSystem,
          flutter: (arguments, directory) async {
            final command = arguments.join(' ');
            commands.add('$directory: $command');
            return (codes[command] ?? 0, '[$command]');
          },
        );

    test(
        'adds the tests to an app outside the matrix, with their dev '
        'dependencies, a package of the Flutter SDK among them, and runs '
        'nothing else', () async {
      final (code, output) = await add([
        MatrixAppTest(
          '/tests/start',
          appliesTo: (app) => true,
          devDependencies: const ['integration_test@{sdk: flutter}', 'mocks'],
        ),
      ]);

      expect(code, 0);
      const pubAdd = 'pub add dev:integration_test@{sdk: flutter} dev:mocks';
      expect(commands, ['/apps/start_app: $pubAdd']);
      expect(
        output,
        'Added the tests integration_test/start_test.dart.\n[$pubAdd]',
      );
      expect(
        fileSystem
            .file('/apps/start_app/integration_test/start_test.dart')
            .readAsStringSync(),
        "import 'package:start_app/main.dart';\n",
      );
    });

    test('runs no command for tests without dev dependencies', () async {
      final (code, output) = await add([
        MatrixAppTest('/tests/start', appliesTo: (app) => true),
      ]);

      expect(code, 0);
      expect(commands, isEmpty);
      expect(output, 'Added the tests integration_test/start_test.dart.\n');
    });

    test('fails when flutter pub add fails, and names it', () async {
      final (code, output) = await add(
        [
          MatrixAppTest(
            '/tests/start',
            appliesTo: (app) => true,
            devDependencies: const ['mocks'],
          ),
        ],
        codes: {'pub add dev:mocks': 69},
      );

      expect(code, 69);
      expect(output, endsWith('\nflutter pub add dev:mocks exited with 69.'));
    });

    test(
        'fails with a placeholder that only an app of the matrix fills, '
        'before it adds anything', () async {
      fileSystem
          .file('/tests/start/integration_test/start_test.dart')
          .writeAsStringSync('// {{app_name}} {{screen}}\n');

      final (code, output) = await add([
        MatrixAppTest(
          '/tests/start',
          appliesTo: (app) => true,
          values: (app) => {'screen': 'home.home'},
          devDependencies: const ['mocks'],
        ),
      ]);

      expect(code, 1);
      expect(
        output,
        'The tests of /tests/start keep {{screen}} in '
        'integration_test/start_test.dart: no value fills it.',
      );
      expect(commands, isEmpty);
      expect(fileSystem.directory('/apps/start_app').existsSync(), isFalse);
    });
  });
}
