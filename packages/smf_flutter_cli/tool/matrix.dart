import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:yaml/yaml.dart';

/// Generates the apps of the matrix of the modules of `smf create` in the
/// directory given as the first argument, analyzes each with Flutter and
/// runs the tests that the modules keep for the apps they are in; see
/// `runMatrix`. Any further argument names an app of the matrix, such as
/// `every module (bloc)`, and only the apps named are checked.
///
/// With `--app-tests` alone, it prints the directory of each of its
/// `MatrixAppTest`s on a line of its own instead, for the test of the
/// repository that finds directories of app tests that no matrix tool
/// lists (`tools/app_tests_test.dart`).
///
/// With `--add-app-tests`, the directory of an app that `smf create`
/// generated outside the matrix and the directories of some of its
/// `MatrixAppTest`s, as `--app-tests` prints them or relative to the
/// working directory, it adds those tests to the app instead, with their
/// dev dependencies, and runs nothing else; see `addAppTestsTo`. So CI
/// runs tests of the matrix in apps of its own, such as on a device.
Future<void> main(List<String> arguments) async {
  if (arguments case ['--app-tests']) {
    for (final test in await _appTests()) {
      stdout.writeln(test.directory);
    }
    return;
  }
  if (arguments case ['--add-app-tests', final app, ...final directories]
      when directories.isNotEmpty) {
    exit(await _addAppTests(app, directories));
  }
  if (arguments.isEmpty || arguments.first.startsWith('-')) {
    stderr
      ..writeln('Usage: dart run tool/matrix.dart <directory> [<app>...]')
      ..writeln('       dart run tool/matrix.dart --app-tests')
      ..writeln(
        '       dart run tool/matrix.dart --add-app-tests <app> '
        '<app tests>...',
      );
    exit(64);
  }
  final code = await runMatrix(
    smfModules,
    directory: arguments.first,
    appTests: MatrixAppTests(
      await _appTests(),
      // Each provider of the router role gets a test of the listeners of
      // the screen; the fixture registry tests the rest of the role.
      testedRoles: {routerRole},
    ),
    only: arguments.length > 1 ? arguments.skip(1).toSet() : null,
  );
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  exit(code);
}

/// The tests of the apps that the modules keep in the directory
/// `app_tests` of their packages.
Future<List<MatrixAppTest>> _appTests() async {
  final cli = await _appTestsOf('smf_flutter_cli');
  final firebaseCore = await _appTestsOf('smf_firebase_core');
  final crashlytics = await _appTestsOf('smf_firebase_crashlytics');
  final analytics = await _appTestsOf('smf_firebase_analytics');
  return [
    // The app starts and shows its first screen: a check that CI builds as
    // the entry of the app and starts on an Android emulator and on an iOS
    // simulator with .github/scripts/start_app.sh, in the apps that it adds
    // it to with --add-app-tests. It knows no module, only main() of
    // lib/main.dart, which the app entry role puts into every app whichever
    // module provides it, so the CLI keeps it and it applies to every app.
    // In the apps of the matrix it is only analyzed, and flutter test runs
    // the tests that the modules put into each app.
    MatrixAppTest('$cli/start', appliesTo: (_) => true),
    // The start-up of the app initializes Firebase, with the options that
    // `flutterfire configure` would write, and the mocks of Firebase Core
    // for the tests of the other Firebase modules.
    MatrixAppTest(
      '$firebaseCore/firebase_core',
      appliesTo: _has(FirebaseCoreModule.id),
      devDependencies: const ['firebase_core_platform_interface'],
    ),
    // Uncaught errors and the crash reporter of the app reach Crashlytics.
    MatrixAppTest(
      '$crashlytics/firebase_crashlytics',
      appliesTo: _has(FirebaseCrashlyticsModule.id),
      devDependencies: const ['firebase_crashlytics_platform_interface'],
    ),
    // The analytics service of the app reaches Firebase Analytics.
    MatrixAppTest(
      '$analytics/firebase_analytics',
      appliesTo: _has(FirebaseAnalyticsModule.id),
    ),
    // The first screen of an app with a router is logged once, under the
    // name of the screen that the app starts on (see _startScreenOf),
    // whichever module provides the router, which calls the listener of the
    // screen of Firebase Analytics: a test of the router role too.
    MatrixAppTest(
      '$analytics/screen_views',
      appliesTo: (app) =>
          _has(FirebaseAnalyticsModule.id)(app) &&
          app.modules.any(
            (id) => _moduleOf(id).descriptor.provides.contains(routerRole),
          ),
      values: (app) => {'start_screen': _startScreenOf(app)},
      roles: {routerRole},
    ),
  ];
}

/// The name under which the listener of Firebase Analytics logs the
/// screen that [app] starts on: the full name of the route that the router
/// role chose for it, such as `home.home`, or `/` for the fallback start
/// screen of its app entry, when no route of its modules can start it.
String _startScreenOf(MatrixApp app) =>
    routerRole.startIn(routerRole.hookInput(app.hook!))?.fullName ?? '/';

/// Adds the `MatrixAppTest`s of [directories] to the app of `smf create`
/// in the directory [app]; returns the exit code.
Future<int> _addAppTests(String app, List<String> directories) async {
  final appTests = await _appTests();
  final tests = <MatrixAppTest>[];
  for (final directory in directories) {
    final test = appTests
        .where((test) => p.equals(test.directory, directory))
        .firstOrNull;
    if (test == null) {
      stderr.writeln(
        '$directory is the directory of no app test of this tool; '
        '--app-tests lists them.',
      );
      return 64;
    }
    tests.add(test);
  }
  final pubspec = File(p.join(app, 'pubspec.yaml')).readAsStringSync();
  final name = (loadYaml(pubspec) as YamlMap)['name'] as String;
  final (code, output) = await addAppTestsTo(
    GeneratedApp(name: name, path: p.absolute(app)),
    tests,
  );
  stdout.writeln(output.trim());
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  return code;
}

/// Whether an app of the matrix has the module [id].
bool Function(MatrixApp app) _has(ModuleId id) =>
    (app) => app.modules.contains(id);

SmfModule _moduleOf(ModuleId id) =>
    smfModules.singleWhere((module) => module.descriptor.id == id);

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
