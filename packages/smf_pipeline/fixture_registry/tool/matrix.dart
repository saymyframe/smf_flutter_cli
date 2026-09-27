import 'dart:io';
import 'dart:isolate';

import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// Generates the apps of the matrix of the fixture modules in the directory
/// given as the only argument, analyzes each with Flutter, so that every
/// feature of the module model compiles, and runs the tests of the apps in
/// `app_tests`; see `runMatrix`.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/matrix.dart <directory>');
    exit(64);
  }
  final library = await Isolate.resolvePackageUri(
    Uri.parse('package:fixture_registry/'),
  );
  final appTests =
      Directory.fromUri(library!).parent.uri.resolve('app_tests').toFilePath();
  final code = await runMatrix(
    fixtureModules(),
    directory: arguments.single,
    appTests: [
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
    ],
  );
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  exit(code);
}

/// Whether an app of the matrix has every module of [ids].
bool Function(MatrixApp app) _hasAll(Set<String> ids) =>
    (app) => ids.every((id) => app.modules.contains(ModuleId(id)));
