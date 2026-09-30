/// The tests that the matrix of CI adds to the apps of the modules of
/// `smf create`, for `tool/matrix.dart` and for the app of several
/// providers of the fixture registry. No library of the binary imports it.
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// The tests that the matrix of the modules of `smf create` adds to its
/// apps, which the CLI and the packages of its modules keep in their
/// `app_tests`, and the roles whose contract they check with every
/// provider; `tool/matrix.dart` runs them in CI.
///
/// Only that tool, the tests of the CLI and the app of several providers of
/// the fixture registry, which runs them next to other providers of their
/// roles, use them: they name the modules whose app tests they register and
/// the roles whose contract those check, which the binary knows nothing of.
Future<MatrixAppTests> smfAppTests() async {
  final cli = await appTestsDirectoryOf('smf_flutter_cli');
  final firebaseCore = await appTestsDirectoryOf('smf_firebase_core');
  final crashlytics = await appTestsDirectoryOf('smf_firebase_crashlytics');
  final analytics = await appTestsDirectoryOf('smf_firebase_analytics');
  return MatrixAppTests(
    [
      // The app starts and shows its first screen: a check that CI builds
      // as the entry of the app and starts on an Android emulator and on an
      // iOS simulator with .github/scripts/start_app.sh, in the apps that
      // it adds it to with --add-app-tests. It knows no module, only main()
      // of lib/main.dart, which the app entry role puts into every app
      // whichever module provides it, so the CLI keeps it and it applies to
      // every app. In the apps of the matrix it is only analyzed, and
      // flutter test runs the tests that the modules put into each app.
      MatrixAppTest('$cli/start', appliesTo: (_) => true),
      // The start-up of the app initializes Firebase, with the options that
      // `flutterfire configure` would write, and the mocks of Firebase Core,
      // which the matrix sets up for the tests of every module of the app.
      MatrixAppTest(
        '$firebaseCore/firebase_core',
        appliesTo: _has(FirebaseCoreModule.id),
        devDependencies: const ['firebase_core_platform_interface'],
        mocks: const MatrixMocks(
          'test/firebase_core_mocks.dart',
          'mockFirebaseCore',
        ),
      ),
      // The crash reporter of the module reaches Crashlytics, and the
      // errors that nothing catches reach it through the handlers that the
      // start-up of the app installs. The tests look only at what reaches
      // Crashlytics, not at the other crash reporters that the app may
      // have.
      MatrixAppTest(
        '$crashlytics/firebase_crashlytics',
        appliesTo: _has(FirebaseCrashlyticsModule.id),
        devDependencies: const ['firebase_crashlytics_platform_interface'],
        mocks: const MatrixMocks(
          'test/firebase_crashlytics_mocks.dart',
          'mockFirebaseCrashlytics',
        ),
      ),
      // The analytics service of the module reaches Firebase Analytics. The
      // test leaves out the other analytics services that the app may have.
      MatrixAppTest(
        '$analytics/firebase_analytics',
        appliesTo: _has(FirebaseAnalyticsModule.id),
        mocks: const MatrixMocks(
          'test/firebase_analytics_mocks.dart',
          'mockFirebaseAnalytics',
        ),
      ),
      // The first screen of an app with a router is logged once, under the
      // name of the screen that the app starts on (see _startScreenOf),
      // whichever module provides the router, which calls the listener of
      // the screen of Firebase Analytics: a test of the router role too, so
      // it finds the apps with a router by their roles.
      MatrixAppTest(
        '$analytics/screen_views',
        appliesTo: (app) =>
            _has(FirebaseAnalyticsModule.id)(app) &&
            app.hook!.presentRoles.contains(routerRole),
        values: (app) => {'start_screen': _startScreenOf(app)},
        roles: {routerRole},
      ),
      // The services of the apps whose modules register some in the DI
      // container, whichever module provides it.
      await diRoleAppTest(),
    ],
    // Each provider of the router role gets a test of the listeners of the
    // screen, the fixture registry tests the rest of the role, and each
    // provider of the DI role gets the test of its services.
    testedRoles: {routerRole, diRole},
  );
}

