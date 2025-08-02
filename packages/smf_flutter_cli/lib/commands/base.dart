import 'package:args/args.dart';
import 'package:args/command_runner.dart';
import 'package:mason/mason.dart';
import 'package:smf_flutter_cli/utils/utils.dart';

abstract base class BaseCommand extends Command<void> {
  Logger get logger => globalResults!['verbose'] as bool
      ? Logger(level: Level.verbose)
      : Logger();

  @override
  late final argParser = ArgParser(usageLineLength: terminalLineLength);
}
