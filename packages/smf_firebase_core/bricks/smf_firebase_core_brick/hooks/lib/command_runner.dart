import 'dart:io';

import 'package:mason/mason.dart';

class CommandRunner {
  static Future<ProcessResult> run(
    String command,
    List<String> args, {
    required Logger logger,
    bool throwOnError = true,
    String? workingDirectory,
    bool runInShell = false,
  }) async {
    final commandString = _buildCommandString(command, args);
    logger.detail('🔄 Running: $commandString');

    final result = await Process.run(
      command,
      args,
      runInShell: runInShell,
      workingDirectory: workingDirectory,
    );

    _logResult(logger, result, commandString);

    if (throwOnError) {
      _throwIfProcessFailed(result, command, args);
    }

    return result;
  }

  static String _buildCommandString(String command, List<String> args) {
    return '$command ${args.join(' ')}';
  }

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
        executable, arguments, errorMessage, result.exitCode);
  }
}
