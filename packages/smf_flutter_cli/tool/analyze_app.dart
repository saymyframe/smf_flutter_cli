import 'dart:io';

import 'package:smf_flutter_cli/matrix.dart';

/// Analyzes the app in the directory given as its only argument, or in the
/// current directory without one, as the matrix analyzes its apps
/// (`analyzeApp`), and exits with the exit code of the analysis.
///
/// CI runs it for the apps that it analyzes outside a run of the matrix: the
/// apps of the CLI from pub.dev, and the app with every module that a job on
/// Windows generates as a user does. So they let pass what the apps of the
/// matrix let pass (`toleratingAnalysis`).
Future<void> main(List<String> arguments) async {
  if (arguments.length > 1 ||
      arguments.any((argument) => argument.startsWith('-'))) {
    stderr.writeln('Usage: dart tool/analyze_app.dart [<directory of app>]');
    exitCode = 64;
    return;
  }
  exitCode = await analyzeApp(
    arguments.isEmpty ? Directory.current.path : arguments.single,
  );
}
