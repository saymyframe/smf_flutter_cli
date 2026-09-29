import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:smf_contracts/core.dart';
import 'package:smf_flutter_cli/src/io/interruption.dart';

/// Runs external commands on this machine with `dart:io`.
///
/// On Windows, a batch file such as `flutter.bat` starts without a shell:
/// Windows runs it with `cmd.exe` itself, and Dart quotes a path with
/// spaces, so the pipeline never needs `runInShell`. `cmd.exe` reads some
/// characters of the command line as its own, though, so neither a batch
/// file nor a command in a shell gets an argument with them; see
/// `batchArgumentProblem`.
///
/// A command that runs past the timeout of [run] is stopped with the
/// processes that it started, such as the `node` that `cmd.exe` starts for
/// the `firebase.cmd` of npm: on Windows with `taskkill /t /f`, elsewhere
/// with `SIGTERM` to it and then to the processes that `ps` lists under it,
/// and with `SIGKILL` to them all, in the same order, if the command is
/// still there after [stopGrace]. A process that escaped them and keeps the
/// output of the command open is not waited for longer than [stopGrace].
final class IoProcessRunner implements SmfProcessRunner {
  /// Creates the runner of a run, which stops its commands when the run is
  /// interrupted.
  ///
  /// [isWindows] is whether the machine runs Windows, and [ps] the command
  /// that lists the processes elsewhere, which tests may set.
  IoProcessRunner(this._interruption, {bool? isWindows, String ps = 'ps'})
      : _isWindows = isWindows ?? io.Platform.isWindows,
        _ps = ps;

  final Interruption _interruption;
  final bool _isWindows;
  final String _ps;

  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
    Duration? timeout,
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
    final stdout = _Output(process.stdout, onOutput);
    final stderr = _Output(process.stderr, onOutput);
    var timedOut = false;
    final exitCode = await (timeout == null
        ? process.exitCode
        : process.exitCode.timeout(
            timeout,
            onTimeout: () {
              timedOut = true;
              return _stop(process);
            },
          ));
    // Once the command is stopped, a process that it started may still hold
    // its output, both streams at once.
    final limit = timedOut ? stopGrace : null;
    final output = await Future.wait([stdout.text(limit), stderr.text(limit)]);
    final result = SmfProcessResult(
      exitCode: exitCode,
      stdout: output.first,
      stderr: output.last,
      timedOut: timedOut,
    );
    _interruption.throwIfInterrupted();
    return result;
  }

  /// How long a stopped command has to end, and its output to close, before
  /// the runner gives up on them.
  static const stopGrace = Duration(seconds: 2);

  /// Stops [process], which ran past its timeout, with the processes that
  /// it started, and returns its exit code.
  ///
  /// On Windows, `taskkill /t /f` ends the tree of the process, or else the
  /// process is ended alone. Elsewhere, the process gets `SIGTERM`, and then
  /// the processes that [_descendantsOf] found under it. Whatever is still
  /// there after [stopGrace] gets `SIGKILL`, the process first again; on
  /// Windows, which has no signals, that ends the process.
  ///
  /// The process gets each signal before the processes that it started, so
  /// that it cannot go on once they end: a shell that waits for them would
  /// end on its own, with the code 0 of `wait`, or run its next command.
  Future<int> _stop(io.Process process) async {
    var started = const <int>[];
    if (_isWindows) {
      try {
        await io.Process.run(
          'taskkill',
          ['/pid', '${process.pid}', '/t', '/f'],
        );
      } on Object {
        process.kill();
      }
    } else {
      // Listed before the process gets the signal: once it ends, `ps` lists
      // what it started under another process.
      started = await _descendantsOf(process.pid);
      process.kill();
      started.forEach(io.Process.killPid);
    }
    return process.exitCode.timeout(
      stopGrace,
      onTimeout: () {
        process.kill(io.ProcessSignal.sigkill);
        for (final pid in started) {
          io.Process.killPid(pid, io.ProcessSignal.sigkill);
        }
        return process.exitCode;
      },
    );
  }

  /// The processes that the process [pid] started, and theirs, as
  /// `ps -A -o pid= -o ppid=` lists them on macOS and Linux; none if `ps`
  /// cannot start or lists none, as one that does not know the options
  /// does.
  Future<List<int>> _descendantsOf(int pid) async {
    final io.ProcessResult result;
    try {
      result = await io.Process.run(_ps, ['-A', '-o', 'pid=', '-o', 'ppid=']);
    } on Object {
      return const [];
    }
    final children = <int, List<int>>{};
    for (final line in _processLine.allMatches('${result.stdout}')) {
      (children[int.parse(line[2]!)] ??= []).add(int.parse(line[1]!));
    }
    final found = <int>{};
    final waiting = [pid];
    while (waiting.isNotEmpty) {
      for (final child in children[waiting.removeLast()] ?? const <int>[]) {
        if (found.add(child)) waiting.add(child);
      }
    }
    return found.toList();
  }

  /// A line of `ps` with the id of a process and the id of its parent.
  static final RegExp _processLine = RegExp(
    r'^[ \t]*(\d+)[ \t]+(\d+)[ \t]*\r?$',
    multiLine: true,
  );

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
}

/// One stream of the output of a command, read as text from the start,
/// with its lines for the callback of [SmfProcessRunner.run] as they come.
final class _Output {
  _Output(Stream<List<int>> stream, void Function(String line)? onOutput)
      : _lines = _Lines(onOutput) {
    _subscription =
        stream.transform(const Utf8Decoder(allowMalformed: true)).listen(
      (chunk) {
        _text.write(chunk);
        _lines.add(chunk);
      },
      onDone: () {
        _lines.flush();
        _done.complete();
      },
      onError: _done.completeError,
      cancelOnError: true,
    );
  }

  final _text = StringBuffer();
  final _Lines _lines;
  final _done = Completer<void>();
  late final StreamSubscription<String> _subscription;

  /// The text of the stream once it ends, or, with [limit], what came until
  /// then if it has not ended by then.
  Future<String> text([Duration? limit]) async {
    if (limit == null) {
      await _done.future;
    } else {
      await _done.future.timeout(
        limit,
        onTimeout: () async {
          await _subscription.cancel();
          _lines.flush();
        },
      );
    }
    return _text.toString();
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
