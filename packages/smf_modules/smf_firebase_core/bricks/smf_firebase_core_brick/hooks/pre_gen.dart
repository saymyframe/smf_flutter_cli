import 'package:mason/mason.dart';
import 'package:smf_firebase_core_brick_hooks/smf_firebase_core_hook.dart';

void run(HookContext context) async {
  final workDirectory = context.vars['working_dir'];
  if (workDirectory is! String) {
    throw throw ArgumentError.value(
      context.vars,
      'vars',
      'Expected a value for key working_dir to be of type String, got $workDirectory.',
    );
  }

  final isInstalled = await SmfFirebaseCoreHook(
    context.logger,
    workingDirectory: workDirectory,
  ).run();

  // Update context variables
  context.vars = {
    'flutterfire_installed': isInstalled,
  };
}
