import 'package:path/path.dart';
import 'package:smf_cli_hooks/src/constants/arguments.dart';
import 'package:smf_cli_hooks/src/constants/constants.dart';
import 'package:smf_cli_hooks/src/models/app_id.dart';
import 'package:smf_cli_hooks/src/models/exceptions.dart';

class SmfCoreConfig {
  SmfCoreConfig({
    required this.appName,
    required this.orgName,
    required this.workingDirectory,
    AppId? appId,
    String? androidNamespace,
  }) {
    this.appId = appId ??
        AppId.fallback(
          orgName: orgName,
          appName: appName,
        );

    if (!this.appId.isValid) {
      throw InvalidAppIdException();
    }

    this.androidNamespace = androidNamespace ?? this.appId.appId;
  }

  factory SmfCoreConfig.fromHooksVars(Map<String, dynamic> vars) {
    final appName = vars['app_name'];
    if (appName is! String?) {
      throw ArgumentError.value(
        vars,
        'vars',
        'Expected a value for key $kAppNameArg to be of type String?, got $appName.',
      );
    }

    final orgName = vars[kOrgNameArg];
    if (orgName is! String?) {
      throw ArgumentError.value(
        vars,
        'vars',
        'Expected a value for key $kOrgNameArg to be of type String?, got $orgName.',
      );
    }

    final appId = vars[kAppIdArg];
    if (appId is! String?) {
      throw ArgumentError.value(
        vars,
        'vars',
        'Expected a value for key $kAppIdArg to be of type String?, got $appId.',
      );
    }

    final workingDir = vars['working_dir'];
    if (workingDir is! String) {
      throw ArgumentError.value(
        vars,
        'vars',
        'Expected a value for key working_dir '
            'to be of type String, got $workingDir.',
      );
    }

    return SmfCoreConfig(
      appName: appName ?? kDefaultAppName,
      orgName: orgName ?? kDefaultOrgName,
      appId: appId == null || appId.isEmpty ? null : AppId(appId),
      workingDirectory: join(workingDir, appName ?? kDefaultAppName),
    );
  }

  final String appName;
  final String orgName;
  late final AppId appId;
  late final String androidNamespace;
  final String workingDirectory;
}
