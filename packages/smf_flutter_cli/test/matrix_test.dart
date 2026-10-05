import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:mirrors';

import 'package:file/memory.dart';
import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
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

/// The package that declares the class of each of [modules], as the
/// matrix tools give them to [appTestsReport].
Map<ModuleId, String> _packagesOf(List<SmfModule> modules) => {
      for (final module in modules)
        module.descriptor.id:
            (reflectClass(module.runtimeType).owner! as LibraryMirror)
                .uri
                .pathSegments
                .first,
    };

/// The directory `app_tests` of the package [package], next to its `lib/`.
Future<String> _appTestsOf(String package) async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:$package/'),
  );
  return '${Directory.fromUri(library!).parent.path}/app_tests';
}

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

/// A role that an app can have several providers of, whose file declares
/// only types, so that none of its functions reaches every provider; with
/// [generates] false, a role whose template leaves out its file.
final class _TypesRole extends Role<String> {
  const _TypesRole(this.id, {required this.generates});

  /// The file of the role in the app.
  static const file = 'lib/core/types/types.dart';

  @override
  final String id;

  /// Whether the template of the role generates [file].
  final bool generates;

  @override
  String get description => 'Types';

  @override
  RoleCardinality get cardinality => RoleCardinality.many;

  @override
  RoleInterface get interface => const RoleInterface(files: [file]);

  @override
  RoleTemplate<String> get template => _TypesTemplate(generates: generates);
}

const _typesRole = _TypesRole('types', generates: true);

const _typesRoleWithoutFile = _TypesRole('types_without', generates: false);

/// The template of a [_TypesRole], which generates its file if [generates].
final class _TypesTemplate extends RoleTemplate<String> {
  const _TypesTemplate({required this.generates});

  final bool generates;

  @override
  List<Contribution> contribute(ModuleContext context) => [
        if (generates)
          BrickContribution(
            MasonBundle(
              name: 'types_role',
              description: 'The types of the role',
              version: '0.1.0',
              files: [
                MasonBundledFile(
                  _TypesRole.file,
                  base64.encode(
                    utf8.encode(
                      '/// A type of the role.\n'
                      'abstract interface class Types {}\n',
                    ),
                  ),
                  'text',
                ),
              ],
            ),
          ),
      ];
}

/// A provider of [_typesRole], or of [_typesRoleWithoutFile] without
/// [file].
final class _TypesProvider extends SmfModule {
  const _TypesProvider({this.file = true});

  /// Whether the template of the role generates its file.
  final bool file;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: const ModuleId('types_provider'),
        description: 'Types',
        kind: ModuleKinds.infrastructure,
        providers: [
          RoleProvider.plain(file ? _typesRole : _typesRoleWithoutFile),
        ],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => const [];
}

/// An infrastructure module [id] with [steps] after generation, which
/// depends on the modules [dependsOn], requires the roles [requires] and
/// provides the roles [provides].
final class _WithSteps extends SmfModule {
  const _WithSteps(
    this.id, {
    this.steps = const [],
    this.dependsOn = const {},
    this.requires = const {},
    this.provides = const {},
  });

  final ModuleId id;
  final List<PostGenStep> steps;
  final Set<ModuleId> dependsOn;
  final Set<Role> requires;
  final Set<Role> provides;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'With steps',
        kind: ModuleKinds.infrastructure,
        dependsOn: dependsOn,
        requires: requires,
        providers: [for (final role in provides) RoleProvider.plain(role)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => steps;
}

/// A role that an app can have any number of providers of, as the crash
/// reporting role, whose providers give it nothing.
final class _ManyRole extends Role<Object> {
  const _ManyRole();

  @override
  String get id => 'many';

  @override
  String get description => 'Many';

