import 'package:file/file.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/src/host.dart';

/// The Flutter SDK that the pipeline found before generation.
final class FlutterSdk {
  /// Creates the SDK with the absolute paths of its executables.
  const FlutterSdk({required this.flutter, required this.dart});

  /// The absolute path of `flutter`, or `flutter.bat` on Windows.
  final String flutter;

  /// The absolute path of the SDK's `dart`, or `dart.bat` on Windows.
  final String dart;
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

  @override
  SmfProcessRunner get processRunner => _host.processRunner;

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

  /// The `PATH` of commands the pipeline runs: the directories of the
  /// installed tools, then the host's `PATH`.
  String get path {
    final separator = _isWindows ? ';' : ':';
    return [
      ..._binDirs,
      if (_host.environmentVariables[_pathKey] case final hostPath?
          when hostPath.isNotEmpty)
        hostPath,
    ].join(separator);
  }

  List<String> get _searchDirectories {
    final separator = _isWindows ? ';' : ':';
    final hostPath = _host.environmentVariables[_pathKey] ?? '';
    return [
      ..._binDirs,
      ...hostPath.split(separator).where((directory) => directory.isNotEmpty),
    ];
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

  /// The first file named [name] in the installed directories and then the
  /// directories of the `PATH`; a [name] with a path is checked as it is.
  /// It does not check whether the file may be executed.
  @override
  Future<String?> findExecutable(String name) async {
    final context = fileSystem.path;
    final names = _candidateNames(name);
    if (context.isAbsolute(name) || name.contains(context.separator)) {
      for (final candidate in names) {
        final path = context.absolute(candidate);
        if (await fileSystem.isFile(path)) return context.normalize(path);
      }
      return null;
    }
    for (final directory in _searchDirectories) {
      for (final candidate in names) {
        final path = context.absolute(context.join(directory, candidate));
        if (await fileSystem.isFile(path)) return context.normalize(path);
      }
    }
    return null;
  }

  @override
  Future<String> writeTempFile(String name, String contents) async {
    final directory = _tempDirectory ??=
        await fileSystem.systemTempDirectory.createTemp('smf_');
    final file = directory.childFile(name);
    await file.writeAsString(contents);
    return file.path;
  }

  /// Resolves [tool] with [arguments] into a command ready to run.
  ///
  /// `flutter` and `dart` stand for the SDK the preflight checks found;
  /// other names are looked up with [findExecutable]. Throws a
  /// [StateError] if the executable cannot be found.
  Future<ResolvedTool> resolveTool(
    ToolRef tool, [
    List<String> arguments = const [],
  ]) async {
    final executable = switch (tool.executable) {
      'flutter' => sdk?.flutter,
      'dart' => sdk?.dart,
      final name => await findExecutable(name),
    };
    if (executable == null) {
      throw StateError('The executable ${tool.executable} was not found.');
    }
    return ResolvedTool(
      executable,
      tool.argumentsFor(arguments),
      {...tool.environment, _pathKey: path},
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
