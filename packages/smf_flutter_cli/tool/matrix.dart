import 'dart:io';

import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';

/// Generates the apps of the matrix of the modules of `smf create` in the
/// directory given as the only argument, and analyzes each with Flutter; see
/// `runMatrix`.
Future<void> main(List<String> arguments) async {
  if (arguments.length != 1) {
    stderr.writeln('Usage: dart run tool/matrix.dart <directory>');
    exit(64);
  }
  final code = await runMatrix(smfModules, directory: arguments.single);
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  exit(code);
}
