import 'package:file/file.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/host.dart';

/// The Flutter SDK that the pipeline found before generation.
final class FlutterSdk {
  /// Creates the SDK with the absolute paths of its executables and, if
  /// known, its versions.
  const FlutterSdk({
    required this.flutter,
    required this.dart,
    this.flutterVersion,
    this.dartVersion,
  });

  /// The absolute path of `flutter`, or `flutter.bat` on Windows.
  final String flutter;

  /// The absolute path of the SDK's `dart`, or `dart.bat` on Windows.
  final String dart;

  /// The version of Flutter, such as `3.44.2`, if the SDK records it.
  final String? flutterVersion;

  /// The version of Dart, such as `3.12.2`, if the SDK records it.
  final String? dartVersion;
}

/// Thrown when the executable of a tool is not on the machine.
final class ToolNotFoundException implements Exception {
  /// Creates the exception for the executable [executable].
  const ToolNotFoundException(this.executable);

  /// The executable as the tool names it, such as `firebase`.
  final String executable;

  @override
  String toString() => 'The executable $executable was not found.';
}

/// A command ready to run: an absolute executable, all its arguments and its
/// environment variables.
final class ResolvedTool {
  /// Creates the command.
  const ResolvedTool(this.executable, this.arguments, this.environment);

  /// The absolute path of the executable.
  final String executable;

  /// All arguments, the prefix arguments of the tool first.
  final List<String> arguments;

  /// The environment variables of the command, including a `PATH` with the
  /// directories of the tools installed during the run.
  final Map<String, String> environment;
}

/// The pipeline's implementation of [SmfEnvironment]: the machine of the
/// host plus what the run has learned about it, such as the directories
/// of tools installed during the run and the Flutter SDK.
final class PipelineEnvironment implements SmfEnvironment {
  /// Creates the environment of a run on a host.
  PipelineEnvironment(
    this._host, {
    required this.interactive,
    required this.skipExternalSetup,
  });

  final SmfHost _host;
  final List<String> _binDirs = [];
  Directory? _tempDirectory;

  /// The Flutter SDK, once the preflight checks found it.
  FlutterSdk? sdk;

  @override
  final bool interactive;

  @override
  final bool skipExternalSetup;

  @override
  HostOperatingSystem get operatingSystem => _host.operatingSystem;

  /// Runs commands with [path] as their `PATH`, unless a call sets its own,
  /// so tools that call each other, such as the Firebase CLI calling
  /// `node`, find what the run installed and the Flutter SDK it found.
  @override
  SmfProcessRunner get processRunner => _PathRunner(this);

  @override
  SmfPrompter get prompter => _host.prompter;

  @override
  SmfLogger get logger => _host.logger;

  /// The file system of the host.
  FileSystem get fileSystem => _host.fileSystem;

  bool get _isWindows => operatingSystem == HostOperatingSystem.windows;

  /// The directories of the tools installed during the run, in the order
  /// they were added.
  List<String> get binDirs => List.unmodifiable(_binDirs);

  /// Adds [directories] with installed tools; they are searched before the
  /// `PATH` of the host.
  void addBinDirs(Iterable<String> directories) {
    for (final directory in directories) {
      if (!_binDirs.contains(directory)) _binDirs.add(directory);
    }
  }

  /// The name of the `PATH` variable in the host's environment, which
  /// Windows spells in any case.
  String get _pathKey {
    if (!_isWindows) return 'PATH';
    for (final key in _host.environmentVariables.keys) {
      if (key.toUpperCase() == 'PATH') return key;
    }
    return 'PATH';
  }

  String get _separator => _isWindows ? ';' : ':';

  /// The directory of the Flutter SDK's executables, once it is known.
  String? get _sdkBin {
    final dart = sdk?.dart;
    return dart == null ? null : fileSystem.path.dirname(dart);
  }

  /// The `PATH` of commands the pipeline runs: the directory of the Flutter
  /// SDK once it is known, the directories of the installed tools, then the
  /// host's `PATH`.
  String get path => [
        if (_sdkBin case final bin?) bin,
        ..._binDirs,
        if (_host.environmentVariables[_pathKey] case final hostPath?
            when hostPath.isNotEmpty)
          hostPath,
      ].join(_separator);

  List<String> get _searchDirectories {
    final hostPath = _host.environmentVariables[_pathKey] ?? '';
    return [
      ..._binDirs,
      for (final directory in hostPath.split(_separator))
        // Windows allows quotes around a directory with a separator in it.
        if (directory.replaceAll('"', '') case final clean
            when clean.isNotEmpty)
          clean,
    ];
  }

