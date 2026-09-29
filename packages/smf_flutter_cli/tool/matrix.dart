import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:path/path.dart' as p;
import 'package:smf_contracts/core.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_app_tests.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:yaml/yaml.dart';

/// Generates the apps of the matrix of the modules of `smf create` in the
/// directory given as the first argument, analyzes each with Flutter and
/// runs the tests that the modules keep for the apps they are in; see
/// `runMatrix`. The tests, and the roles whose contract they check with
/// every provider, are those of `smfAppTests` in
/// `lib/matrix_app_tests.dart`, which the tests of the package check too. Any further argument names an app of the matrix, such as
/// `flutter_core (flutter_core)`, and only the apps named are checked.
///
/// With `--every-module` before the directory, it checks only the apps with
/// every module, one for each combination of the providers of the roles
/// that take one, such as one for each state manager; see
/// `everyModuleAppsOf`. CI checks these apps so, rather than by names that
/// change when a role gets another provider.
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
/// the apps of the matrix that each test that a package of modules keeps
/// applies to without the modules of that package, and the modules whose
/// ids each test uses.
///
/// With `--add-app-tests`, the directory of an app that `smf create`
/// generated outside the matrix and the directories of some of its
/// `MatrixAppTest`s, as `--app-tests` prints them or relative to the
/// working directory, it adds those tests to the app instead, with their
/// dev dependencies and the configuration that sets up their mocks, and
/// runs nothing else; see `addAppTestsTo`. So CI runs tests of the matrix
/// in apps of its own, such as on a device. Tests that run the start-up of
/// the app with `flutter test` need the mocks of every module of the app,
/// which the tests of each module declare, so those tests go into the app
/// too.
Future<void> main(List<String> arguments) async {
  if (arguments case ['--app-tests']) {
    for (final test in (await smfAppTests()).tests) {
      stdout.writeln(test.directory);
    }
    return;
  }
  if (arguments case ['--app-tests', '--json']) {
    final report = await appTestsReport(
      (await smfAppTests()).tests,
      modules: smfModules,
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
    exit(await _create(directory, name, options, withoutExternalSteps: true));
  }
  if (arguments
      case [
        '--create',
        final directory,
        final name,
        ...final options,
      ] when !directory.startsWith('-')) {
    exit(await _create(directory, name, options));
  }
  final everyModule = arguments.firstOrNull == '--every-module';
  final rest = everyModule ? arguments.skip(1).toList() : arguments;
  if (rest.isEmpty ||
      rest.first.startsWith('-') ||
      (everyModule && rest.length > 1)) {
    stderr
      ..writeln('Usage: dart run tool/matrix.dart <directory> [<app>...]')
      ..writeln('       dart run tool/matrix.dart --every-module <directory>')
      ..writeln(
        '       dart run tool/matrix.dart --create '
        '[--without-external-steps] <directory> <name> '
        '[<option of smf create>...]',
      )
      ..writeln('       dart run tool/matrix.dart --app-tests [--json]')
      ..writeln(
        '       dart run tool/matrix.dart --add-app-tests <app> '
        '<app tests>...',
      );
    exit(64);
  }
  final code = await runMatrix(
    smfModules,
    directory: rest.first,
    appTests: await smfAppTests(),
    only: rest.length > 1 ? rest.skip(1).toSet() : null,
    everyModule: everyModule,
  );
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  exit(code);
}

/// Generates the apps with every module in [directory] as [name], with the
/// [options] of `smf create`; returns the exit code.
Future<int> _create(
  String directory,
  String name,
  List<String> options, {
  bool withoutExternalSteps = false,
}) async {
  final code = await createEveryModuleApps(
    smfModules,
    directory: directory,
    name: name,
    withoutExternalSteps: withoutExternalSteps,
    options: options,
  );
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  return code;
}

/// Adds the `MatrixAppTest`s of [directories] to the app of `smf create`
/// in the directory [app]; returns the exit code.
Future<int> _addAppTests(String app, List<String> directories) async {
  final appTests = (await smfAppTests()).tests;
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
