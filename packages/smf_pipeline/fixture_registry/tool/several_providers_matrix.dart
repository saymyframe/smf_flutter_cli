import 'dart:convert';
import 'dart:io';
import 'dart:mirrors';

import 'package:fixture_registry/fixture_registry.dart';
import 'package:fixture_registry/matrix_app_tests.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// Generates the app with every module of the registry of several
/// providers (`severalProvidersModules`) in the directory given as the only
/// argument, analyzes it with Flutter and runs there the tests that the
/// modules of the CLI keep for the apps they are in, those of
/// `severalProvidersAppTests` in `lib/matrix_app_tests.dart`; see
/// `runMatrix`.
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
    for (final test in (await severalProvidersAppTests()).tests) {
      stdout.writeln(test.directory);
    }
    return;
  }
  if (arguments case ['--app-tests', '--json']) {
    final report = await appTestsReport(
      (await severalProvidersAppTests()).tests,
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
      selection: severalProvidersApps,
      appTests: await severalProvidersAppTests(),
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
