import 'package:args/command_runner.dart';
import 'package:smf_flutter_cli/commands/create.dart';
import 'package:smf_flutter_cli/utils/utils.dart';

class SMFCommandRunner extends CommandRunner<void> {
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