  @override
  RoleCardinality get cardinality => RoleCardinality.many;
}

const _many = _ManyRole();

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
      'manager, the app of home and the app of settings, which get the '
      'router, the apps of the localization with the settings screen and '
      'without, which get the preferences, the app of the DI container, '
      'the apps of the events and of the preferences with the DI container '
      'and without, the app of Firebase, the app of Crashlytics '
      'with the DI container and without, which gets Firebase, the apps of '
      'Firebase Analytics with and without the DI container and the router, '
      'which get Firebase, and one of every module for each state manager',
      () async {
    final (:apps, :failed) = await matrixOf(smfModules);
    const localizedWithSettings = 'gen_l10n with settings_screen '
        '(gen_l10n, settings, flutter_core, shared_preferences, go_router)';
    String everyModule(String stateManager) => 'every module ($stateManager) '
        '(flutter_core, go_router, $stateManager, home, settings, '
        'bottom_tabs, gen_l10n, get_it, event_bus, shared_preferences, '
        'firebase_core, firebase_crashlytics, firebase_analytics)';

    expect(failed, isEmpty);
    expect(apps.map((app) => '$app'), [
      'flutter_core with router (flutter_core, go_router)',
      'flutter_core (flutter_core)',
      'go_router with layout (go_router, bottom_tabs, flutter_core)',
      'bloc (bloc, flutter_core)',
      'riverpod (riverpod, flutter_core)',
      'home (home, flutter_core, go_router)',
      'settings (settings, flutter_core, go_router)',
      localizedWithSettings,
      'gen_l10n (gen_l10n, flutter_core, shared_preferences)',
      'get_it (get_it, flutter_core)',
      'event_bus with di (event_bus, get_it, flutter_core)',
      'event_bus (event_bus, flutter_core)',
      'shared_preferences with di (shared_preferences, get_it, flutter_core)',
      'shared_preferences (shared_preferences, flutter_core)',
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

  test(
      'an app with every module is named after the providers of the roles '
      'that take one, not after those of a role that takes many, which every '
      'app has, also when the apps without external steps leave its first '
      'provider out', () async {
    // The first provider of the role that takes many has a step that needs
    // an external service, as Firebase Crashlytics among the crash
    // reporters, so the apps without external steps have only the second.
    const external = _WithSteps(
      ModuleId('many_external'),
      steps: [_configure],
      provides: {_many},
    );
    const local = _WithSteps(ModuleId('many_local'), provides: {_many});
    final modules = [...smfModules, external, local];

    for (final withoutExternalSteps in [false, true]) {
      final (:apps, :failed) = await everyModuleAppsOf(
        modules,
        withoutExternalSteps: withoutExternalSteps,
      );

      expect(failed, isEmpty);
      expect(
        [for (final app in apps) app.modules],
        everyElement(contains(local.id)),
      );
      expect(
        [for (final app in apps) app.packageName('start_app')],
        ['start_app', 'start_app_riverpod'],
        reason: 'withoutExternalSteps: $withoutExternalSteps',
      );
    }
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
      'modules whose steps need an external service, those among them that '
      'continue a step of another module included, those that depend on '
      'them, and those that are then left without a provider of a role they '
      'require', () async {
    const build = PostGenStepId(ModuleId('local'), 'build');
    const local = _WithSteps(
      ModuleId('local'),
      steps: [
        PostGenStep(ToolRef('tool'), ['build'], id: build),
      ],
    );
    const external = _WithSteps(ModuleId('external'), steps: [_configure]);
    // It continues the step of local, which needs nothing outside the app,
    // with a step that does, so the app keeps local without it.
    const followUp = _WithSteps(
      ModuleId('follow_up'),
      dependsOn: {ModuleId('local')},
      steps: [
        PostGenStep(
          ToolRef('tool'),
          ['configure'],
          followUpOf: build,
          external: true,
          skippable: true,
        ),
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
        '(flutter_core, go_router, $stateManager, home, settings, '
        'bottom_tabs, gen_l10n, get_it, event_bus, shared_preferences, '
        'local)';
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

  test(
      'the report of the app tests names the modules of the package that '
      'keeps each, the apps it applies to without them, and the roles whose '
      'contract it checks', () async {
    final home = await _appTestsOf('smf_home_flutter');
    final cli = await _appTestsOf('smf_flutter_cli');
    const packages = {
      FlutterCoreModule.id: 'smf_flutter_core',
      HomeModule.id: 'smf_home_flutter',
    };
    const withHome = MatrixApp(
      'with home',
      [FlutterCoreModule.id, HomeModule.id],
      roleOptions: {'start': '/home'},
    );
    const withoutHome = MatrixApp('without home', [FlutterCoreModule.id]);
    // An app with every module, with home in place of the first provider of
    // a role.
    const everyModule = MatrixApp(
      'every module',
      [FlutterCoreModule.id, HomeModule.id],
      everyModuleWith: [HomeModule.id],
    );
    var built = 0;
    Future<List<MatrixApp>> apps() async {
      built++;
      return const [withHome, withoutHome, everyModule];
    }

    final report = await appTestsReport(
      [
        // Tests of home that apply to every app, to the apps with home, to
        // the apps with the option of home, and to the apps with every
        // module, which the apps keep without it, and to the app with every
        // module and home, which it does not.
        MatrixAppTest('$home/everywhere', appliesTo: (_) => true),
        MatrixAppTest(
          '$home/with_home',
          appliesTo: (app) => app.modules.contains(HomeModule.id),
        ),
        MatrixAppTest(
          '$home/start',
          appliesTo: (app) => app.roleOptions['start'] == '/home',
        ),
        MatrixAppTest(
          '$home/every_module',
          appliesTo: (app) => app.everyModuleWith != null,
        ),
        MatrixAppTest(
          '$home/every_module_with_home',
          appliesTo: (app) =>
              app.everyModuleWith?.contains(HomeModule.id) ?? false,
        ),
        // A test of a package of no module of the matrix.
        MatrixAppTest('$cli/start', appliesTo: (_) => true),
        // A test of the contract of roles, which the report names by their
        // ids.
        MatrixAppTest(
          '$cli/of_roles',
          appliesTo: (app) =>
              app.hook?.presentRoles.contains(routerRole) ?? false,
          roles: {routerRole, layoutRole},
        ),
      ],
      modules: const [FlutterCoreModule(), HomeModule()],
      packages: packages,
      apps: apps,
    );

    expect(report, [
      {
        'directory': '$home/everywhere',
        'modules': ['home'],
        'appliesWithout': ['with home', 'without home', 'every module'],
        'uses': <Object>[],
        'roles': <String>[],
        'roleFunctionUses': <Object>[],
      },
      {
        'directory': '$home/with_home',
        'modules': ['home'],
        'appliesWithout': <String>[],
        'uses': [
          {
            'module': 'home',
            'package': 'smf_home_flutter',
            'apps': ['with home', 'every module'],
          },
        ],
        'roles': <String>[],
        'roleFunctionUses': <Object>[],
      },
      {
        'directory': '$home/start',
        'modules': ['home'],
        'appliesWithout': ['with home'],
        'uses': <Object>[],
        'roles': <String>[],
        'roleFunctionUses': <Object>[],
      },
      {
        'directory': '$home/every_module',
        'modules': ['home'],
        'appliesWithout': ['every module'],
        'uses': <Object>[],
        'roles': <String>[],
        'roleFunctionUses': <Object>[],
      },
      {
        'directory': '$home/every_module_with_home',
        'modules': ['home'],
        'appliesWithout': <String>[],
        'uses': [
          {
            'module': 'home',
            'package': 'smf_home_flutter',
            'apps': ['every module'],
          },
        ],
        'roles': <String>[],
        'roleFunctionUses': <Object>[],
      },
      {
        'directory': '$cli/start',
        'modules': <String>[],
        'appliesWithout': <String>[],
        'uses': <Object>[],
        'roles': <String>[],
        'roleFunctionUses': <Object>[],
      },
      {
        'directory': '$cli/of_roles',
        'modules': <String>[],
        'appliesWithout': <String>[],
        'uses': <Object>[],
        'roles': ['router', 'layout'],
        'roleFunctionUses': <Object>[],
      },
    ]);
    // It builds the apps once for all the tests, and not without tests.
    expect(built, 1);
    expect(
      await appTestsReport(
        const [],
        modules: const [FlutterCoreModule(), HomeModule()],
        packages: packages,
        apps: apps,
      ),
      isEmpty,
    );
    expect(built, 1);
  });

  group(
      'the report of the app tests names the uses, in the Dart files of each '
      'test, of the functions of the roles that an app can have several '
      'providers of', () {
    const path = 'lib/core/crash_reporting/crash_reporter.dart';

    /// The uses of the functions of the roles of [modules] that the report
    /// names in the tests of the [files] by path.
    Future<Object?> usesIn(
      Map<String, String> files, {
      List<SmfModule> modules = smfModules,
    }) async {
      final fileSystem = MemoryFileSystem();
      for (final MapEntry(key: path, value: text) in files.entries) {
        fileSystem.file('/tests/a/$path')
          ..createSync(recursive: true)
          ..writeAsStringSync(text);
      }
      final report = await appTestsReport(
        [MatrixAppTest('/tests/a', appliesTo: (_) => true)],
        modules: modules,
        packages: const {},
        apps: () async => const [],
        fileSystem: fileSystem,
      );
      return report.single['roleFunctionUses'];
    }

    const imports = """
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart';
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart'
    as role;
""";

    for (final (use, code) in [
      ('a call of it', 'createCrashReporter();'),
      ('a call of it with a prefix', 'role.createCrashReporter();'),
      ('a tear-off of it', 'final create = createCrashReporter;'),
      (
        'a tear-off of it with a prefix',
        'final create = role.createCrashReporter;'
      ),
    ]) {
      test('such as $use, through an import of its file, with its role',
          () async {
        expect(
          await usesIn({
            'test/a_test.dart': '$imports\nvoid main() {\n  $code\n}\n',
          }),
          [
            {
              'use': 'test/a_test.dart: createCrashReporter() of $path',
              'role': 'crash_reporting',
            },
          ],
        );
      });
    }

    test('but no use of a function of the same name from another file',
        () async {
      expect(
        await usesIn({
          'test/a_test.dart': """
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart'
    as role;
import 'package:{{app_name}}/core/crash_reporting/other_crash_reporter.dart';
import 'package:{{app_name}}/core/crash_reporting/other_crash_reporter.dart'
    as other;

void main() {
  createCrashReporter();
  other.installCrashReporting();
  final create = other.createCrashReporter;
}
""",
        }),
        isEmpty,
      );
    });

    test(
        'in the files of the test by their path, of every such role, but '
        'the hidden files and those that are not Dart', () async {
      const call = """
import 'package:{{app_name}}/core/crash_reporting/crash_reporter.dart';

void main() => installCrashReporting();
""";
      const analytics = 'lib/analytics.dart: createAnalyticsService() of '
          'lib/core/analytics/analytics_service.dart';

      expect(
        await usesIn({
          'test/a_test.dart': call,
          'test/.dart_tool/b.dart': call,
          '.hidden/c.dart': call,
          'test/notes.txt': call,
          'lib/analytics.dart': """
import 'package:{{app_name}}/core/analytics/analytics_service.dart';

final analytics = createAnalyticsService();
""",
        }),
        [
          {'use': analytics, 'role': 'analytics'},
          {
            'use': 'test/a_test.dart: installCrashReporting() of $path',
            'role': 'crash_reporting',
          },
        ],
      );
    });

    test('and has none to look for of a role whose file declares only types',
        () async {
      expect(
        await usesIn(
          {
            'test/a_test.dart': """
import 'package:{{app_name}}/core/types/types.dart';

Type type() => Types;
""",
          },
          modules: const [FlutterCoreModule(), _TypesProvider()],
        ),
        isEmpty,
      );
    });

    test(
        'and fails when the contract harness renders no app of a provider of '
        'such a role, or one without the file of the role', () async {
      await expectLater(
        usesIn(
          const {},
          modules: const [FlutterCoreModule(), _BrokenAnalytics()],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            startsWith(
              'The contract harness renders no app of broken_analytics, '
              'which provides the analytics role: error [broken_analytics]',
            ),
          ),
        ),
      );
      await expectLater(
        usesIn(
          const {},
          modules: const [FlutterCoreModule(), _TypesProvider(file: false)],
        ),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            'The app of types_provider that the contract harness renders has '
                'no ${_TypesRole.file} of the types role.',
          ),
        ),
      );
    });
  });

  test(
      'the report of the app tests names the modules whose ids each uses: '
      'those that, with another module in their place, change whether it '
      'applies to an app, the values of its files there or the files it '
      'generates', () async {
    final (:apps, :failed) = await matrixOf(smfModules);
    final withHome = [
      for (final app in apps)
        if (app.modules.contains(HomeModule.id)) app.name,
    ];
    final cli = await _appTestsOf('smf_flutter_cli');
    bool hasRouter(MatrixApp app) =>
        app.hook!.presentRoles.contains(routerRole);
    String startScreenOf(MatrixApp app) =>
        routerRole.startIn(routerRole.hookInput(app.hook!))?.fullName ?? '/';

    final report = await appTestsReport(
      [
        // The start screen that the router role chose for the app, by the
        // routes of its modules, as a value and in a file that it
        // generates.
        MatrixAppTest(
          '$cli/by_role',
          appliesTo: hasRouter,
          values: (app) => {'start_screen': startScreenOf(app)},
          generatedFiles: (app, packageName) => {
            'test/start_screen.dart': "const start = '${startScreenOf(app)}';",
          },
        ),
        // The start screen by whether the app has home, which a second
        // feature that can start the app would make wrong.
        MatrixAppTest(
          '$cli/start_by_id',
          appliesTo: hasRouter,
          values: (app) => {
            'start_screen':
                app.modules.contains(HomeModule.id) ? 'home.home' : '/',
          },
        ),
        // The apps whose case is named after home.
        MatrixAppTest(
          '$cli/by_name',
          appliesTo: (app) => app.name.startsWith('home'),
        ),
        // The apps with a router, found by looking every module of the app
        // up by its id, which fails with another module in its place.
        MatrixAppTest(
          '$cli/by_lookup',
          appliesTo: (app) => [
            for (final id in app.modules)
              smfModules.singleWhere((module) => module.descriptor.id == id),
          ].any((module) => module.descriptor.provides.contains(routerRole)),
        ),
        // A file that it generates by whether the app has home.
        MatrixAppTest(
          '$cli/files_by_id',
          appliesTo: hasRouter,
          generatedFiles: (app, packageName) => {
            'test/start_screen.dart': app.modules.contains(HomeModule.id)
                ? "const start = 'home.home';"
                : "const start = '/';",
          },
        ),
      ],
      modules: smfModules,
      packages: _packagesOf(smfModules),
      apps: () async => apps,
    );

    expect(failed, isEmpty);
    expect(withHome, isNotEmpty);
    // The apps of each module that a test uses, by the id of the module.
    Map<String, Object?> usesOf(Map<String, Object> test) => {
          for (final use in test['uses']! as List<Object>)
            if (use case {'module': final String id, 'apps': final apps})
              id: apps,
        };
    expect(report.map((test) => test['modules']), everyElement(isEmpty));
    expect(usesOf(report[0]), isEmpty);
    expect(report[1]['uses'], [
      {'module': 'home', 'package': 'smf_home_flutter', 'apps': withHome},
    ]);
    expect(usesOf(report[2]), {
      'home': ['home'],
    });
    expect(
      usesOf(report[3]).keys,
      unorderedEquals([
        for (final module in smfModules) module.descriptor.id.value,
      ]),
    );
    expect(report[4]['uses'], [
      {'module': 'home', 'package': 'smf_home_flutter', 'apps': withHome},
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
      bool everyModule = false,
    }) =>
        runMatrix(
          modules,
          directory: '/apps',
          appTests: MatrixAppTests(appTests, testedRoles: testedRoles),
          selection: MatrixSelection(only: only, everyModule: everyModule),
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

      /// The problem that the tests of the state management role tell its
      /// provider [id] apart by its id in the apps [names].
      String byId(String id, String names) =>
          'The tests of /tests/state check the state management role, but '
          'select their apps, take the values of their files or generate '
          'files by the id of $id, which provides it: with another module in '
          'its place, they would apply otherwise, or get other values or '
          'files, in these apps of the matrix: $names. A test of a role takes '
          'what it needs of the providers of the role from the roles of the '
          'app (MatrixApp.hook), such as whether the app has the role '
          '(presentRoles), so that a new provider of the role gets the test '
          'as it is.';

      test(
          'passes when they apply to an app of every provider of the role, '
          'which they select by the roles of the app', () async {
        final byRole = stateTest(
          (app) => app.hook!.presentRoles.contains(stateManagementRole),
        );
        // Tests that generate a file from the roles of the app.
        final generating = MatrixAppTest(
          '/tests/state',
          appliesTo: (app) =>
              app.hook!.presentRoles.contains(stateManagementRole),
          generatedFiles: (app, packageName) => {
            'test/roles.dart': [
              for (final role in app.hook!.presentRoles) '// ${role.id}\n',
            ].join(),
          },
          roles: {stateManagementRole},
        );

        for (final test in [byRole, generating]) {
          expect(
            await run(
              modules: modules,
              appTests: [test],
              testedRoles: {stateManagementRole},
            ),
            0,
          );
          expect(problems(), isEmpty);
        }
        expect(tested, isNotEmpty);
      });

      test(
          'fails when they leave out a provider of the role, as they do when '
          'they select the apps of another provider by its id', () async {
        final byModule = stateTest(
          (app) => app.modules.contains(BlocModule.id),
        );

        expect(await run(modules: modules, appTests: [byModule]), 1);
        expect(problems(), [
          equals(byId('bloc', 'bloc')),
          equals(
            'The tests of /tests/state check the state management role, but '
            'apply to no app with riverpod, which provides it: a test of a '
            'role applies to the apps of every provider of the role, which '
            'it selects by the role.',
          ),
        ]);
      });

      test(
          'fails when they tell the providers of the role apart by their ids, '
          'also when they apply to the apps of each', () async {
        // The apps of each provider by its id, and the apps of the modules
        // that provide the role, looked up by their ids, which finds no
        // module with another id.
        final byIds = stateTest(
          (app) =>
              app.modules.contains(BlocModule.id) ||
              app.modules.contains(RiverpodModule.id),
        );
        final byLookup = stateTest(
          (app) => app.modules.any(
            (id) => modules.any(
              (module) =>
                  module.descriptor.id == id &&
                  module.descriptor.provides.contains(stateManagementRole),
            ),
          ),
        );

        for (final test in [byIds, byLookup]) {
          expect(await run(modules: modules, appTests: [test]), 1);
          expect(problems(), [
            equals(byId('bloc', 'bloc')),
            equals(byId('riverpod', 'riverpod')),
          ]);
          log.clear();
        }

        // A value of the files by the id of a provider.
        final values = MatrixAppTest(
          '/tests/state',
          appliesTo: (app) =>
              app.hook!.presentRoles.contains(stateManagementRole),
          values: (app) => {
            'manager': app.modules.contains(BlocModule.id) ? 'bloc' : 'other',
          },
          roles: {stateManagementRole},
        );
        expect(await run(modules: modules, appTests: [values]), 1);
        expect(problems(), [equals(byId('bloc', 'bloc'))]);
        log.clear();

        // A file that the tests generate by the id of a provider.
        final files = MatrixAppTest(
          '/tests/state',
          appliesTo: (app) =>
              app.hook!.presentRoles.contains(stateManagementRole),
          generatedFiles: (app, packageName) => {
            'test/manager.dart':
                app.modules.contains(RiverpodModule.id) ? 'riverpod' : 'other',
          },
          roles: {stateManagementRole},
        );
        expect(await run(modules: modules, appTests: [files]), 1);
        expect(problems(), [equals(byId('riverpod', 'riverpod'))]);
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

  group('createEveryModuleApps', () {
    late List<String> log;
    late List<List<String>> created;

    setUp(() {
      log = [];
      created = [];
    });

    Future<int> create({
      List<SmfModule> modules = smfModules,
      String name = 'start_app',
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
          name: name,
          options: options,
          apps: EveryModuleApps(withoutExternalSteps: withoutExternalSteps),
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
              'settings',
              'bottom_tabs',
              'gen_l10n',
              'get_it',
              'event_bus',
              'shared_preferences',
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

    test(
        'generates nothing with a name that smf create would take for an '
        'option, as when the options come before it', () async {
      expect(
        await create(name: '--org', options: const ['com.example.ci', 'x']),
        64,
      );

      expect(created, isEmpty);
      expect(log, [
        equals(
          'The name of the apps, --org, starts with -, so smf create would '
          'take it for an option: give the name right after the directory, '
          'and the options of smf create after it.',
        ),
      ]);
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

  test(
      'the tests of an app go into it with the files that they generate for '
      'the app of the matrix, as they generate them', () {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/tests/core/test/core/core_test.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync("import 'services.dart';\n// {{app_name}}\n");
    fileSystem.file('/tests/more/test/more_test.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// more\n');
    const app = MatrixApp('home', [ModuleId('home')]);
    final generating = <String>[];

    final added = addAppTests(
      [
        MatrixAppTest(
          '/tests/core',
          appliesTo: (app) => true,
          generatedFiles: (app, packageName) {
            generating.add('${app.name} as $packageName');
            return {
              // What the app is, with the name of its package, and no
              // placeholder filled.
              'test/core/services.dart':
                  "import 'package:$packageName/app.dart';\n"
                      '// ${app.modules.single} {{app_name}}\n',
              'lib/services.dart': '// ${app.name}\n',
            };
          },
        ),
        MatrixAppTest('/tests/more', appliesTo: (app) => true),
      ],
      app: app,
      directory: '/apps/app_1',
      packageName: 'my_app',
      fileSystem: fileSystem,
    );

    expect(generating, ['home as my_app']);
    expect(added, [
      'test/core/core_test.dart',
      'test/core/services.dart',
      'lib/services.dart',
      'test/more_test.dart',
    ]);
    String read(String path) =>
        fileSystem.file('/apps/app_1/$path').readAsStringSync();
    expect(read('test/core/core_test.dart'), contains('// my_app\n'));
    expect(
      read('test/core/services.dart'),
      "import 'package:my_app/app.dart';\n// home {{app_name}}\n",
    );
    expect(read('lib/services.dart'), '// home\n');
  });

  test(
      'the files that tests generate go into the app of the matrix only at '
      'paths in it that no other file of the tests has', () {
    final fileSystem = MemoryFileSystem();
    fileSystem.file('/tests/core/test/core_test.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// core\n');
    fileSystem.file('/tests/more/test/more_test.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// more\n');
    const app = MatrixApp('home', [ModuleId('home')]);
    List<String> add(
      Map<String, String> files, {
      MatrixApp? matrixApp = app,
    }) =>
        addAppTests(
          [
            MatrixAppTest('/tests/core', appliesTo: (app) => true),
            MatrixAppTest(
              '/tests/more',
              appliesTo: (app) => true,
              generatedFiles: (app, packageName) => files,
            ),
          ],
          app: matrixApp,
          directory: '/apps/app_1',
          packageName: 'my_app',
          fileSystem: fileSystem,
        );
    // A problem reads as its message.
    Matcher throwsProblem(String message) => throwsA(
          isA<MatrixAppTestException>()
              .having((error) => error.message, 'message', message),
        );

    for (final (path, other) in [
      // A file of other tests, and one of their own.
      ('test/core_test.dart', '/tests/core'),
      ('test/more_test.dart', '/tests/more'),
    ]) {
      expect(
        () => add({path: '// generated\n'}),
        throwsProblem(
          'The tests of /tests/more generate $path, which the tests of '
          '$other have too.',
        ),
        reason: path,
      );
    }
    for (final path in [
      '',
      '/test/services.dart',
      '../services.dart',
      'test/../../services.dart',
      'test/./services.dart',
      'test//services.dart',
      r'test\services.dart',
      'C:/services.dart',
    ]) {
      expect(
        () => add({path: '// generated\n'}),
        throwsProblem(
          'The tests of /tests/more generate a file at "$path", which is no '
          'path in the app, such as test/services.dart: names separated by /, '
          r'none of them empty, . or .., and none with \ or :.',
        ),
        reason: path,
      );
    }
    // An app that smf create generated outside the matrix, which the files
    // of an app of the matrix do not fit.
    expect(
      () => add({'test/services.dart': '// generated\n'}, matrixApp: null),
      throwsProblem(
        'The tests of /tests/more generate files for an app of the matrix, '
        'but the app is none.',
      ),
    );
    expect(fileSystem.directory('/apps/app_1').existsSync(), isFalse);
  });

  group('the mocks of the tests of an app', () {
    late MemoryFileSystem fileSystem;
    const app = MatrixApp('home', [ModuleId('home')]);

    setUp(() {
      fileSystem = MemoryFileSystem();
      for (final path in [
        '/tests/core/test/core_mocks.dart',
        '/tests/core/test/core_test.dart',
        '/tests/core/lib/options.dart',
        '/tests/crash/test/mocks/crash_mocks.dart',
        '/tests/start/integration_test/start_check.dart',
      ]) {
        fileSystem.file(path)
          ..createSync(recursive: true)
          ..writeAsStringSync('// {{app_name}}\n');
      }
    });

    List<String> add(List<MatrixAppTest> tests) => addAppTests(
          tests,
          app: app,
          directory: '/apps/app_1',
          packageName: 'my_app',
          fileSystem: fileSystem,
        );

    const core = MatrixMocks('test/core_mocks.dart', 'mockCore');
    const crash = MatrixMocks('test/mocks/crash_mocks.dart', 'mockCrash');

    test(
        'go into the app with the configuration of its tests, which sets up '
        'the mocks of each test that declares them, in the order of the '
        'tests, before the tests of each test file', () {
      final added = add([
        MatrixAppTest('/tests/core', appliesTo: (_) => true, mocks: core),
        MatrixAppTest('/tests/start', appliesTo: (_) => true),
        MatrixAppTest('/tests/crash', appliesTo: (_) => true, mocks: crash),
      ]);

      expect(added, [
        'lib/options.dart',
        'test/core_mocks.dart',
        'test/core_test.dart',
        'integration_test/start_check.dart',
        'test/mocks/crash_mocks.dart',
        'test/flutter_test_config.dart',
      ]);
      final config = fileSystem
          .file('/apps/app_1/test/flutter_test_config.dart')
          .readAsStringSync();
      expect(
        config,
        endsWith('''
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';

import 'core_mocks.dart' as mocks0;
import 'mocks/crash_mocks.dart' as mocks1;

Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  setUpAll(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    mocks0.mockCore();
    mocks1.mockCrash();
  });
  await testMain();
}
'''),
      );
      // flutter test calls testExecutable of the configuration with the
      // main() of each test file in test/.
      final index =
          DartFileIndexer.index('test/flutter_test_config.dart', config);
      expect(
        index.declarations.map((declaration) => declaration.name),
        ['testExecutable'],
      );
      expect(
        [
          for (final import in index.imports)
            if (import.prefix case final prefix?) '$prefix: ${import.uri}',
        ],
        ['mocks0: core_mocks.dart', 'mocks1: mocks/crash_mocks.dart'],
      );
      expect(
        [
          for (final call in index.invocations)
            if (call.target case final target?) '$target.${call.name}',
        ],
        [
          'TestWidgetsFlutterBinding.ensureInitialized',
          'mocks0.mockCore',
          'mocks1.mockCrash',
        ],
      );
    });

    test('leave the tests of an app without mocks as they are', () {
      final added = add([
        MatrixAppTest('/tests/core', appliesTo: (_) => true),
        MatrixAppTest('/tests/start', appliesTo: (_) => true),
      ]);

      expect(added, isNot(contains('test/flutter_test_config.dart')));
      expect(
        fileSystem
            .file('/apps/app_1/test/flutter_test_config.dart')
            .existsSync(),
        isFalse,
      );
    });

    test(
        'are in a file of their tests in test/, and the configuration is no '
        'file of a test', () {
      // A problem reads as its message.
      Matcher throwsProblem(String message) => throwsA(
            isA<MatrixAppTestException>()
                .having((error) => error.message, 'message', message),
          );
      String declared(String directory, String path) =>
          'The tests of $directory declare their mocks in $path, which is no '
          'file of theirs in test/.';

      for (final path in [
        // No file of the tests.
        'test/gone_mocks.dart',
        // A file of the tests out of test/.
        'lib/options.dart',
        // A file of other tests.
        'test/mocks/crash_mocks.dart',
      ]) {
        expect(
          () => add([
            MatrixAppTest(
              '/tests/core',
              appliesTo: (_) => true,
              mocks: MatrixMocks(path, 'mock'),
            ),
            MatrixAppTest('/tests/crash', appliesTo: (_) => true),
          ]),
          throwsProblem(declared('/tests/core', path)),
          reason: path,
        );
      }

      fileSystem.file('/tests/start/test/flutter_test_config.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('// Of the tests.\n');
      expect(
        () => add([
          MatrixAppTest('/tests/core', appliesTo: (_) => true, mocks: core),
          MatrixAppTest('/tests/start', appliesTo: (_) => true),
        ]),
        throwsProblem(
          'The tests of /tests/start have test/flutter_test_config.dart, '
          'which the matrix writes for the mocks of the tests.',
        ),
      );
      expect(fileSystem.directory('/apps/app_1').existsSync(), isFalse);
    });
  });

  group('the probes of the tests of an app', () {
    late MemoryFileSystem fileSystem;
    const app = MatrixApp('home', [ModuleId('home')]);

    setUp(() {
      fileSystem = MemoryFileSystem();
      for (final path in [
        '/tests/walk/integration_test/walk/walk.dart',
        '/tests/walk/test/walk_test.dart',
        '/tests/start/integration_test/start_check.dart',
        '/tests/services/test/services_test.dart',
      ]) {
        fileSystem.file(path)
          ..createSync(recursive: true)
          ..writeAsStringSync('// {{app_name}}\n');
      }
    });

    List<String> add(List<MatrixAppTest> tests) => addAppTests(
          tests,
          app: app,
          directory: '/apps/app_1',
          packageName: 'my_app',
          fileSystem: fileSystem,
        );

    MatrixAppTest walk({String path = 'integration_test/walk/walk.dart'}) =>
        MatrixAppTest(
          '/tests/walk',
          appliesTo: (_) => true,
          startProbe: MatrixStartProbe(path, 'probeRoutes'),
        );
    // A probe in a file that the tests generate for the app.
    final services = MatrixAppTest(
      '/tests/services',
      appliesTo: (_) => true,
      generatedFiles: (app, packageName) => {
        'integration_test/services/probe.dart': '// ${app.name}\n',
      },
      startProbe: const MatrixStartProbe(
        'integration_test/services/probe.dart',
        'probeServices',
      ),
    );
    final start = MatrixAppTest(
      '/tests/start',
      appliesTo: (_) => true,
      readsStartProbes: true,
    );

    test(
        'go into the app with the list of the probes, which the tests that '
        'run them import: the probe of each test, in the order of the '
        'tests, after the name of its directory', () {
      final added = add([services, start, walk()]);

      expect(added, [
        'test/services_test.dart',
        'integration_test/services/probe.dart',
        'integration_test/start_check.dart',
        'integration_test/walk/walk.dart',
        'test/walk_test.dart',
        startProbesFile,
      ]);
      expect(startProbesFile, 'integration_test/start_probes.dart');
      final list =
          fileSystem.file('/apps/app_1/$startProbesFile').readAsStringSync();
      expect(
        list,
        endsWith('''
import 'services/probe.dart' as probe0;
import 'walk/walk.dart' as probe1;

/// The probes of the tests of the app, each with the name of its tests: a
/// function that goes through the running app, with the function that
/// waits until the screen settles, and returns the problems that it finds.
const List<(String, Future<List<String>> Function(Future<void> Function()))>
    startProbes = [
  ('services', probe0.probeServices),
  ('walk', probe1.probeRoutes),
];
'''),
      );
      // The check imports it next to itself, and reads startProbes.
      final (:index, :errors) = DartFileIndexer.parse(startProbesFile, list);
      expect(errors, isEmpty);
      expect(
        index.declarations.map((declaration) => declaration.name),
        ['startProbes'],
      );
      expect(
        [
          for (final import in index.imports) '${import.prefix}: ${import.uri}',
        ],
        ['probe0: services/probe.dart', 'probe1: walk/walk.dart'],
      );
      expect(
        [
          for (final access in index.memberAccesses)
            '${access.enclosingDeclaration}: ${access.target}.${access.name}',
        ],
        [
          'startProbes: probe0.probeServices',
          'startProbes: probe1.probeRoutes',
        ],
      );
    });

    test(
        'go into the list as none when no test that goes into the app has '
        'one, and the list goes into no app without tests that run them', () {
      expect(add([start]), contains(startProbesFile));
      final list =
          fileSystem.file('/apps/app_1/$startProbesFile').readAsStringSync();
      final (:index, :errors) = DartFileIndexer.parse(startProbesFile, list);
      expect(errors, isEmpty);
      expect(index.imports, isEmpty);
      expect(index.memberAccesses, isEmpty);
      expect(list, contains('startProbes = [\n];\n'));

      fileSystem.directory('/apps/app_1').deleteSync(recursive: true);
      expect(add([services, walk()]), isNot(contains(startProbesFile)));
      expect(
        fileSystem.file('/apps/app_1/$startProbesFile').existsSync(),
        isFalse,
      );
    });

    test(
        'are in a file of their tests in integration_test/, with the tests '
        'that run them or without, and the list is no file of a test', () {
      // A problem reads as its message.
      Matcher throwsProblem(String message) => throwsA(
            isA<MatrixAppTestException>()
                .having((error) => error.message, 'message', message),
          );

      for (final path in [
        // No file of the tests.
        'integration_test/walk/gone.dart',
        // A file of the tests out of integration_test/.
        'test/walk_test.dart',
        // A file of other tests.
        'integration_test/start_check.dart',
        'integration_test/services/probe.dart',
      ]) {
        for (final tests in [
          [walk(path: path), start, services],
          [walk(path: path), services],
        ]) {
          expect(
            () => add(tests),
            throwsProblem(
              'The tests of /tests/walk declare their probe in $path, which '
              'is no file of theirs in integration_test/.',
            ),
            reason: '$path with ${tests.length} tests',
          );
        }
      }

      fileSystem.file('/tests/walk/integration_test/start_probes.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('// Of the tests.\n');
      expect(
        () => add([walk(), start]),
        throwsProblem(
          'The tests of /tests/walk have integration_test/start_probes.dart, '
          'which the matrix writes for the probes of the tests.',
        ),
      );
      expect(fileSystem.directory('/apps/app_1').existsSync(), isFalse);
    });
  });

  group('appTestsFor', () {
    const app = MatrixApp('home', [ModuleId('home')]);
    const other = MatrixApp('other', [ModuleId('other')]);
    bool onlyHome(MatrixApp app) => app.name == 'home';
    final start = MatrixAppTest(
      '/tests/start',
      appliesTo: (_) => true,
      readsStartProbes: true,
    );
    const probe = MatrixStartProbe('integration_test/probe.dart', 'probe');
    final walk =
        MatrixAppTest('/tests/walk', appliesTo: onlyHome, startProbe: probe);
    final services = MatrixAppTest(
      '/tests/services',
      appliesTo: (_) => true,
      startProbe: probe,
    );
    final plain = MatrixAppTest('/tests/plain', appliesTo: (_) => true);
    final all = [walk, plain, start, services];
    List<String> directories(List<MatrixAppTest> tests) =>
        [for (final test in tests) test.directory];

    test(
        'adds to the tests named for an app of the matrix, with tests that '
        'run the probes, each other test with a probe that applies to it', () {
      expect(directories(appTestsFor(app, [start], all)), [
        '/tests/start',
        '/tests/walk',
        '/tests/services',
      ]);
      expect(directories(appTestsFor(other, [start], all)), [
        '/tests/start',
        '/tests/services',
      ]);
      // A test named with them goes into the app once, where it is named.
      expect(directories(appTestsFor(app, [services, start], all)), [
        '/tests/services',
        '/tests/start',
        '/tests/walk',
      ]);
      // Without tests that run the probes, only the tests named.
      expect(directories(appTestsFor(app, [plain, walk], all)), [
        '/tests/plain',
        '/tests/walk',
      ]);
    });

    test('fails on a test named for an app that it does not apply to', () {
      expect(
        () => appTestsFor(other, [start, walk], all),
        throwsA(
          isA<MatrixAppTestException>().having(
            (error) => error.message,
            'message',
            'The tests of /tests/walk do not apply to other.',
          ),
        ),
      );
    });
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
      MatrixApp? app,
    }) =>
        addAppTestsTo(
          generated,
          tests,
          app: app,
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

    test(
        'adds the configuration that sets up the mocks of the tests, as in '
        'an app of the matrix', () async {
      fileSystem.file('/tests/core/test/core_mocks.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('void mockCore() {}\n');

      final (code, output) = await add([
        MatrixAppTest('/tests/start', appliesTo: (app) => true),
        MatrixAppTest(
          '/tests/core',
          appliesTo: (app) => true,
          mocks: const MatrixMocks('test/core_mocks.dart', 'mockCore'),
        ),
      ]);

      expect(code, 0);
      expect(
        output,
        'Added the tests integration_test/start_test.dart, '
        'test/core_mocks.dart, test/flutter_test_config.dart.\n',
      );
      expect(
        fileSystem
            .file('/apps/start_app/test/flutter_test_config.dart')
            .readAsStringSync(),
        contains('    mocks0.mockCore();\n'),
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

    test(
        'adds the tests to the app of the matrix that smf create generated '
        'outside it, with the values and the files of that app', () async {
      fileSystem
          .file('/tests/start/integration_test/start_test.dart')
          .writeAsStringSync('// {{app_name}} {{screen}}\n');
      final tests = [
        MatrixAppTest(
          '/tests/start',
          appliesTo: (app) => true,
          values: (app) => {'screen': '${app.modules.single}.home'},
          generatedFiles: (app, packageName) => {
            'integration_test/screens.dart': '// $packageName ${app.name}\n',
          },
        ),
      ];

      final (code, output) = await add(
        tests,
        app: const MatrixApp('every module', [ModuleId('home')]),
      );

      expect(code, 0);
      expect(
        output,
        'Added the tests integration_test/start_test.dart, '
        'integration_test/screens.dart.\n',
      );
      String read(String path) =>
          fileSystem.file('/apps/start_app/$path').readAsStringSync();
      expect(
        read('integration_test/start_test.dart'),
        '// start_app home.home\n',
      );
      expect(
        read('integration_test/screens.dart'),
        '// start_app every module\n',
      );

      // Without the app of the matrix, which the files come from.
      fileSystem.directory('/apps/start_app').deleteSync(recursive: true);
      final (failed, problem) = await add(tests);

      expect(failed, 1);
      expect(
        problem,
        'The tests of /tests/start generate files for an app of the matrix, '
        'but the app is none.',
      );
      expect(fileSystem.directory('/apps/start_app').existsSync(), isFalse);
    });
  });
}
