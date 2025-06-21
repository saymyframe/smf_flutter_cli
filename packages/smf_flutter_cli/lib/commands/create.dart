import 'package:smf_flutter_cli/cli_engine.dart';
import 'package:smf_flutter_cli/commands/base.dart';

final class CreateCommand extends BaseCommand {
  CreateCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output path. A path where project will be created',
      defaultsTo: './',
    );
  }

  @override
  String get description => 'Create flutter app';

  @override
  String get name => 'create';

  @override
  Future<void> run() async {
    print(argResults!['output']);
    print(argResults!.rest.first);
    print('${argResults!['output']}${argResults!.rest.first}');
    // Process.run(
    //   'flutter',
    //   ['create', '${argResults!['output']}${argResults!.rest.first}'],
    // );

    // CreatePrompt().prompt();
    runCli();
  }
}
