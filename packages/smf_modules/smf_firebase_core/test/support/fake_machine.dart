import 'dart:async';

import 'package:smf_contracts/lego.dart';

/// A command that a check ran.
final class Call {
  /// Creates the record of a command.
  const Call(
    this.executable,
    this.arguments, {
    this.workingDirectory,
    this.environment = const {},
    this.interactive = false,
  });

  /// The absolute path of the executable.
  final String executable;

  /// The arguments.
  final List<String> arguments;

  /// Where it ran, if the caller said.
  final String? workingDirectory;

  /// The environment variables that the caller set.
  final Map<String, String> environment;

  /// Whether it ran with the terminal attached.
  final bool interactive;

  /// The command as a line, such as `/bin/firebase login:list --json`.
  String get line => [executable, ...arguments].join(' ');

  @override
  String toString() => line;
}

/// What a command does on the fake machine: its result, or, for a command
/// with the terminal attached, its exit code in [SmfProcessResult.exitCode].
typedef Reply = FutureOr<SmfProcessResult> Function(Call call);

/// A machine for the tests of the checks, which implements every seam of
/// [SmfEnvironment] in memory.
///
/// The executables on its `PATH` are [executables], by name, which a reply
/// may change, as an installation does. Every command runs the reply given
/// to the constructor, which succeeds without output by default; the lines
/// of its output go to the `onOutput` of the caller, those of the standard
/// output first. The confirmations given to it answer the yes-or-no
/// questions in order. It records the commands, the questions, what was
/// reported and the temporary files.
final class FakeMachine implements SmfEnvironment {
  /// Creates the machine.
  FakeMachine({
    this.operatingSystem = HostOperatingSystem.macos,
    Map<String, String> executables = const {},
    Reply? reply,
    List<bool> confirmations = const [],
  })  : executables = {...executables},
        _reply = reply ?? ((_) => const SmfProcessResult(exitCode: 0)),
        _confirmations = [...confirmations];

  @override
  final HostOperatingSystem operatingSystem;

  /// The absolute path of each executable on the `PATH`, by name.
  final Map<String, String> executables;

  final Reply _reply;
  final List<bool> _confirmations;

  /// The commands that ran, in order.
  final List<Call> calls = [];

  /// The yes-or-no questions that were asked, in order.
  final List<String> questions = [];

  /// What was reported, each line prefixed with its kind, such as
  /// `warn: …` or `progress: …`.
  final List<String> reports = [];

  /// The temporary files by path, with their contents.
  final Map<String, String> tempFiles = {};

  @override
  bool get interactive => true;

  @override
  bool get skipExternalSetup => false;

  @override
  SmfProcessRunner get processRunner => _Runner(this);

  @override
  SmfPrompter get prompter => _Prompter(this);

  @override
  SmfLogger get logger => _Logger(this);

  @override
  Future<String?> findExecutable(String name) async => executables[name];

  @override
  Future<String> writeTempFile(String name, String contents) async {
    final path = '/tmp/smf/file_${tempFiles.length}/$name';
    tempFiles[path] = contents;
    return path;
  }
}

final class _Runner implements SmfProcessRunner {
  const _Runner(this._machine);

  final FakeMachine _machine;

  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
  }) async {
    final call = Call(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
    );
    _machine.calls.add(call);
    final result = await _machine._reply(call);
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
    final call = Call(
      executable,
      arguments,
      workingDirectory: workingDirectory,
      environment: environment,
      interactive: true,
    );
    _machine.calls.add(call);
    return (await _machine._reply(call)).exitCode;
  }
}

final class _Prompter implements SmfPrompter {
  const _Prompter(this._machine);

  final FakeMachine _machine;

  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) async {
    _machine.questions.add(message);
    if (_machine._confirmations.isEmpty) {
      throw StateError('Unexpected question: $message');
    }
    return _machine._confirmations.removeAt(0);
  }

  @override
  Future<String> input(String message, {String? defaultValue}) =>
      throw StateError('Unexpected question: $message');

  @override
  Future<T> select<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    T? defaultValue,
  }) =>
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
  const _Logger(this._machine);

  final FakeMachine _machine;

  List<String> get _reports => _machine.reports;

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
