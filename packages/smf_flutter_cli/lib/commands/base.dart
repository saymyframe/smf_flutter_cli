import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:cli_util/cli_logging.dart';
import 'package:smf_flutter_cli/utils/utils.dart';

abstract base class BaseCommand extends Command<void> {
  Logger get logger =>
      globalResults!['verbose'] as bool ? Logger.verbose() : Logger.standard();

  @override
  late final argParser = ArgParser(usageLineLength: terminalLineLength);
}
