import 'dart:io';

import 'package:mason/mason.dart';

/// Runs shell commands and logs execution details and results.
class ShellRunner {
  /// Runs a command to completion and throws if the process fails.
  static Future<void> run(
    String command,
    List<String> args, {
    required Logger logger,
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    final commandString = _buildCommandString(command, args);
    logger.info('🔄 Run: $commandString');

    final result = await Process.run(
      command,
      args,
      runInShell: runInShell,
      workingDirectory: workingDirectory,
    );

    _logResult(logger, result, commandString);
    _throwIfProcessFailed(result, command, args);
  }

  /// Starts a process and awaits its exit code, throwing on non-zero status.
  static Future<void> start(
    String command,
    List<String> args, {
    required Logger logger,
    String? workingDirectory,
    bool runInShell = false,
    ProcessStartMode mode = ProcessStartMode.inheritStdio,
  }) async {
    final commandString = _buildCommandString(command, args);
    logger.info('🔄 Run: $commandString');

    final process = await Process.start(
      command,
      args,
      workingDirectory: workingDirectory,
      runInShell: runInShell,
      mode: mode,
    );

    final exitCode = await process.exitCode;
    final result = ProcessResult(
      process.pid,
      exitCode,
      '',
      '',
    );

    _logResult(logger, result, commandString);
    _throwIfProcessFailed(result, command, args);
  }

  /// Builds a human-readable command string for logging.
  static String _buildCommandString(String command, List<String> args) {
    return '$command ${args.join(' ')}';
  }

  /// Logs stdout, stderr and exit status of a finished process.
  static void _logResult(Logger logger, ProcessResult result, String command) {
    if (result.stdout.toString().isNotEmpty) {
      logger.detail('📤 stdout:\n${result.stdout}');
    }

    if (result.stderr.toString().isNotEmpty) {
      logger.detail('📥 stderr:\n${result.stderr}');
    }

    if (result.exitCode == 0) {
      logger.detail('✅ Command completed successfully');
    } else {
      logger.detail('❌ Command failed with exit code: ${result.exitCode}');
    }
  }

  /// Throws a [ProcessException] with captured output when exit code != 0.
  static void _throwIfProcessFailed(
    ProcessResult result,
    String executable,
    List<String> arguments,
  ) {
    if (result.exitCode == 0) return;

    final output = <String>[];
    final stdoutStr = result.stdout?.toString().trim();
    final stderrStr = result.stderr?.toString().trim();

    if (stdoutStr != null && stdoutStr.isNotEmpty) {
      output.add('stdout:\n$stdoutStr');
    }
    if (stderrStr != null && stderrStr.isNotEmpty) {
      output.add('stderr:\n$stderrStr');
    }

    final errorMessage = output.isNotEmpty
        ? output.join('\n')
        : 'Process failed with exit code ${result.exitCode}';

    throw ProcessException(
      executable,
      arguments,
      errorMessage,
      result.exitCode,
    );
  }
}
