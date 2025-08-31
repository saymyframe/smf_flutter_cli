import 'package:mason/mason.dart';
import 'package:smf_cli_hooks/smf_core_hook_config.dart';
import 'package:smf_contracts/smf_contracts.dart';

Future<void> run(HookContext context) async {
  final config = SmfCoreConfig.fromHooksVars(context.vars);

  context.vars = {
    'app_name': config.appName,
    'org_name': config.orgName,
    'android_application_id': config.androidAppId,
    'ios_application_id': config.iOSAppId,
    'android_namespace': config.androidNamespace,
    kWorkingDirectory: config.workingDirectory,
  };
}
