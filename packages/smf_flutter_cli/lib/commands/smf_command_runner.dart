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
import 'package:smf_flutter_cli/commands/create.dart';
import 'package:smf_flutter_cli/utils/utils.dart';

/// Top-level command runner for the `smfflutter` CLI.
class SMFCommandRunner extends CommandRunner<void> {
  /// Configures the top-level CLI and registers subcommands.
  SMFCommandRunner()
      : super(
          'smfflutter',
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
        'version',
        abbr: 'v',
        negatable: false,
        help: 'Print the current CLI version.',
      );

    addCommand(CreateCommand());
  }
}
