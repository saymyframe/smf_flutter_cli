/// The tests that the matrix of CI adds to the apps of the modules of
/// `smf create`, for `tool/matrix.dart` and for the app of several
/// providers of the fixture registry. No library of the binary imports it.
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_settings/smf_settings.dart';
import 'package:smf_shared_preferences/smf_shared_preferences.dart';

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
  final settings = await appTestsDirectoryOf('smf_settings');
  final sharedPreferences = await appTestsDirectoryOf(
    'smf_shared_preferences',
  );
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
      // Once the first screen settled, it runs the probes of the tests that
      // go into the app with it, which go through the roles of the app,
      // such as the walk of its routes.
      MatrixAppTest(
        '$cli/start',
        appliesTo: (_) => true,
        readsStartProbes: true,
      ),
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
      // The last row of the settings screen of the module, which tells
      // what the app is: it opens the about dialog of Flutter with the name
      // of the app, and the dialog the licenses of its packages.
      MatrixAppTest('$settings/settings', appliesTo: _has(SettingsModule.id)),
      // The preferences of the module reach shared_preferences, and read
      // what it has when they are opened, lists in the form that each
      // platform returns them in. The mocks keep the platform side of the
      // package in memory, and the matrix sets them up for the tests of
      // every module of the app, since the start-up of the app opens the
      // preferences. Its probe opens the preferences again on a device,
      // where the platform side is the real one, and reads back what it
      // saved.
      MatrixAppTest(
        '$sharedPreferences/shared_preferences',
        appliesTo: _has(SharedPreferencesModule.id),
        devDependencies: const ['shared_preferences_platform_interface'],
        mocks: const MatrixMocks(
          'test/shared_preferences_mocks.dart',
          'mockSharedPreferences',
        ),
        startProbe: const MatrixStartProbe(
          'integration_test/shared_preferences/probe.dart',
          'probeSharedPreferences',
        ),
      ),
      // The services of the apps whose modules register some in the DI
      // container, whichever module provides it.
      await diRoleAppTest(),
      // The events of the apps with the events role, whichever module
      // provides it.
      await eventsRoleAppTest(),
      // The preferences of the apps with the preferences role, whichever
      // module provides it.
      await preferencesRoleAppTest(),
      // The routes of the apps with a router, whichever module provides
      // it: the test starts the app and goes to each location that needs
      // no values.
      await routerWalkAppTest(),
      // The settings screen of the apps with the settings screen role,
      // whichever module provides it: the route that the provider names
      // shows the screen, and the screen shows every entry that the
      // modules of the app give the role once, one below the other in the
      // order of the role.
      MatrixAppTest(
        '$cli/settings_screen_role',
        appliesTo: (app) => app.hook!.presentRoles.contains(settingsScreenRole),
        generatedFiles: _settingsOf,
        roles: {settingsScreenRole},
      ),
    ],
    // Each provider of the router role gets a test of the listeners of the
    // screen, the fixture registry tests the rest of the role, and each
    // provider of the DI role, of the events role, of the preferences role
    // and of the settings screen role gets the tests of its role.
    testedRoles: {
      routerRole,
      diRole,
      eventsRole,
      preferencesRole,
      settingsScreenRole,
    },
  );
}

/// The test of the events role that the CLI keeps in its
/// `app_tests/events_role`, for the apps with the role, whichever module
/// provides it, that [among] accepts, or all of them: once the start-up of
/// the app ran, every listener of a type gets each event of that type once,
/// in the order the events were fired; a listener of another type gets none
/// of them, and no error; an event fired before the stream of `on<T>()` is
/// listened to is not in it, even after `on<T>()` returned the stream; and a
/// cancelled subscription gets no more events.
///
/// The test knows only the role and fires events of its own through
/// `createCommunicationService()` of the role. The matrix of the fixtures
/// runs it too, only in the apps with every module, which run other tests
/// already.
Future<MatrixAppTest> eventsRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/events_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(eventsRole) &&
          (among?.call(app) ?? true),
      roles: {eventsRole},
    );

