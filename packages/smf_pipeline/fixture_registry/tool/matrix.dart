import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:fixture_registry/fixture_registry.dart';
import 'package:fixture_registry/matrix_app_tests.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// Generates the apps of the matrix of the fixture modules in the directory
/// given as the first argument, analyzes each with Flutter, so that every
/// feature of the module model compiles, and runs the tests of the apps in
/// `app_tests`, those of `fixtureAppTests` in `lib/matrix_app_tests.dart`;
/// see `runMatrix`. Any further argument names an app of the matrix, such
/// as `fake_codegen`, and only the apps named are checked. With
/// `--every-module` before the directory, it checks only the apps with
/// every module, one for each combination of the providers of the roles
/// that take one; see `everyModuleAppsOf`. Of those, a run takes a pairwise
/// covering of the combinations, or those of `--combinations 3-wise` or
/// `--combinations all`, or only one, by the name of its case, with `--app`
/// after `--every-module`; and with `--shard <index>/<count>`, only its
/// share of the apps that it checks. These options come before the
/// directory; see `MatrixToolOptions`. With `--plan [--every-combination]`
/// alone, it prints the plan of the jobs of CI that check the matrix, one
/// shard for each job; see `matrixPlanOf`.
///
/// The tests of the router role and of the layout role apply to the apps
/// of every module that provides the role, and the run fails when a
/// provider has apps that none of them applies to.
///
/// With `--app-tests` alone, it prints the directory of each of its
/// `MatrixAppTest`s on a line of its own instead. With `--app-tests --json`,
/// it prints what the tests of the repository check of them
/// (`tools/app_tests_test.dart`), see `appTestsReport`: their directories,
/// the apps of the matrix that each test that a package of modules keeps
/// applies to without the modules of that package, and the modules whose
/// ids each test uses.
Future<void> main(List<String> given) async {
  if (given case ['--plan', ...final options]) {
    exit(await printMatrixPlan(fixtureModules(), options));
  }
  final choice = MatrixToolOptions.parse(given);
  if (choice.problem case final problem?) _usage(problem);
  final arguments = choice.arguments;
  if (arguments case ['--app-tests']) {
    for (final test in (await fixtureAppTests()).tests) {
      stdout.writeln(test.directory);
    }
    return;
  }
  if (arguments case ['--app-tests', '--json']) {
    final report = await appTestsReport(
      (await fixtureAppTests()).tests,
      packages: _packagesOf(fixtureModules()),
      apps: () async => (await matrixOf(fixtureModules())).apps,
    );
    stdout.writeln(jsonEncode(report));
    return;
  }
  final everyModule = arguments.firstOrNull == '--every-module';
  final rest = everyModule ? arguments.skip(1).toList() : arguments;
  if (rest.isEmpty ||
      rest.first.startsWith('-') ||
      (everyModule && rest.length > 1)) {
    _usage();
  }
  final code = await runMatrix(
    fixtureModules(),
    directory: rest.first,
    only: rest.length > 1 ? rest.skip(1).toSet() : null,
    everyModule: everyModule,
    everyModuleApps: choice.selection,
    shard: choice.shard,
    appTests: await fixtureAppTests(),
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
    ..writeln('       dart run tool/matrix.dart --plan [--every-combination]')
    ..writeln('       dart run tool/matrix.dart --app-tests [--json]')
    ..writeln(
      '<c>: pairwise (by default), 3-wise or all, the combinations of the '
      'providers that the apps with every module cover.',
    );
  exit(64);
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