  /// [environment] with [path] as its `PATH`, unless it has one; on
  /// Windows the name of the variable may have any case.
  Map<String, String> withPath(Map<String, String> environment) {
    final hasPath = environment.keys.any(
      (key) => _isWindows ? key.toUpperCase() == 'PATH' : key == 'PATH',
    );
    return hasPath ? environment : {...environment, _pathKey: path};
  }

  /// The names to look for when searching for [name]: on Windows, [name]
  /// with each extension of `PATHEXT` unless it has an extension already.
  List<String> _candidateNames(String name) {
    final context = fileSystem.path;
    if (!_isWindows || context.extension(name).isNotEmpty) return [name];
    final extensions = _host.environmentVariables.entries
            .where((entry) => entry.key.toUpperCase() == 'PATHEXT')
            .map((entry) => entry.value)
            .firstOrNull ??
        '.COM;.EXE;.BAT;.CMD';
    return [
      for (final extension in extensions.split(';'))
        if (extension.isNotEmpty) '$name${extension.toLowerCase()}',
    ];
  }

  /// `flutter` and `dart` are the executables of the Flutter SDK once the
  /// preflight checks found it; any other name is the first file with the
  /// name in the installed directories and then the directories of the
  /// `PATH`, and a [name] with a path is checked as it is. It does not check
  /// whether the file may be executed.
  @override
  Future<String?> findExecutable(String name) async {
    if (sdk case final sdk?) {
      if (name == 'flutter') return sdk.flutter;
      if (name == 'dart') return sdk.dart;
    }
    final context = fileSystem.path;
    final names = _candidateNames(name);
    if (context.isAbsolute(name) ||
        name.contains(context.separator) ||
        name.contains('/')) {
      for (final candidate in names) {
        final path = context.normalize(context.absolute(candidate));
        if (await fileSystem.isFile(path)) return path;
      }
      return null;
    }
    for (final directory in _searchDirectories) {
      for (final candidate in names) {
        final path = context
            .normalize(context.absolute(context.join(directory, candidate)));
        if (await fileSystem.isFile(path)) return path;
      }
    }
    return null;
  }

  @override
  Future<String> writeTempFile(String name, String contents) async {
    final directory = _tempDirectory ??=
        await fileSystem.systemTempDirectory.createTemp('smf_');
    // A directory of its own keeps the name and never meets another file.
    final file = (await directory.createTemp('file_')).childFile(name);
    await file.writeAsString(contents);
    return file.path;
  }

  /// Resolves [tool] with [arguments] into a command ready to run.
  ///
  /// `flutter` and `dart` stand for the SDK the preflight checks found;
  /// other names are looked up with [findExecutable]. The command's `PATH`
  /// is the tool's own, if it has one, followed by [path]. Throws a
  /// [ToolNotFoundException] if the executable cannot be found.
  Future<ResolvedTool> resolveTool(
    ToolRef tool, [
    List<String> arguments = const [],
  ]) async {
    final executable = switch (tool.executable) {
      'flutter' => sdk?.flutter,
      'dart' => sdk?.dart,
      final name => await findExecutable(name),
    };
    if (executable == null) throw ToolNotFoundException(tool.executable);
    bool isPath(String key) =>
        _isWindows ? key.toUpperCase() == 'PATH' : key == 'PATH';
    final toolPath = [
      for (final MapEntry(:key, :value) in tool.environment.entries)
        if (isPath(key)) value,
    ];
    return ResolvedTool(
      executable,
      tool.argumentsFor(arguments),
      {
        for (final MapEntry(:key, :value) in tool.environment.entries)
          if (!isPath(key)) key: value,
        _pathKey: [...toolPath, path].join(_separator),
      },
    );
  }

  /// Deletes the temporary files of the run.
  Future<void> dispose() async {
    final directory = _tempDirectory;
    _tempDirectory = null;
    if (directory != null && directory.existsSync()) {
      await directory.delete(recursive: true);
    }
  }
}

/// The runner of a [PipelineEnvironment]: the host's, with the `PATH` of the
/// environment for every call that does not set one.
final class _PathRunner implements SmfProcessRunner {
  const _PathRunner(this._environment);

  final PipelineEnvironment _environment;

  SmfProcessRunner get _host => _environment._host.processRunner;

  @override
  Future<SmfProcessResult> run(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
    void Function(String line)? onOutput,
  }) =>
      _host.run(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: _environment.withPath(environment),
        runInShell: runInShell,
        onOutput: onOutput,
      );

  @override
  Future<int> runInteractive(
    String executable,
    List<String> arguments, {
    String? workingDirectory,
    Map<String, String> environment = const {},
    bool runInShell = false,
  }) =>
      _host.runInteractive(
        executable,
        arguments,
        workingDirectory: workingDirectory,
        environment: _environment.withPath(environment),
        runInShell: runInShell,
      );
}
