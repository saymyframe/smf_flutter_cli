import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_cli/src/io/interruption.dart';

/// Runs external commands on this machine with `dart:io`.
///
/// On Windows, a batch file such as `flutter.bat` starts without a shell:
/// Windows runs it with `cmd.exe` itself, and Dart quotes a path with
/// spaces, so the pipeline never needs `runInShell`. `cmd.exe` reads some
/// characters of the command line as its own, though, so neither a batch
/// file nor a command in a shell gets an argument with them; see
/// `batchArgumentProblem`.
final class IoProcessRunner implements SmfProcessRunner {
  /// Creates the runner of a run, which stops its commands when the run is
  /// interrupted.
  ///
  /// [isWindows] is whether the machine runs Windows, which tests may set.
  IoProcessRunner(this._interruption, {bool? isWindows})
      : _isWindows = isWindows ?? io.Platform.isWindows;

  final Interruption _interruption;
  final bool _isWindows;

  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
  }) async {
    _interruption.throwIfInterrupted();
    _checkCommandLine(executable, arguments, runInShell: runInShell);
    final process = await io.Process.start(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      runInShell: runInShell,
    );
    _interruption.track(process);
    // The command gets no input, so one that reads it ends instead of
    // waiting; Process.run does the same.
    unawaited(process.stdin.close());
    final stdout = _read(process.stdout, onOutput);
    final stderr = _read(process.stderr, onOutput);
    final exitCode = await process.exitCode;
    final result = SmfProcessResult(
      exitCode: exitCode,
      stdout: await stdout,
      stderr: await stderr,
    );
    _interruption.throwIfInterrupted();
    return result;
  }

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) async {
    _interruption.throwIfInterrupted();
    _checkCommandLine(executable, arguments, runInShell: runInShell);
    return _interruption.whileForwarding(() async {
      final process = await io.Process.start(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: environment,
        runInShell: runInShell,
        mode: io.ProcessStartMode.inheritStdio,
      );
      return process.exitCode;
    });
  }

  /// Throws a [io.ProcessException] if `cmd.exe` would read the command
  /// line of [executable] on Windows, as it does for a batch file or with
  /// [runInShell], and the executable or an argument has characters that
  /// it reads as its own.
  void _checkCommandLine(
    String executable,
    List<String> arguments, {
    required bool runInShell,
  }) {
    if (!_isWindows || !(runInShell || isBatchFile(executable))) return;
    for (final text in [executable, ...arguments]) {
      if (batchArgumentProblem(text) case final problem?) {
        throw io.ProcessException(
          executable,
          arguments,
          '"$text" cannot go to cmd.exe safely: $problem.',
        );
      }
    }
  }

  /// Reads [stream] as text, which it returns, and gives [onOutput] its
  /// lines as they come.
  static Future<String> _read(
    Stream<List<int>> stream,
    void Function(String line)? onOutput,
  ) async {
    final text = StringBuffer();
    final lines = _Lines(onOutput);
    await for (final chunk
        in stream.transform(const Utf8Decoder(allowMalformed: true))) {
      text.write(chunk);
      lines.add(chunk);
    }
    lines.flush();
    return text.toString();
  }
}

/// Whether [executable] is a batch file of Windows, which `cmd.exe` runs.
bool isBatchFile(String executable) {
  final name = executable.toLowerCase();
  return name.endsWith('.bat') || name.endsWith('.cmd');
}

/// Why [text] cannot be a part of the command line of a batch file, or
/// `null` if it can.
///
/// `cmd.exe` reads `%` as the start of a variable, `^` as an escape, `&`,
/// `|`, `<` and `>` as the end of the command or a redirection when they are
/// outside quotes, and a `"` inside an argument ends its quotes; a line
/// break ends the command.
String? batchArgumentProblem(String text) {
  const special = {
    '%': 'cmd.exe would read "%" as the start of a variable',
    '^': 'cmd.exe would read "^" as an escape',
    '&': 'cmd.exe would read "&" as the end of the command',
    '|': 'cmd.exe would read "|" as a pipe',
    '<': 'cmd.exe would read "<" as a redirection',
    '>': 'cmd.exe would read ">" as a redirection',
    '"': 'cmd.exe would read the quote as the end of the quotes',
    '\n': 'a line break would end the command',
    '\r': 'a line break would end the command',
  };
  for (final MapEntry(key: character, value: problem) in special.entries) {
    if (text.contains(character)) return problem;
  }
  return null;
}

/// The lines of one stream of the output of a command, split at line breaks
/// and carriage returns, for the callback of [SmfProcessRunner.run].
final class _Lines {
  _Lines(this._onLine);

  final void Function(String line)? _onLine;
  final _partial = StringBuffer();

  void add(String chunk) {
    final onLine = _onLine;
    if (onLine == null) return;
    for (final character in chunk.split('')) {
      if (character == '\n' || character == '\r') {
        _emit(onLine);
      } else {
        _partial.write(character);
      }
    }
  }

  /// Gives the callback the last line, which has no line break.
  void flush() {
    if (_onLine case final onLine?) _emit(onLine);
  }

  void _emit(void Function(String line) onLine) {
    final line = _partial.toString().trimRight();
    _partial.clear();
    if (line.trim().isNotEmpty) onLine(line);
  }
}
