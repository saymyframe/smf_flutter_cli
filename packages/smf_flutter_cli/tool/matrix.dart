import 'dart:io';
import 'dart:isolate';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';

/// Generates the apps of the matrix of the modules of `smf create` in the
/// directory given as the only argument, analyzes each with Flutter and
/// runs the tests that the modules keep for the apps they are in; see
/// `runMatrix`.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/matrix.dart <directory>');
    exit(64);
  }
  final code = await runMatrix(
    smfModules,
    directory: arguments.single,
    appTests: await _appTests(),
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
      appliesTo: _has('firebase_core'),
      devDependencies: const ['firebase_core_platform_interface'],
    ),
    // Uncaught errors and the crash reporter of the app reach Crashlytics.
    MatrixAppTest(
      '$crashlytics/firebase_crashlytics',
      appliesTo: _has('firebase_crashlytics'),
      devDependencies: const ['firebase_crashlytics_platform_interface'],
    ),
    // The analytics service of the app reaches Firebase Analytics.
    MatrixAppTest(
      '$analytics/firebase_analytics',
      appliesTo: _has('firebase_analytics'),
    ),
    // The first screen of an app with a router is logged once: the home
    // screen, or else the fallback start screen, as `/`.
    MatrixAppTest(
      '$analytics/screen_views',
      appliesTo: (app) =>
          _has('firebase_analytics')(app) &&
          app.modules.any(
            (id) => _moduleOf(id).descriptor.provides.contains(routerRole),
          ),
      values: (app) => {
        'start_screen':
            app.modules.contains(const ModuleId('home')) ? 'home.home' : '/',
      },
    ),
  ];
}

/// Whether an app of the matrix has the module [id].
bool Function(MatrixApp app) _has(String id) =>
    (app) => app.modules.contains(ModuleId(id));

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
