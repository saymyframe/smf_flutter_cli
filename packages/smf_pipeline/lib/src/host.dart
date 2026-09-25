import 'package:file/file.dart';
import 'package:smf_contracts/lego_core.dart';

/// The machine the pipeline runs on: the terminal, the file system, the
/// environment variables and external commands.
///
/// The CLI passes the real implementations and tests pass fakes, so the
/// pipeline never touches `dart:io` directly.
final class SmfHost {
  /// Creates the host.
  const SmfHost({
    required this.prompter,
    required this.processRunner,
    required this.logger,
    required this.fileSystem,
    required this.environmentVariables,
    required this.operatingSystem,
    required this.hasTerminal,
  });

  /// Asks the user.
  final SmfPrompter prompter;

  /// Runs external commands.
  final SmfProcessRunner processRunner;

  /// Reports progress and problems.
  final SmfLogger logger;

  /// The file system; paths are resolved against its current directory.
  final FileSystem fileSystem;

  /// The environment variables of the process, such as `PATH`.
  final Map<String, String> environmentVariables;

  /// The operating system the pipeline runs on.
  final HostOperatingSystem operatingSystem;

  /// Whether a user sits at a terminal that can answer prompts.
  final bool hasTerminal;
}
