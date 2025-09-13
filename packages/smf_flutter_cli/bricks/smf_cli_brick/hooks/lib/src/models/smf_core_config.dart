import 'package:mason/mason.dart';
import 'package:path/path.dart';
import 'package:smf_cli_hooks/src/constants/arguments.dart';
import 'package:smf_cli_hooks/src/constants/constants.dart';
import 'package:smf_cli_hooks/src/models/app_id.dart';
import 'package:smf_cli_hooks/src/models/exceptions.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// Configuration object for SMF core project scaffolding.
///
/// Encapsulates app and organization names, derived Android/iOS identifiers,
/// Android package namespace, and the absolute working directory where the
/// project will be generated.
class SmfCoreConfig {
  /// Creates a new [SmfCoreConfig].
  ///
  /// When `appId` is not provided, platform-specific identifiers are derived
  /// using `AppId.fallbackAndroid` and `AppId.fallbackiOS`. When
  /// `androidNamespace` is not provided, it defaults to the Android
  /// `appId` value of the resolved `AppId`.
  ///
  /// Throws [InvalidAppIdException] if the resolved Android [AppId] is invalid.
  SmfCoreConfig({
    required this.appName,
    required this.orgName,
    required this.workingDirectory,
    AppId? appId,
    String? androidNamespace,
  }) {
    androidAppId = appId ??
        AppId.fallbackAndroid(
          orgName: orgName,
          appName: appName,
        );

    iOSAppId = appId ??
        AppId.fallbackiOS(
          orgName: orgName,
          appName: appName,
        );

    if (!androidAppId.isValid) {
      throw InvalidAppIdException();
    }

    this.androidNamespace = androidNamespace ?? androidAppId.appId;
  }

  /// Creates a [SmfCoreConfig] from Mason hook variables.
  ///
  /// Expected keys in [vars]:
  /// - 'app_name' (String?)
  /// - `kOrgNameArg` (String?)
  /// - `kAppIdArg` (String?)
  /// - 'working_dir' (String)
  ///
  /// Falls back to `kDefaultAppName` and `kDefaultOrgName` when values are
  /// not provided. The [workingDirectory] is constructed by joining
  /// 'working_dir' and the effective app name.
  ///
  /// Throws [ArgumentError] when a value has an unexpected type.
  factory SmfCoreConfig.fromHooksVars(Map<String, dynamic> vars) {
    var appName = vars['app_name'];
    if (appName is! String?) {
      throw ArgumentError.value(
        vars,
        'vars',
        'Expected a value for key app_name to be of type String?,'
            ' got $appName.',
      );
    } else {
      appName = appName?.snakeCase;
    }

    var orgName = vars[kOrgNameArg];
    if (orgName is! String?) {
      throw ArgumentError.value(
        vars,
        'vars',
        'Expected a value for key org_name to be of type String?,'
            ' got $orgName.',
      );
    } else {
      orgName = orgName?.dotCase;
    }

    final appId = vars[kAppIdArg];
    if (appId is! String?) {
      throw ArgumentError.value(
        vars,
        'vars',
        'Expected a value for key application_id to be of type String?,'
            ' got $appId.',
      );
    }

    final workingDir = vars[kWorkingDirectory];
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

  /// Human-readable application name.
  final String appName;

  /// Organization name (usually reverse domain) used for identifiers.
  final String orgName;

  /// Resolved Android application identifier derived or taken from `appId`.
  /// Validated in the constructor.
  late final AppId androidAppId;

  /// Resolved iOS application identifier derived or taken from appId.
  late final AppId iOSAppId;

  /// Android package namespace used in Gradle/Manifest.
  /// Defaults to `androidAppId.appId` when not explicitly provided.
  late final String androidNamespace;

  /// Absolute path to the directory where the Flutter project will be created.
  final String workingDirectory;
}