/// The test of the preferences role that the CLI keeps in its
/// `app_tests/preferences_role`, for the apps with the role, whichever
/// module provides it, that [among] accepts, or all of them: once the
/// start-up of the app opened the preferences, a value of each type is read
/// back as it was saved, and as `null` by the reads of the other types,
/// which do not throw; a key that was removed has no value; a write
/// replaces what its key had, a value of another type too; the preferences
/// keep a copy of a list that they are given, and a read returns a copy of
/// it; and the next start, `initPreferences()` again, reads what was saved
/// and nothing that was removed.
///
/// The test knows only the role, and writes keys of its own. Its probe,
/// `probePreferences()` of `integration_test/preferences_role/probe.dart`,
/// runs the checks of one run on a device for the start check, where the
/// platform side of the provider is the real one, and the test runs the
/// probe too. The matrix of the fixtures runs the test only in its apps
/// with every module, which run other tests already.
Future<MatrixAppTest> preferencesRoleAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/preferences_role',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(preferencesRole) &&
          (among?.call(app) ?? true),
      roles: {preferencesRole},
      startProbe: const MatrixStartProbe(
        'integration_test/preferences_role/probe.dart',
        'probePreferences',
      ),
    );

/// The test of the router role that the CLI keeps in its
/// `app_tests/router_walk`, for the apps with the role, whichever module
/// provides it, that [among] accepts, or all of them: it starts the app
/// with `main()` and goes to each location of the app that needs no
/// values, at most [routerWalkLimit], with `go()` of the navigator of the
/// role. Each must show the page named after its route on top of the
/// innermost navigator on the screen, and the screen of the route, without
/// an `ErrorWidget` on the screen or an error that Flutter reports.
///
/// The test knows only the role. The matrix writes the locations of each
/// app for it, from the routes of its router role, into [routerWalkFile],
/// next to the walk in `integration_test/router_walk/walk.dart`, whose
/// probe, `probeRoutes()`, the start check runs on a device. The matrix of
/// the fixtures runs it too, only in the apps with every module, which run
/// other tests already.
Future<MatrixAppTest> routerWalkAppTest({
  bool Function(MatrixApp app)? among,
}) async =>
    MatrixAppTest(
      '${await appTestsDirectoryOf('smf_flutter_cli')}/router_walk',
      appliesTo: (app) =>
          app.hook!.presentRoles.contains(routerRole) &&
          (among?.call(app) ?? true),
      generatedFiles: _walkedLocationsOf,
      roles: {routerRole},
      startProbe: const MatrixStartProbe(
        'integration_test/router_walk/walk.dart',
        'probeRoutes',
      ),
    );

/// The path in an app of the locations that the walk of the test of the
/// router role goes to, which the matrix writes: `walkedLocations`, the
/// locations of the routes that need no values, in the order of the routes
/// of the app ([RouterFacade.routes]), each with the full name of its route
/// ([FacadeRoute.fullName]), the location, created as `const` from its
/// class of the navigation of the role, and the type of the screen that the
/// route shows.
const routerWalkFile = 'integration_test/router_walk/locations.dart';

/// The most locations that the walk of the test of the router role goes
/// to, the first of the app.
const routerWalkLimit = 20;

/// The file at [routerWalkFile] of [app], an app of the matrix with the
/// router role, whose package is [packageName].
///
/// It imports the navigation of the role without a prefix, since the names
/// of its classes differ from those of the file, and the file of every
/// screen once, with a prefix of its own, `screen0`, `screen1`, ..., so
/// that no name clashes.
Map<String, String> _walkedLocationsOf(MatrixApp app, String packageName) {
  final routes = [
    for (final route
        in routerRole.facadeOf(routerRole.hookInput(app.hook!)).routes)
      if (!route.hasRequiredParams) route,
  ].take(routerWalkLimit);
  final screens = <String, String>{};
  final locations = StringBuffer();
  for (final route in routes) {
    final screen = route.route.screen;
    final prefix = screens.putIfAbsent(
      screen.import.resolveUri(packageName),
      () => 'screen${screens.length}',
    );
    locations
      ..writeln('  (')
      ..writeln('    route: ${SmfNames.dartString(route.fullName)},')
      ..writeln('    location: ${route.locationClass}(),')
      ..writeln('    screen: $prefix.${screen.className},')
      ..writeln('  ),');
  }
  final navigation = ImportRef.app(
    RouterRole.navigationFile.substring('lib/'.length),
  ).resolveUri(packageName);
  final imports = [
    "import '$navigation';",
    for (final MapEntry(key: uri, value: prefix) in screens.entries)
      "import '$uri' as $prefix;",
  ]..sort();
  return {
    routerWalkFile: '''
// The locations of the app that need no values, at most $routerWalkLimit,
// which the matrix of SMF writes from the data of the router role of the
// app for the walk of its routes, walk.dart.
${imports.join('\n')}

/// A location of the app that needs no values: the full name of its route,
/// the location, and the type of the screen that the route shows.
typedef WalkedLocation = ({String route, AppLocation location, Type screen});

/// The locations of the app that need no values, in the order of the
/// routes of the app.
const List<WalkedLocation> walkedLocations = [
$locations];
''',
  };
}

