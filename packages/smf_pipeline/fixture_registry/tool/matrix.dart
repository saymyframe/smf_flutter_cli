import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:mirrors';

import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// Generates the apps of the matrix of the fixture modules in the directory
/// given as the first argument, analyzes each with Flutter, so that every
/// feature of the module model compiles, and runs the tests of the apps in
/// `app_tests`; see `runMatrix`. Any further argument names an app of the
/// matrix, such as `fake_codegen`, and only the apps named are checked.
///
/// With `--app-tests` alone, it prints the directory of each of its
/// `MatrixAppTest`s on a line of its own instead. With `--app-tests --json`,
/// it prints what the tests of the repository check of them
/// (`tools/app_tests_test.dart`), see `appTestsReport`: their directories,
/// and the apps of the matrix that each test that a package of modules keeps
/// applies to without the modules of that package.
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
      packages: _packagesOf(fixtureModules()),
      apps: () async => (await matrixOf(fixtureModules())).apps,
    );
    stdout.writeln(jsonEncode(report));
    return;
  }
  if (arguments.isEmpty || arguments.first.startsWith('-')) {
    stderr
      ..writeln('Usage: dart run tool/matrix.dart <directory> [<app>...]')
      ..writeln('       dart run tool/matrix.dart --app-tests [--json]');
    exit(64);
  }
  final code = await runMatrix(
    fixtureModules(),
    directory: arguments.first,
    only: arguments.length > 1 ? arguments.skip(1).toSet() : null,
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

/// The package that declares the class of each of [modules], such as
/// fake_infra for fake_analytics.
Map<ModuleId, String> _packagesOf(List<SmfModule> modules) => {
      for (final module in modules)
        module.descriptor.id:
            (reflectClass(module.runtimeType).owner! as LibraryMirror)
                .uri
                .pathSegments
                .first,
    };

/// Whether an app of the matrix has every module of [ids].
bool Function(MatrixApp app) _hasAll(Set<String> ids) =>
    (app) => ids.every((id) => app.modules.contains(ModuleId(id)));
