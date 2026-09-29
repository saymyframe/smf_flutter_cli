import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:mirrors';

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
/// `flutter_core (flutter_core)`, and only the apps named are checked.
///
/// With `--every-module` before the directory, it checks only the apps with
/// every module, one for each combination of the providers of the roles
/// that take one, such as one for each state manager; see
/// `everyModuleAppsOf`. CI checks these apps so, rather than by names that
/// change when a role gets another provider.
///
/// Of the apps with every module, a run takes a pairwise covering of the
/// combinations of the providers, or those of `--combinations 3-wise` or
/// `--combinations all`, or only one, by the name of its case, with
/// `--app`; and with `--shard <index>/<count>`, only its share of the apps
/// that it checks. These options come before the directory; see
/// `MatrixToolOptions`. With `--plan [--every-combination]` alone, it
/// prints the plan of the jobs of CI that check the matrix and build,
/// archive and start its apps, one app or shard for each job; see
/// `matrixPlanOf`.
///
/// With `--create`, a directory and a name, it generates the apps with
/// every module in the directory instead, without checking them, each as
/// the name followed by the providers that set it apart, such as
/// `start_app` and `start_app_riverpod`; see `createEveryModuleApps`. With
/// `--without-external-steps` after `--create`, it leaves out the modules
/// whose steps need an external service, such as a network account, so the
/// apps start without it. Any further argument is an option of
/// `smf create`, such as `--org com.example`. CI builds these apps for
/// Android and iOS and starts them on devices, and a second provider of a
/// role gets its own app there without a change of CI.
///
/// With `--app-tests` alone, it prints the directory of each of its
/// `MatrixAppTest`s on a line of its own instead. With `--app-tests --json`,
/// it prints what the tests of the repository check of them
/// (`tools/app_tests_test.dart`), see `appTestsReport`: their directories,
/// and the apps of the matrix that each test that a package of modules keeps
/// applies to without the modules of that package.
///
/// With `--add-app-tests`, the directory of an app that `smf create`
/// generated outside the matrix and the directories of some of its
/// `MatrixAppTest`s, as `--app-tests` prints them or relative to the
/// working directory, it adds those tests to the app instead, with their
/// dev dependencies, and runs nothing else; see `addAppTestsTo`. So CI
/// runs tests of the matrix in apps of its own, such as on a device.
Future<void> main(List<String> given) async {
  if (given case ['--plan', ...final options]) {
    exit(await printMatrixPlan(smfModules, options, native: appEntryRole));
  }
  final choice = MatrixToolOptions.parse(given);
  if (choice.problem case final problem?) _usage(problem);
  final arguments = choice.arguments;
  if (arguments case ['--app-tests']) {
    for (final test in await _appTests()) {
      stdout.writeln(test.directory);
    }
    return;
  }
  if (arguments case ['--app-tests', '--json']) {
    final report = await appTestsReport(
      await _appTests(),
      packages: _packagesOf(smfModules),
      apps: () async => (await matrixOf(smfModules)).apps,
    );
    stdout.writeln(jsonEncode(report));
    return;
  }
  if (arguments case ['--add-app-tests', final app, ...final directories]
      when directories.isNotEmpty) {
    exit(await _addAppTests(app, directories));
  }
  if (arguments
      case [
        '--create',
        '--without-external-steps',
        final directory,
        final name,
        ...final options,
      ]) {
    exit(
      await _create(
        directory,
        name,
        options,
        choice.selection,
        withoutExternalSteps: true,
      ),
    );
  }
  if (arguments
      case [
        '--create',
        final directory,
        final name,
        ...final options,
      ] when !directory.startsWith('-')) {
    exit(await _create(directory, name, options, choice.selection));
  }
  final everyModule = arguments.firstOrNull == '--every-module';
  final rest = everyModule ? arguments.skip(1).toList() : arguments;
  if (rest.isEmpty ||
      rest.first.startsWith('-') ||
      (everyModule && rest.length > 1)) {
    _usage();
  }
  final code = await runMatrix(
    smfModules,
    directory: rest.first,
    appTests: MatrixAppTests(
      await _appTests(),
      // Each provider of the router role gets a test of the listeners of
      // the screen; the fixture registry tests the rest of the role.
      testedRoles: {routerRole},
    ),
    only: rest.length > 1 ? rest.skip(1).toSet() : null,
    everyModule: everyModule,
    everyModuleApps: choice.selection,
    shard: choice.shard,
  );
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  exit(code);
}

/// Prints the usage, after [problem] if there is one, and exits with 64.
Never _usage([String? problem]) {
  if (problem != null) stderr.writeln(problem);
  stderr
    ..writeln(
      'Usage: dart run tool/matrix.dart [--combinations <c>] '
      '[--shard <i>/<n>] <directory> [<app>...]',
    )
    ..writeln(
      '       dart run tool/matrix.dart --every-module '
      '[--combinations <c> | --app <name>] [--shard <i>/<n>] <directory>',
    )
    ..writeln(
      '       dart run tool/matrix.dart --create '
      '[--without-external-steps] [--combinations <c> | --app <name>] '
      '<directory> <name> [<option of smf create>...]',
    )
    ..writeln('       dart run tool/matrix.dart --plan [--every-combination]')
    ..writeln('       dart run tool/matrix.dart --app-tests [--json]')
    ..writeln(
      '       dart run tool/matrix.dart --add-app-tests <app> '
      '<app tests>...',
    )
    ..writeln(
      '<c>: pairwise (by default), 3-wise or all, the combinations of the '
      'providers that the apps with every module cover.',
    );
  exit(64);
}

/// Generates the apps with every module of [selection] in [directory] as
/// [name], with the [options] of `smf create`; returns the exit code.
Future<int> _create(
  String directory,
  String name,
  List<String> options,
  EveryModuleSelection selection, {
  bool withoutExternalSteps = false,
}) async {
  final code = await createEveryModuleApps(
    smfModules,
    directory: directory,
    name: name,
    withoutExternalSteps: withoutExternalSteps,
    options: options,
    selection: selection,
  );
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  return code;
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
    // The analytics service of the module reaches Firebase Analytics. The
    // test leaves out the other analytics services that the app may have.
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

/// The package that declares the class of each of [modules], such as
/// smf_home_flutter for home.
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
