import 'package:smf_contracts/lego_core.dart';

/// The operating system the pipeline runs on.
enum HostOperatingSystem {
  /// macOS.
  macos,

  /// Linux.
  linux,

  /// Windows.
  windows,

  /// Any other system.
  other,
}

/// What a hook with side effects may use: the machine, the user, and
/// external commands.
///
/// [PreflightCheck]s and the `choose` hooks of roles receive it. The pipeline
/// implements it, and tests pass fakes, so hooks never touch `dart:io`
/// directly.
abstract interface class SmfEnvironment {
  /// Whether the user can answer prompts: there is a terminal and the run
  /// is not `--no-input`.
  bool get interactive;

  /// Whether the run skips setup outside the app, such as installing tools
  /// or logging in (`--skip-external-setup`); hooks print instructions
  /// instead.
  bool get skipExternalSetup;

  /// The operating system the pipeline runs on.
  HostOperatingSystem get operatingSystem;

  /// Runs external commands.
  SmfProcessRunner get processRunner;

  /// Asks the user; use only when [interactive].
  SmfPrompter get prompter;

  /// Reports progress and problems.
  SmfLogger get logger;

  /// Returns the absolute path of the executable [name] on the `PATH`, or
  /// `null` if it is not found.
  ///
  /// The search includes the directories of tools installed during the run
  /// (see [ToolInstall.binDirs]) and, on Windows, the usual extensions such
  /// as `.exe` and `.bat`. Once the preflight checks found the Flutter SDK,
  /// `flutter` and `dart` are the executables of that SDK, whatever else is
  /// on the `PATH`.
  ///
  /// The commands of [processRunner] get a `PATH` with the same directories
  /// unless a call sets its own.
  Future<String?> findExecutable(String name);

  /// Writes [contents] to a new temporary file whose name ends with [name],
  /// such as an install script, and returns its absolute path.
  ///
  /// The pipeline deletes the file at the end of the run. The file is not
  /// executable; run a script through its interpreter, such as `bash`.
  Future<String> writeTempFile(String name, String contents);
}

/// Thrown when the user cancels the run, such as with Ctrl-C.
///
/// [SmfPrompter] throws it when the user cancels a question, and
/// [SmfProcessRunner.run] when the user interrupts the run while a command
/// runs. Hooks let it through: the pipeline stops, deletes what it has
/// generated so far, and the CLI exits with code 130.
final class SmfCancelledException implements Exception {
  /// Creates the exception.
  const SmfCancelledException();

  @override
  String toString() => 'SmfCancelledException: the user cancelled the run.';
}

/// Asks the user questions in the terminal.
///
/// Every method throws an [SmfCancelledException] when the user cancels the
/// question instead of answering it, such as with Ctrl-C, or when the input
/// ends.
abstract interface class SmfPrompter {
  /// Asks a yes or no question.
  Future<bool> confirm(String message, {bool defaultValue = false});

  /// Asks for a line of text.
  Future<String> input(String message, {String? defaultValue});

  /// Asks the user to pick one of [choices], shown with [display].
  Future<T> select<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    T? defaultValue,
  });

  /// Asks the user to pick any number of [choices], shown with [display].
  Future<List<T>> multiSelect<T extends Object>(
    String message,
    List<T> choices, {
    String Function(T choice)? display,
    List<T> defaultValues = const [],
  });
}

/// The result of a command run by [SmfProcessRunner.run].
final class SmfProcessResult {
  /// Creates the result of a command that exited with [exitCode].
  const SmfProcessResult({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
  });

  /// The exit code of the command.
  final int exitCode;

  /// What the command wrote to its standard output.
  final String stdout;

  /// What the command wrote to its standard error.
  final String stderr;

  /// Whether the command exited with code 0.
  bool get succeeded => exitCode == 0;
}

/// Runs external commands.
///
/// The executable is always an absolute path, found with
/// [SmfEnvironment.findExecutable], so the result does not depend on how a
/// shell would resolve the name. On Windows it may be a batch file, such as
/// `flutter.bat`; the runner starts it the way the host needs.
///
/// Both methods throw if the command cannot start, as when the file is not
/// executable. The variables of `environment` are added to those of the
/// process running the pipeline.
abstract interface class SmfProcessRunner {
  /// Runs [executable] with [arguments] and captures its output.
  ///
  /// The command gets no input: its standard input is closed, so a command
  /// that would ask the user ends instead of waiting.
  ///
  /// [onOutput], if given, gets each line of the standard output and error
  /// of the command as it comes, such as a message that the command waits
  /// for something; the result has the whole output anyway. A carriage
  /// return ends a line too, since tools use it to rewrite their last line.
  ///
  /// Throws an [SmfCancelledException] when the user interrupts the run
  /// before or while the command runs, such as with Ctrl-C; the command is
  /// stopped then.
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
  });

  /// Runs [executable] with [arguments] attached to the terminal, so the
  /// command can ask the user, and returns its exit code.
  ///
  /// The command owns the terminal while it runs: Ctrl-C goes to it, and its
  /// exit code tells what happened, so the user can stop the command without
  /// cancelling the run.
  ///
  /// Throws an [SmfCancelledException] when the user interrupted the run
  /// before the command starts.
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  });
}

/// Reports progress and problems to the user.
abstract interface class SmfLogger {
  /// Reports a regular message.
  void info(String message);

  /// Reports a message shown only in verbose output.
  void detail(String message);

  /// Reports something that did not stop the run but needs attention.
  void warn(String message);

  /// Reports a failure.
  void error(String message);

  /// Reports a success.
  void success(String message);

  /// Starts a long-running task and returns its progress indicator.
  SmfProgress progress(String message);
}

/// The progress indicator of a long-running task.
abstract interface class SmfProgress {
  /// Replaces the message of the task.
  void update(String message);

  /// Ends the task as successful.
  void complete([String? message]);

  /// Ends the task as failed.
  void fail([String? message]);
}

/// A resolved way to run a tool: an executable, arguments that always come
/// first, and environment variables.
///
/// For example, flutterfire activated with `dart pub global activate` runs
/// as `ToolRef('dart', prefixArgs: ['pub', 'global', 'run',
/// 'flutterfire_cli:flutterfire'])`.
final class ToolRef {
  /// Creates a way to run [executable].
  ///
  /// [executable] is an absolute path or a name that the pipeline looks up
  /// with [SmfEnvironment.findExecutable] before running it. The names
  /// `flutter` and `dart` stand for the Flutter SDK that the pipeline
  /// checked before generation, whatever else is on the `PATH`.
  const ToolRef(
    this.executable, {
    this.prefixArgs = const [],
    this.environment = const {},
  });

  /// The executable: an absolute path or a name to look up.
  final String executable;

  /// Arguments that come before the arguments of every call.
  final List<String> prefixArgs;

  /// Environment variables the tool needs.
  final Map<String, String> environment;

  /// The full arguments of a call with [arguments].
  List<String> argumentsFor(List<String> arguments) =>
      [...prefixArgs, ...arguments];
}
