import 'dart:io';

import 'package:fixture_registry/fixture_registry.dart';
import 'package:smf_flutter_cli/matrix.dart';

/// Generates the apps of the matrix of the fixture modules in the directory
/// given as the only argument, and analyzes each with Flutter, so that every
/// feature of the module model compiles; see `runMatrix`.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/matrix.dart <directory>');
    exit(64);
  }
  final code = await runMatrix(fixtureModules(), directory: arguments.single);
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  exit(code);
}
