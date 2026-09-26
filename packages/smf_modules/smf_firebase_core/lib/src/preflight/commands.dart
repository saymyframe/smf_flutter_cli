import 'package:smf_contracts/lego.dart';

/// Why a preflight check could not install or set up what it found
/// missing; the pipeline reports [message].
final class PreflightSetupException implements Exception {
  /// Creates the exception with [message].
  const PreflightSetupException(this.message);

  /// What went wrong.
  final String message;

  @override
  String toString() => message;
}

/// A directory of its own for the files that a command may leave in its
/// working directory, such as the Firebase CLI's `firebase-debug.log`,
/// among the temporary files of the run, which the pipeline deletes.
Future<String> scratchDirectory(SmfEnvironment environment) async =>
    directoryOf(await environment.writeTempFile('.keep', ''));

/// The directory of the file at [path], with either separator.
String directoryOf(String path) {
  final end = path.lastIndexOf(RegExp(r'[/\\]'));
  return end <= 0 ? path.substring(0, end + 1) : path.substring(0, end);
}

/// How the command [command] ended with the exit code [code]: a negative
/// code is the signal that stopped it, as `dart:io` reports it.
String endOf(String command, int code) => code < 0
    ? '"$command" was stopped by signal ${-code}'
    : '"$command" exited with code $code';

/// Why the command [command] of [result] failed: how it ended, and the last
/// lines of what it wrote, if anything; see [outputTail].
String failureOf(String command, SmfProcessResult result) {
  final tail = outputTail(result);
  return '${endOf(command, result.exitCode)}'
      '${tail.isEmpty ? '.' : ':\n$tail'}';
}

/// The last lines of what the command of [result] wrote, the standard error
/// first, which say what went wrong.
String outputTail(SmfProcessResult result, {int lines = 20}) {
  final all = [
    for (final stream in [result.stderr, result.stdout])
      ...stream.trim().split('\n').where((line) => line.trim().isNotEmpty),
  ];
  return (all.length <= lines ? all : ['…', ...all.sublist(all.length - lines)])
      .join('\n');
}