/// The test of the DI role that the CLI keeps in its `app_tests/di_role`,
/// for the apps with the role, whichever module provides it, whose modules
/// register services, at least one of each of [lifetimes]: once the
/// start-up of the app ran, every service resolves, a singleton and a lazy
/// singleton to one instance; `resetDependencies()` removes them all, and
/// `registerDependencies()` registers them again.
///
/// The test knows only the role. The matrix writes the services of each
/// app for it, from the registrations of its DI role, into
/// [registeredServicesFile]. The matrix of the fixtures runs it too, in the
/// apps whose services have every lifetime.
Future<MatrixAppTest> diRoleAppTest({
  Set<DiLifetime> lifetimes = const {},
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/di_role',
      appliesTo: (app) {
        if (!app.hook!.presentRoles.contains(diRole)) return false;
        final registered = {
          for (final registration in _servicesOf(app)) registration.lifetime,
        };
        return registered.isNotEmpty && registered.containsAll(lifetimes);
      },
      generatedFiles: _registeredServicesOf,
      roles: {diRole},
    );

/// The path in an app of the services that its modules register, which the
/// matrix writes for the test of the DI role: `registeredServices`, the
/// services in the order of their registration ([DiGraph.ordered]), each
/// with its name, such as `FixtureZone "utc"`, its lifetime, such as
/// `lazySingleton`, and a function that resolves it with `resolve()` of the
/// service locator of the role, by its type and its instance name.
const registeredServicesFile = 'test/di_role/registered_services.dart';

/// The file at [registeredServicesFile] of [app], an app of the matrix with
/// the DI role, whose package is [packageName].
///
/// It imports the service locator with the prefix `locator`, and the file
/// of every type of a service once, with a prefix of its own, `di0`, `di1`,
/// ..., so that no name clashes.
Map<String, String> _registeredServicesOf(
  MatrixApp app,
  String packageName,
) {
  final locator = ImportRef.app(
    DiRole.serviceLocatorFile.substring('lib/'.length),
  ).resolveUri(packageName);
  final prefixes = <String, String>{locator: 'locator'};
  String typeOf(TypeRef type) => switch (type.import) {
        null => type.name,
        final import => type.codeWith(
            prefixes.putIfAbsent(
              import.resolveUri(packageName),
              () => 'di${prefixes.length - 1}',
            ),
          ),
      };
  final services = StringBuffer();
  for (final registration in _servicesOf(app)) {
    final name = switch (registration.instanceName) {
      null => '',
      final name => 'instanceName: ${SmfNames.dartString(name)}',
    };
    services
      ..writeln('  (')
      ..writeln('    name: ${SmfNames.dartString('${registration.key}')},')
      ..writeln("    lifetime: '${registration.lifetime.name}',")
      ..writeln(
        '    resolve: () => '
        'locator.resolve<${typeOf(registration.type)}>($name),',
      )
      ..writeln('  ),');
  }
  final imports = [
    for (final MapEntry(key: uri, value: prefix) in prefixes.entries)
      "import '$uri' as $prefix;",
  ]..sort();
  return {
    registeredServicesFile: '''
// The services that the modules of the app register in its DI container,
// which the matrix of SMF writes from the data of the DI role of the app
// for the test of the role, di_role_test.dart.
${imports.join('\n')}

/// A service that the modules of the app register: its name, its lifetime,
/// and a function that resolves it with resolve() of the service locator.
typedef RegisteredService = ({
  String name,
  String lifetime,
  Object Function() resolve,
});

/// The services that the modules of the app register, in the order of
/// their registration.
final List<RegisteredService> registeredServices = [
$services];
''',
  };
}

/// The registrations of the DI role of [app], in the order of their
/// registration.
List<DiRegistration> _servicesOf(MatrixApp app) =>
    diRole.graphOf(diRole.hookInput(app.hook!)).ordered;

/// The name under which the listener of Firebase Analytics logs the
/// screen that [app] starts on: the full name of the route that the router
/// role chose for it, such as `home.home`, or `/` for the fallback start
/// screen of its app entry, when no route of its modules can start it.
String _startScreenOf(MatrixApp app) =>
    routerRole.startIn(routerRole.hookInput(app.hook!))?.fullName ?? '/';

/// Whether an app of the matrix has the module [id].
bool Function(MatrixApp app) _has(ModuleId id) =>
    (app) => app.modules.contains(id);
