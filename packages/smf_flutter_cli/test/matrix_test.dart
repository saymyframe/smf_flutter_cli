import 'package:file/memory.dart';
import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
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

/// An infrastructure module [id] with [steps] after generation, which
/// depends on the modules [dependsOn] and requires the roles [requires].
final class _WithSteps extends SmfModule {
  const _WithSteps(
    this.id, {
    this.steps = const [],
    this.dependsOn = const {},
    this.requires = const {},
  });

  final ModuleId id;
  final List<PostGenStep> steps;
  final Set<ModuleId> dependsOn;
  final Set<Role> requires;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'With steps',
        kind: ModuleKinds.infrastructure,
        dependsOn: dependsOn,
        requires: requires,
      );

  @override
  List<Contribution> contribute(ModuleContext context) => steps;
}

/// A step that needs nothing outside the app.
const _build = PostGenStep(ToolRef('tool'), ['build']);

/// A step that needs an external service.
const _configure = PostGenStep(
  ToolRef('tool'),
  ['configure'],
  external: true,
  skippable: true,
);

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
    // The apps with every module tell apart by the providers other than
    // the first of their roles, bloc of the state managers.
    expect(
      [for (final app in apps) app.everyModuleWith],
      [
        for (final _ in apps.skip(2)) isNull,
        isEmpty,
        [RiverpodModule.id],
      ],
    );
  });

  test(
      'an app with every module is named after the providers other than '
      'the first of their roles, so its name stays when another role gets '
      'a second provider', () async {
    Future<List<String>> packageNames(List<SmfModule> modules) async {
      final (:apps, :failed) = await everyModuleAppsOf(modules);
      expect(failed, isEmpty);
      return [for (final app in apps) '${app.name}: ${app.packageName('app')}'];
    }

    expect(
      await packageNames(const [FlutterCoreModule(), BlocModule()]),
      ['every module: app'],
    );
    expect(
      await packageNames(
        const [FlutterCoreModule(), BlocModule(), RiverpodModule()],
      ),
      ['every module (bloc): app', 'every module (riverpod): app_riverpod'],
    );
    // Any other app of the matrix is named as it is given.
    expect(const MatrixApp('bloc', []).packageName('app'), 'app');
  });

  test('the apps with every module have every module', () async {
    final (:apps, :failed) = await everyModuleAppsOf(smfModules);

    expect(failed, isEmpty);
    expect(apps.map((app) => app.modules.length), [
      smfModules.length - 1,
      smfModules.length - 1,
    ]);
    expect(apps.map((app) => app.modules), [
      isNot(contains(RiverpodModule.id)),
      isNot(contains(BlocModule.id)),
    ]);
  });

  test(
      'the apps with every module without external steps leave out the '
      'modules whose steps or their follow-ups need an external service, '
      'those that depend on them, and those that are then left without a '
      'provider of a role they require', () async {
    const local = _WithSteps(ModuleId('local'), steps: [_build]);
    const external = _WithSteps(ModuleId('external'), steps: [_configure]);
    const followUp = _WithSteps(
      ModuleId('follow_up'),
      steps: [
        PostGenStep(ToolRef('tool'), ['check'], followUps: [_configure]),
      ],
    );
    const dependent = _WithSteps(
      ModuleId('dependent'),
      dependsOn: {ModuleId('external')},
    );
    // Crash reports come only from Firebase Crashlytics, which depends on
    // Firebase Core, whose step configures an app in a Firebase project.
    const reporter = _WithSteps(
      ModuleId('reporter'),
      requires: {crashReportingRole},
    );
    final modules = [
      ...smfModules,
      local,
      external,
      followUp,
      dependent,
      reporter,
    ];

    final (:apps, :failed) = await everyModuleAppsOf(
      modules,
      withoutExternalSteps: true,
    );

    expect(failed, isEmpty);
    String without(String stateManager) => 'every module ($stateManager) '
        '(flutter_core, go_router, $stateManager, home, bottom_tabs, get_it, '
        'event_bus, local)';
    expect(apps.map((app) => '$app'), [
      without('bloc'),
      without('riverpod'),
    ]);
    expect(apps.map((app) => app.everyModuleWith), [
      isEmpty,
      [RiverpodModule.id],
    ]);

    // Without the option, the apps have them all.
    final every = await everyModuleAppsOf(modules);
    expect(every.failed, isEmpty);
    for (final app in every.apps) {
      expect(
        app.modules,
        containsAll(const [
          ModuleId('local'),
          ModuleId('external'),
          ModuleId('follow_up'),
          ModuleId('dependent'),
          ModuleId('reporter'),
        ]),
      );
    }
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

  test(
      'an app of the matrix has the data and the roles of its case, and the '
      'choices of the roles, such as the route it starts on', () async {
    final (:apps, :failed) = await matrixOf(smfModules);
    MatrixApp named(String name) => apps.singleWhere((app) => app.name == name);

    expect(failed, isEmpty);
    // Of the modules of the CLI, only home has a route that can start the
    // app; an app with a router but without it starts on the fallback
    // screen of its app entry, and an app without a router has no route.
    for (final app in apps) {
      final input = routerRole.hookInput(app.hook!);
      expect(
        routerRole.startIn(input)?.fullName,
        app.modules.contains(HomeModule.id) ? 'home.home' : isNull,
        reason: '$app',
      );
      expect(input.context, ContractHarness.defaultContext, reason: '$app');
    }
    expect(
      named('flutter_core with router').hook!.presentRoles,
      contains(routerRole),
    );
    expect(
      named('flutter_core').hook!.presentRoles,
      isNot(contains(routerRole)),
    );
    expect(const MatrixApp('home', [HomeModule.id]).hook, isNull);
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
      int testCode = 0,
      Set<String>? only,
      bool everyModule = false,
    }) =>
        runMatrix(
          modules,
          directory: '/apps',
          appTests: appTests,
          only: only,
          everyModule: everyModule,
          commands: MatrixCommands(
            log: log.add,
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

    test(
        'checks only the apps with every module when it is asked to, also '
        'those that other cases built already', () async {
      const modules = [FlutterCoreModule(), BlocModule(), RiverpodModule()];

      expect(await run(modules: modules, everyModule: true), 0);

      // The app of bloc is the app with every module and bloc, and that of
      // riverpod the one with riverpod.
      expect(
        created.map((arguments) => arguments.take(4).join(' ')),
        [
          'create app_2 -m bloc,flutter_core',
          'create app_3 -m riverpod,flutter_core',
        ],
      );
      expect(log.last, '\n2 apps generated in /apps.');
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

  group('createEveryModuleApps', () {
    late List<String> log;
    late List<List<String>> created;

    setUp(() {
      log = [];
      created = [];
    });

    Future<int> create({
      List<SmfModule> modules = smfModules,
      bool withoutExternalSteps = false,
      List<String> options = const [],
      int code = 0,
      bool generates = true,
      List<LeftOut> leftOut = const [],
      List<SkippedStep> skippedSteps = const [],
    }) =>
        createEveryModuleApps(
          modules,
          directory: '/apps',
          name: 'start_app',
          withoutExternalSteps: withoutExternalSteps,
          options: options,
          commands: MatrixCommands(
            log: log.add,
            create: (arguments, onCreated) async {
              created.add(arguments);
              if (generates) {
                onCreated(
                  GeneratedApp(
                    name: arguments[1],
                    path: '/apps/${arguments[1]}',
                    leftOut: leftOut,
                    skippedSteps: skippedSteps,
                  ),
                );
              }
              return code;
            },
          ),
        );

    test(
        'generates each app with every module under a name of its own, '
        'with the options of CI and the options given', () async {
      expect(
        await create(
          withoutExternalSteps: true,
          options: const ['--org', 'com.example.ci'],
        ),
        0,
      );

      List<String> arguments(String name, String stateManager) => [
            'create',
            name,
            '-m',
            [
              'flutter_core',
              'go_router',
              stateManager,
              'home',
              'bottom_tabs',
              'get_it',
              'event_bus',
            ].join(','),
            '-o',
            '/apps',
            '--on-conflict',
            'replace',
            '--no-input',
            '--skip-external-setup',
            '--no-dart-fix',
            '--strict',
            '--org',
            'com.example.ci',
          ];
      expect(created, [
        arguments('start_app', 'bloc'),
        arguments('start_app_riverpod', 'riverpod'),
      ]);
      expect(log, [
        startsWith('\n=== start_app: every module (bloc) (flutter_core, '),
        startsWith('\n=== start_app_riverpod: every module (riverpod) '),
      ]);

      // With every module, Firebase among them.
      expect(await create(), 0);
      expect(created.last, contains(startsWith('flutter_core,')));
      expect(
        created.last[created.last.indexOf('-m') + 1].split(','),
        contains('firebase_core'),
      );
    });

    test(
        'fails when an app is not generated, is left without a module or '
        'a step failed', () async {
      expect(await create(code: 1), 1);
      expect(log.sublist(log.indexOf('Problems:') + 1), [
        startsWith('start_app (every module (bloc) '),
        allOf(
          startsWith('start_app_riverpod (every module (riverpod) '),
          endsWith('smf create exited with 1.'),
        ),
      ]);

      expect(await create(generates: false), 1);
      expect(log.last, endsWith('smf create exited with 0.'));

      expect(
        await create(leftOut: const [LeftOut(ModuleId('x'), 'broken')]),
        1,
      );
      expect(log.last, endsWith('smf create left out x.'));

      expect(
        await create(
          skippedSteps: const [
            SkippedStep(
              'Configure',
              'tool configure',
              'it exited with 1',
              failed: true,
            ),
          ],
        ),
        1,
      );
      expect(
        log.last,
        endsWith('the step Configure: tool configure (it exited with 1).'),
      );
    });

    test('with --explain, only checks that smf create succeeds', () async {
      expect(
        await create(options: const ['--explain'], generates: false),
        0,
      );
      expect(created, everyElement(contains('--explain')));
      expect(log, isNot(contains('Problems:')));

      expect(
        await create(options: const ['--explain'], generates: false, code: 64),
        1,
      );
      expect(log.last, endsWith('smf create exited with 64.'));
    });

    test('fails when the contract harness finds errors in an app', () async {
      expect(
        await create(modules: const [FlutterCoreModule(), _Broken()]),
        1,
      );

      expect(created, isEmpty);
      expect(log, [
        'Problems:',
        startsWith('every module: error [broken]: broken failed to contribute'),
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
