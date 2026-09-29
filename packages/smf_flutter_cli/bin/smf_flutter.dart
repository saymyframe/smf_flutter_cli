import 'dart:io';

import 'package:smf_flutter_cli/smf_flutter_cli.dart';

Future<void> main(List<String> arguments) async {
  final code = await runCli(arguments);
  // Nothing may keep the process alive once the command is done.
  await Future.wait<void>([stdout.flush(), stderr.flush()]);
  exit(code);
}
