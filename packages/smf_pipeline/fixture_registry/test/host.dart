import 'package:file/memory.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';

/// A host without a terminal, with a Flutter SDK in `/sdk` and nothing else,
/// whose current directory is `/work`: asking the user fails the test, and
/// so does running a command unless [processRunner] runs it.
SmfHost testHost({SmfProcessRunner? processRunner}) {
  final fileSystem = MemoryFileSystem.test();
  fileSystem.currentDirectory = fileSystem.directory('/work')..createSync();
  for (final name in ['flutter', 'dart']) {
    fileSystem.file('/sdk/bin/$name').createSync(recursive: true);
  }
  // What tells the bin directory of a Flutter SDK apart.
  fileSystem.directory('/sdk/bin/cache/dart-sdk').createSync(recursive: true);
  return SmfHost(
    prompter: _NoPrompter(),
    processRunner: processRunner ?? _NoProcessRunner(),
    logger: _SilentLogger(),
    fileSystem: fileSystem,
    environmentVariables: const {'PATH': '/sdk/bin'},
    operatingSystem: HostOperatingSystem.linux,
    hasTerminal: false,
  );
}

final class _NoPrompter implements SmfPrompter {
  @override
  Future<bool> confirm(String message, {bool defaultValue = false}) =>
      throw StateError('Unexpected question: $message');

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

final class _NoProcessRunner implements SmfProcessRunner {
  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
  }) =>
      throw StateError('Unexpected command: $executable');

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) =>
      throw StateError('Unexpected command: $executable');
}

final class _SilentLogger implements SmfLogger {
  @override
  void info(String message) {}

  @override
  void detail(String message) {}

  @override
  void warn(String message) {}

  @override
  void error(String message) {}

  @override
  void success(String message) {}

  @override
  SmfProgress progress(String message) => _SilentProgress();
}

final class _SilentProgress implements SmfProgress {
  @override
  void update(String message) {}

  @override
  void complete([String? message]) {}

  @override
  void fail([String? message]) {}
}

/// A process runner that records every command and lets it succeed.
final class RecordingRunner implements SmfProcessRunner {
  /// The commands, as the name of the executable followed by the arguments.
  final List<String> lines = [];

  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
  }) async {
    lines.add([executable.split('/').last, ...arguments].join(' '));
    return const SmfProcessResult(exitCode: 0);
  }

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) async {
    lines.add([executable.split('/').last, ...arguments].join(' '));
    return 0;
  }
}
