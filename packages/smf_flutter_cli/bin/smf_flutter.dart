import 'package:smf_flutter_cli/commands/smf_command_runner.dart';

Future<void> main(List<String> arguments) async {
  await SMFCommandRunner().run(arguments);
}
