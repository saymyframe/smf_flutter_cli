// Copyright 2025 SayMyFrame. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:smf_flutter_cli/commands/create.dart';
import 'package:smf_flutter_cli/utils/utils.dart';
import 'package:smf_flutter_cli/version.dart';

/// Top-level command runner for the `smf` CLI.
class SMFCommandRunner extends CommandRunner<void> {
  /// Configures the top-level CLI and registers subcommands.
  SMFCommandRunner()
      : super(
          'smf',
          'A CLI tool by Say My Frame',
          usageLineLength: terminalLineLength,
        ) {
    argParser
      ..addFlag(
        'verbose',
        negatable: false,
        help: 'Enable verbose logging.',
      )
      ..addFlag(
        'strict',
        negatable: false,
        help: 'Enable strict mode for module compatibility checks.',
      )
      ..addFlag(
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print the current CLI version.',
      );

    addCommand(CreateCommand());
  }

  @override
  Future<void> run(Iterable<String> args) async {
    // Print version if requested.
    // If no subcommand is provided, exit after printing.
    final hasVersion = args.contains('--version') || args.contains('-v');
    final hasSubcommand = args.any((a) => commands.containsKey(a));

    if (hasVersion) {
      Logger.standard().write('ℹ️ CLI version: $packageVersion\n');
      if (!hasSubcommand) return;
    }

    return super.run(args);
  }
}
