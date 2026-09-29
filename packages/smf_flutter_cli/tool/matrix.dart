import 'dart:io';
import 'dart:isolate';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';
import 'package:smf_firebase_crashlytics/smf_firebase_crashlytics.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';

/// Generates the apps of the matrix of the modules of `smf create` in the
/// directory given as the first argument, analyzes each with Flutter and
/// runs the tests that the modules keep for the apps they are in; see
/// `runMatrix`. Any further argument names an app of the matrix, such as
/// `every module (bloc)`, and only the apps named are checked.
Future<void> main(List<String> arguments) async {
  if (arguments.isEmpty) {
    stderr.writeln('Usage: dart run tool/matrix.dart <directory> [<app>...]');
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
  final firebaseCore = await _appTestsOf('smf_firebase_core');
  final crashlytics = await _appTestsOf('smf_firebase_crashlytics');
  final analytics = await _appTestsOf('smf_firebase_analytics');
  return [
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
