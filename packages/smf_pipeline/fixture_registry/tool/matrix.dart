import 'dart:io';
import 'dart:isolate';

import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// Generates the apps of the matrix of the fixture modules in the directory
/// given as the first argument, analyzes each with Flutter, so that every
/// feature of the module model compiles, and runs the tests of the apps in
/// `app_tests`; see `runMatrix`. Any further argument names an app of the
/// matrix, such as `fake_codegen`, and only the apps named are checked.
/// With `--every-module` before the directory, it checks only the apps with
/// every module, one for each combination of the providers of the roles
/// that take one; see `everyModuleAppsOf`.
///
/// With `--app-tests` alone, it prints the directory of each of its
/// `MatrixAppTest`s on a line of its own instead, for the test of the
/// repository that finds directories of app tests that no matrix tool
/// lists (`tools/app_tests_test.dart`).
Future<void> main(List<String> arguments) async {
  if (arguments case ['--app-tests']) {
    for (final test in await _appTests()) {
      stdout.writeln(test.directory);
    }
    return;
  }
  final everyModule = arguments.firstOrNull == '--every-module';
  final rest = everyModule ? arguments.skip(1).toList() : arguments;
  if (rest.isEmpty ||
      rest.first.startsWith('-') ||
      (everyModule && rest.length > 1)) {
    stderr
      ..writeln('Usage: dart run tool/matrix.dart <directory> [<app>...]')
      ..writeln('       dart run tool/matrix.dart --every-module <directory>')
      ..writeln('       dart run tool/matrix.dart --app-tests');
    exit(64);
  }
  final code = await runMatrix(
    fixtureModules(),
    directory: rest.first,
    only: rest.length > 1 ? rest.skip(1).toSet() : null,
    everyModule: everyModule,
    appTests: await _appTests(),
  );
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  exit(code);
}

/// The tests of the apps in the directory `app_tests` of this package.
Future<List<MatrixAppTest>> _appTests() async {
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:fixture_registry/'),
  );
  final appTests =
      Directory.fromUri(library!).parent.uri.resolve('app_tests').toFilePath();
  return [
    // The listeners of the screen under go_router, with a main navigation
    // for the destinations of the two fixture features.
    MatrixAppTest(
      '$appTests/go_router_screens',
      appliesTo: _hasAll(const {
        'go_router',
        'bottom_tabs',
        'fake_feature',
        'fake_second',
        'fake_analytics',
      }),
    ),
    // The listeners of the screen under the fixture router.
    MatrixAppTest(
      '$appTests/fake_router_screens',
      appliesTo: _hasAll(const {
        'fake_router',
        'fake_feature',
        'fake_analytics',
      }),
    ),
  ];
}

/// Whether an app of the matrix has every module of [ids].
bool Function(MatrixApp app) _hasAll(Set<String> ids) =>
    (app) => ids.every((id) => app.modules.contains(ModuleId(id)));