/// The path in an app of what the matrix writes for the tests of the
/// settings screen role that the CLI keeps in its
/// `app_tests/settings_screen_role`: `settingsLocation`, the location of the
/// route that the provider of the role names as the settings screen
/// ([SettingsScreenRole.screenIn]), created as `const` from its class of
/// the navigation of the router role, `settingsScreen`, the type of the
/// screen that the route shows, and `settingsEntries`, the types of the
/// widgets of the entries of the screen, in the order of the role
/// ([SettingsScreenRole.entriesIn]).
const settingsScreenFile = 'test/settings_screen_role/settings.dart';

/// The file at [settingsScreenFile] of [app], an app of the matrix with
/// the settings screen role, whose package is [packageName].
///
/// It imports the navigation of the router role without a prefix, since the
/// names of its classes differ from those of the file, the file of the
/// screen with the prefix `screen`, and the file of every entry once, with a
/// prefix of its own, `entry0`, `entry1`, ..., so that no name clashes.
/// Throws a [StateError] if the provider of the role names no route of its
/// own, which the rules of the role report in an app of the matrix.
Map<String, String> _settingsOf(MatrixApp app, String packageName) {
  final input = settingsScreenRole.hookInput(app.hook!);
  final route = settingsScreenRole.screenIn(input);
  if (route == null) {
    throw StateError(
      'No module of ${app.name} names a route of its own as the settings '
      'screen.',
    );
  }
  final screen = route.route.screen;
  final prefixes = {screen.import.resolveUri(packageName): 'screen'};
  final entries = StringBuffer();
  for (final entry in settingsScreenRole.entriesIn(input)) {
    final widget = entry.widget;
    // The template of the role rejects an entry whose widget is not in a
    // file of the app, so each has an import.
    final prefix = prefixes.putIfAbsent(
      widget.import!.resolveUri(packageName),
      () => 'entry${prefixes.length - 1}',
    );
    entries.writeln('  ${widget.codeWith(prefix)},');
  }
  final navigation = ImportRef.app(
    RouterRole.navigationFile.substring('lib/'.length),
  ).resolveUri(packageName);
  final imports = [
    "import '$navigation';",
    for (final MapEntry(key: uri, value: prefix) in prefixes.entries)
      "import '$uri' as $prefix;",
  ]..sort();
  return {
    settingsScreenFile: '''
// The settings screen of the app and its entries, which the matrix of SMF
// writes from the data of the settings screen role of the app for the
// tests of the role, settings_screen_test.dart and
// settings_entries_test.dart.
${imports.join('\n')}

/// The location of the route that shows the settings screen.
const AppLocation settingsLocation = ${route.locationClass}();

/// The type of the settings screen.
const Type settingsScreen = screen.${screen.className};

/// The types of the widgets of the entries of the settings screen, in the
/// order in which the screen shows them.
const List<Type> settingsEntries = [
$entries];
''',
  };
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
/// apps whose services have every lifetime. Its probe, `probeServices()` of
/// `integration_test/di_role/probe.dart`, resolves each service on a device
/// for the start check, a singleton and a lazy singleton twice, without
/// calling it or resetting the container.
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
      startProbe: const MatrixStartProbe(
        'integration_test/di_role/probe.dart',
        'probeServices',
      ),
    );

/// The path in an app of the services that its modules register, which the
/// matrix writes for the test of the DI role: `registeredServices`, the
/// services in the order of their registration ([DiGraph.ordered]), each
/// with its name, such as `FixtureZone "utc"`, its lifetime, such as
/// `lazySingleton`, and a function that resolves it with `resolve()` of the
/// service locator of the role, by its type and its instance name.
const registeredServicesFile =
    'integration_test/di_role/registered_services.dart';

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
