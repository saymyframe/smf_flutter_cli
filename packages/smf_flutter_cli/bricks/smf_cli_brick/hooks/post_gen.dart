import 'package:mason/mason.dart';
import 'package:smf_cli_hooks/shell/shell_runner.dart';

Future<void> run(HookContext context) async {
  final workingDirectory = context.vars['working_dir'] as String;

  await ShellRunner.run(
    'flutter',
    ['pub', 'get'],
    logger: context.logger,
    workingDirectory: workingDirectory,
    runInShell: true,
  );

  await ShellRunner.run(
    'dart',
    ['fix', '--apply'],
    logger: context.logger,
    workingDirectory: workingDirectory,
    runInShell: true,
  );

  await ShellRunner.run(
    'dart',
    ['format', '.'],
    logger: context.logger,
    workingDirectory: workingDirectory,
    runInShell: true,
  );
}
