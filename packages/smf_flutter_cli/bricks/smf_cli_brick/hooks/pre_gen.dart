import 'package:mason/mason.dart';
import 'package:smf_cli_hooks/smf_core_hook_config.dart';

Future<void> run(HookContext context) async {
  final config = SmfCoreConfig.fromHooksVars(context.vars);

  context.vars = {
    'app_name': config.appName,
    'org_name': config.orgName,
    'application_id': config.appId,
    'android_namespace': config.androidNamespace,
    'working_dir': config.workingDirectory,
  };
}
