import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';
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
    appTests: await _appTests(),
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
    // The crash reporter of the module reaches Crashlytics, and the errors
    // that nothing catches reach it through the handlers that the start-up
    // of the app installs. The tests look only at what reaches Crashlytics,
    // not at the other crash reporters that the app may have.
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
    // The first screen of an app with a router is logged once. Of the
    // modules of the CLI, only home has a start screen, its route
    // home.home; an app without it starts on the fallback start screen at
    // `/`. A module of the CLI with another start screen goes here too.
    MatrixAppTest(
      '$analytics/screen_views',
      appliesTo: (app) =>
          _has(FirebaseAnalyticsModule.id)(app) &&
          app.modules.any(
            (id) => _moduleOf(id).descriptor.provides.contains(routerRole),
          ),
      values: (app) => {
        'start_screen': app.modules.contains(HomeModule.id) ? 'home.home' : '/',
      },
    ),
  ];
}

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
