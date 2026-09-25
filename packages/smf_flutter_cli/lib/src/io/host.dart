import 'dart:io' as io;

import 'package:file/local.dart';
import 'package:smf_contracts/lego_core.dart';
import 'package:smf_flutter_cli/src/banner.dart';
import 'package:smf_flutter_cli/src/io/interruption.dart';
import 'package:smf_flutter_cli/src/io/logger.dart';
import 'package:smf_flutter_cli/src/io/process_runner.dart';
import 'package:smf_flutter_cli/src/io/prompter.dart';
import 'package:smf_flutter_cli/src/io/terminal.dart';
import 'package:smf_pipeline/smf_pipeline.dart';

/// The machine `smf` runs on: its terminal, file system, environment
/// variables and processes.
final class IoHost {
  /// Creates the machine of a run, which reports details if [verbose] and
  /// handles Ctrl-C with [interruption].
  IoHost({required bool verbose, required Interruption interruption})
      : logger = IoLogger(verbose: verbose),
        _interruption = interruption;

  /// Reports to the terminal.
  final IoLogger logger;

  final Interruption _interruption;

  /// The operating system of this machine.
  static HostOperatingSystem get operatingSystem =>
      switch (io.Platform.operatingSystem) {
        'macos' => HostOperatingSystem.macos,
        'linux' => HostOperatingSystem.linux,
        'windows' => HostOperatingSystem.windows,
        _ => HostOperatingSystem.other,
      };

  /// Whether a user sits at a terminal that can answer questions.
  static bool get hasTerminal => io.stdin.hasTerminal && io.stdout.hasTerminal;

  /// The host of the pipeline.
  SmfHost get host => SmfHost(
        prompter: TerminalPrompter(
          IoPromptTerminal(),
          interruption: _interruption,
          greeting: greeting,
        ),
        processRunner: IoProcessRunner(_interruption),
        logger: logger,
        fileSystem: const LocalFileSystem(),
        environmentVariables: io.Platform.environment,
        operatingSystem: operatingSystem,
        hasTerminal: hasTerminal,
      );
}
