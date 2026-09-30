// The tests that the matrix of CI adds to the apps of the modules of
// `smf create` (smfAppTests, which tool/matrix.dart runs). CI runs them
// only in its job with Flutter, which checks that they apply to some app
// and that they check the contract of their roles with every provider
// only at its end; these tests check the same without Flutter.
import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_app_tests.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

void main() {
  late MatrixAppTests appTests;
  late List<MatrixApp> apps;

  setUpAll(() async {
    appTests = await smfAppTests();
    final (apps: matrix, :failed) = await matrixOf(smfModules);
    expect(failed, isEmpty);
    apps = matrix;
  });

  /// The app test whose files are in the directory [name].
  MatrixAppTest named(String name) =>
      appTests.tests.singleWhere((test) => p.basename(test.directory) == name);

  test('each app test applies to an app of the matrix', () {
    expect(appTests.tests, isNotEmpty);
    for (final test in appTests.tests) {
      expect(apps.where(test.appliesTo), isNotEmpty, reason: test.directory);
    }
  });

  test(
      'the app tests check the contract of the router role and of the DI '
      'role with every provider of each, which they tell apart by the roles '
      'of the app only', () {
    expect(appTests.testedRoles, containsAll([routerRole, diRole]));
    expect(named('screen_views').roles, contains(routerRole));
    expect(named('di_role').roles, {diRole});

    expect(appTests.roleProblems(smfModules, apps), isEmpty);
  });

  test(
      'the test of the DI role applies to the apps with the role whose '
      'modules register services, and gets the services of each from the '
      'data of the role', () {
    final diRoleTest = named('di_role');
    bool hasDi(MatrixApp app) => app.hook!.presentRoles.contains(diRole);

    expect(
      [
        for (final app in apps)
          if (diRoleTest.appliesTo(app)) app.name,
      ],
      [
        'event_bus with di',
        'firebase_crashlytics with di',
        'firebase_analytics with di, router',
        'firebase_analytics with di',
        'every module (bloc)',
        'every module (riverpod)',
      ],
    );
    // The app of the container alone, whose modules register nothing.
    expect(
      [
        for (final app in apps)
          if (hasDi(app) && !diRoleTest.appliesTo(app)) app.name,
      ],
      ['get_it'],
    );

    for (final app in apps.where(diRoleTest.appliesTo)) {
      final files = diRoleTest.generatedFiles!(app, 'my_app');
      expect(files.keys, [registeredServicesFile]);
      final (:index, :errors) = DartFileIndexer.parse(
        registeredServicesFile,
        files[registeredServicesFile]!,
      );
      expect(errors, isEmpty, reason: app.name);
      // The service locator, and the file of each type once, each with a
      // prefix of its own.
      final prefixes = {
        for (final import in index.imports) import.uri: import.prefix!,
      };
      expect(
        prefixes,
        containsPair('package:my_app/core/di/service_locator.dart', 'locator'),
      );
      expect({...prefixes.values}, hasLength(prefixes.length));
      expect(
        index.declarations.map((declaration) => declaration.name),
        ['RegisteredService', 'registeredServices'],
      );
      // Each service, in the order of its registration, resolved through
      // the service locator by its type and name.
      final registrations = diRole.graphOf(diRole.hookInput(app.hook!)).ordered;
      expect(registrations, isNotEmpty);
      String typeOf(TypeRef type) =>
          '${prefixes[type.import!.resolveUri('my_app')]}.${type.name}';
      String call(
        String target,
        String name,
        List<String> types, {
        required bool named,
      }) =>
          '$target.$name<${types.join(', ')}>(${named ? 'instanceName' : ''})';
      expect(
        [
          for (final invocation in index.invocations)
            call(
              '${invocation.target}',
              invocation.name,
              invocation.typeArguments,
              named: invocation.namedArguments.contains('instanceName'),
            ),
        ],
        [
          for (final registration in registrations)
            call(
              'locator',
              'resolve',
              [typeOf(registration.type)],
              named: registration.instanceName != null,
            ),
        ],
        reason: app.name,
      );
      for (final registration in registrations) {
        expect(
          files[registeredServicesFile],
          contains(
            "    name: '${registration.key}',\n"
            "    lifetime: '${registration.lifetime.name}',\n",
          ),
          reason: app.name,
        );
      }
    }
  });

  test(
      'the services of the test of the DI role name a type of dart:core '
      'without a prefix, the file of a package with one, and a service by '
      'its name, and the test takes the apps with the lifetimes it is given',
      () async {
    const file = ImportRef.app('core/values/values.dart');
    MatrixApp appOf(List<DiRegistration> registrations) => MatrixApp(
          'values',
          const [ModuleId('values')],
          hook: RoleHookRequest(
            data: [
              for (final registration in registrations)
                diRole
                    .data(registration)
                    .withOrigin(const ModuleOrigin(ModuleId('values'))),
            ],
            presentRoles: {diRole},
            context: ContractHarness.defaultContext,
          ),
        );
    const registrations = [
      DiRegistration(
        type: TypeRef('Uri'),
        create: FactoryRef('createApiUri', import: file),
        lifetime: DiLifetime.singleton,
        instanceName: 'api',
      ),
      DiRegistration(
        type: TypeRef('Random', import: ImportRef('dart:math')),
        create: FactoryRef('createRandom', import: file),
      ),
      DiRegistration(
        type: TypeRef('Values', import: file),
        create: FactoryRef('createValues', import: file),
        lifetime: DiLifetime.factory,
      ),
    ];
    final app = appOf(registrations);

    final text = named('di_role').generatedFiles!(app, 'my_app').values.single;

    final (:index, :errors) = DartFileIndexer.parse(
      registeredServicesFile,
      text,
    );
    expect(errors, isEmpty);
    expect(
      [for (final import in index.imports) '${import.uri} as ${import.prefix}'],
      [
        'dart:math as di0',
        'package:my_app/core/di/service_locator.dart as locator',
        'package:my_app/core/values/values.dart as di1',
      ],
    );
    String written(IndexedInvocation call) =>
        '${call.target}.${call.name}<${call.typeArguments.join()}>'
        '(${call.namedArguments.join()})';
    expect(
      index.invocations.map(written),
      [
        'locator.resolve<Uri>(instanceName)',
        'locator.resolve<di0.Random>()',
        'locator.resolve<di1.Values>()',
      ],
    );
    expect(
      text,
      contains(
        "    name: 'Uri \"api\"',\n"
        "    lifetime: 'singleton',\n"
        "    resolve: () => locator.resolve<Uri>(instanceName: 'api'),\n",
      ),
    );

    // The fixtures take only the apps whose services have every lifetime,
    // which no app of the modules of the CLI has.
    final everyLifetime = await diRoleAppTest(
      lifetimes: DiLifetime.values.toSet(),
    );
    expect(everyLifetime.appliesTo(app), isTrue);
    expect(everyLifetime.appliesTo(appOf(registrations.sublist(1))), isFalse);
    expect(apps.where(everyLifetime.appliesTo), isEmpty);
  });

  test(
      'the test of the screen views expects the screen that the router role '
      'chose for the app to start on', () {
    final screenViews = named('screen_views');

    expect(
      {
        for (final app in apps)
          if (screenViews.appliesTo(app))
            app.name: screenViews.values!(app)['start_screen'],
      },
      {
        // The fallback screen of the app entry, without a route that can
        // start the app.
        'firebase_analytics with di, router': '/',
        'firebase_analytics with router': '/',
        // The start screen of home.
        'every module (bloc)': 'home.home',
        'every module (riverpod)': 'home.home',
      },
    );
  });
}
