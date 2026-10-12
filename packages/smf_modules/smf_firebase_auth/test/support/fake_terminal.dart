import 'dart:async';

import 'package:smf_contracts/smf_contracts.dart';

/// A command that a run of `smf create` ran.
final class Call {
  /// Creates the record of a command.
  const Call(this.executable, this.arguments, {this.interactive = false});

  /// The absolute path of the executable.
  final String executable;

  /// The arguments.
  final List<String> arguments;

  /// Whether it ran with the terminal attached.
  final bool interactive;

  /// The command as a line, such as `/bin/firebase --version`.
  String get line => [executable, ...arguments].join(' ');

  @override
  String toString() => line;
}

/// What a command does on the machine of a test: its result, or, for a
/// command with the terminal attached, its exit code in
/// [SmfProcessResult.exitCode].
typedef Reply = FutureOr<SmfProcessResult> Function(Call call);

/// The terminal and the processes of a machine on which a test runs
/// `smf create`, in memory.
///
/// Every command runs the reply given to the constructor, and the lines of
/// its output go to the `onOutput` of the caller, those of the standard
/// output first. The confirmations given to it answer the yes-or-no
/// questions in order, and a question with choices gets its default. It
/// records the commands, the questions and what was reported.
final class FakeTerminal {
  /// Creates the terminal.
  FakeTerminal({required Reply reply, List<bool> confirmations = const []})
      : _reply = reply,
        _confirmations = [...confirmations];

  final Reply _reply;
  final List<bool> _confirmations;

  /// The commands that ran, in order.
  final List<Call> calls = [];

  /// The yes-or-no questions that were asked, in order.
  final List<String> questions = [];

  /// The questions with choices that were asked, in order.
  final List<String> selections = [];

  /// What was reported, each line prefixed with its kind, such as
  /// `warn: …` or `progress: …`.
  final List<String> reports = [];

  /// The processes of the machine.
  SmfProcessRunner get processRunner => _Runner(this);

  /// The questions of the terminal.
  SmfPrompter get prompter => _Prompter(this);

  /// The output of the terminal.
  SmfLogger get logger => _Logger(reports);
}

final class _Runner implements SmfProcessRunner {
  const _Runner(this._terminal);

  final FakeTerminal _terminal;

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
    final call = Call(executable, arguments);
    _terminal.calls.add(call);
    final result = await _terminal._reply(call);
    if (onOutput != null) {
      for (final stream in [result.stdout, result.stderr]) {
        stream
            .split(RegExp('[\r\n]'))
            .where((line) => line.isNotEmpty)
            .forEach(onOutput);
      }
    }
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
    final call = Call(executable, arguments, interactive: true);
    _terminal.calls.add(call);
    return (await _terminal._reply(call)).exitCode;
  }
}

final class _Prompter implements SmfPrompter {
  const _Prompter(this._terminal);

  final FakeTerminal _terminal;

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) async {
    _terminal.questions.add(message);
    if (_terminal._confirmations.isEmpty) {
      throw StateError('Unexpected question: $message');
    }
    return _terminal._confirmations.removeAt(0);
  }

  @override
  Future<T> select<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    T? defaultValue,
  }) async {
    _terminal.selections.add(message);
    return defaultValue ?? choices.first;
  }

  @override
  Future<String> input(String message, {String? defaultValue}) =>
      throw StateError('Unexpected question: $message');

  @override
  Future<List<T>> multiSelect<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    List<T> defaultValues = const [],
  }) =>
      throw StateError('Unexpected question: $message');
}

final class _Logger implements SmfLogger {
  const _Logger(this._reports);

  final List<String> _reports;

  @override
  void info(String message) => _reports.add('info: $message');

  @override
  void detail(String message) => _reports.add('detail: $message');

  @override
  void warn(String message) => _reports.add('warn: $message');

  @override
  void error(String message) => _reports.add('error: $message');

  @override
  void success(String message) => _reports.add('success: $message');

  @override
  SmfProgress progress(String message) {
    _reports.add('progress: $message');
    return _Progress(_reports);
  }
}

final class _Progress implements SmfProgress {
  const _Progress(this._reports);

  final List<String> _reports;

  @override
  void update(String message) => _reports.add('update: $message');

  @override
  void complete([String? message]) => _reports.add('complete: $message');

  @override
  void fail([String? message]) => _reports.add('fail: $message');
}
