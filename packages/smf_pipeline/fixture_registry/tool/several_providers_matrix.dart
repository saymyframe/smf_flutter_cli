import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:mirrors';

import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_cli/matrix.dart';

import 'fixture_mocks.dart';

/// Generates the app with every module of the registry of several
/// providers (`severalProvidersModules`) in the directory given as the only
/// argument, analyzes it with Flutter and runs there the tests that the
/// modules of the CLI keep for the apps they are in; see `runMatrix`.
///
/// The app has the modules of the CLI that provide a role an app can have
/// several providers of, next to fixture providers of the same roles, whose
/// start-up and services go through platform channels that no test of the
/// modules of the CLI knows, and a fixture module whose start-up waits for
/// a timer. So the tests of a module pass in every app with the module,
/// whichever other providers of its roles, and whatever other start-up, the
/// app has.
///
/// With `--app-tests` alone, it prints the directory of each of its
/// `MatrixAppTest`s on a line of its own instead. With `--app-tests --json`,
/// it prints what the tests of the repository check of them
/// (`tools/app_tests_test.dart`), see `appTestsReport`.
Future<void> main(List<String> arguments) async {
  if (arguments case ['--app-tests']) {
    for (final test in await _appTests()) {
      stdout.writeln(test.directory);
    }
    return;
  }
  if (arguments case ['--app-tests', '--json']) {
    final report = await appTestsReport(
      await _appTests(),
      modules: severalProvidersModules(),
      packages: _packagesOf(severalProvidersModules()),
      apps: () async => (await matrixOf(severalProvidersModules())).apps,
    );
    stdout.writeln(jsonEncode(report));
    return;
  }
  if (arguments case [final directory] when !directory.startsWith('-')) {
    final code = await runMatrix(
      severalProvidersModules(),
      directory: directory,
      // Only its app with every module, which has each of its modules next
      // to the others; the matrices of the CLI and of the fixtures check
      // their modules in the other combinations.
      everyModule: true,
      appTests: MatrixAppTests(await _appTests()),
    );
    await Future.wait<void>([stdout.flush(), stderr.flush()]);
    exit(code);
  }
  stderr
    ..writeln('Usage: dart run tool/several_providers_matrix.dart <directory>')
    ..writeln(
      '       dart run tool/several_providers_matrix.dart --app-tests '
      '[--json]',
    );
  exit(64);
}

/// The tests of the apps that the modules keep in the directory
/// `app_tests` of their packages, as the matrix of the CLI registers them,
/// and the mocks of the fixture providers.
Future<List<MatrixAppTest>> _appTests() async {
  final firebaseCore = await _appTestsOf('smf_firebase_core');
  final crashlytics = await _appTestsOf('smf_firebase_crashlytics');
  final analytics = await _appTestsOf('smf_firebase_analytics');
  return [
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
    // The crash reporter of the module reaches Crashlytics, and the errors
    // that nothing catches reach it through the handlers that the start-up
    // of the app installs.
    MatrixAppTest(
      '$crashlytics/firebase_crashlytics',
      appliesTo: _has(FirebaseCrashlyticsModule.id),
      devDependencies: const ['firebase_crashlytics_platform_interface'],
      mocks: const MatrixMocks(
        'test/firebase_crashlytics_mocks.dart',
        'mockFirebaseCrashlytics',
      ),
    ),
    // The analytics service of the module reaches Firebase Analytics.
    MatrixAppTest(
      '$analytics/firebase_analytics',
      appliesTo: _has(FirebaseAnalyticsModule.id),
      mocks: const MatrixMocks(
        'test/firebase_analytics_mocks.dart',
        'mockFirebaseAnalytics',
      ),
    ),
    // The first screen of an app with a router is logged once, under the
    // name of the screen that the app starts on, whichever module provides
    // the router: a test of the router role too.
    MatrixAppTest(
      '$analytics/screen_views',
      appliesTo: (app) =>
          _has(FirebaseAnalyticsModule.id)(app) &&
          app.modules.any(_routers.contains),
      values: (app) => {'start_screen': _startScreenOf(app)},
      roles: {routerRole},
    ),
    // The platform side of the fixture providers of crash reporting and
    // analytics, which no test of the modules of the CLI knows.
    ...await fixtureMocks(),
  ];
}

/// The modules of the registry that provide the router role.
final Set<ModuleId> _routers = {
  for (final module in severalProvidersModules())
    if (module.descriptor.provides.contains(routerRole)) module.descriptor.id,
};

/// The name under which the listener of Firebase Analytics logs the
/// screen that [app] starts on: the full name of the route that the router
/// role chose for it, or `/` for the fallback start screen of its app
/// entry, when no route of its modules can start it.
String _startScreenOf(MatrixApp app) =>
    routerRole.startIn(routerRole.hookInput(app.hook!))?.fullName ?? '/';

/// The package that declares the class of each of [modules], such as
/// smf_firebase_core for firebase_core.
Map<ModuleId, String> _packagesOf(List<SmfModule> modules) => {
      for (final module in modules)
        module.descriptor.id:
            (reflectClass(module.runtimeType).owner! as LibraryMirror)
                .uri
                .pathSegments
                .first,
    };

/// Whether an app of the matrix has the module [id].
bool Function(MatrixApp app) _has(ModuleId id) =>
    (app) => app.modules.contains(id);

/// The directory `app_tests` of the package [package].
Future<String> _appTestsOf(String package) async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:$package/'),
  );
  if (library == null) throw StateError('No package $package.');
  return Directory.fromUri(library)
      .parent
      .uri
      .resolve('app_tests')
      .toFilePath();
}
