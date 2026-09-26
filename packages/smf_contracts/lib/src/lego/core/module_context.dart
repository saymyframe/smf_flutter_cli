import 'package:smf_contracts/lego_core.dart';

/// Platform identifiers of the generated app.
final class AppIdentity {
  /// Creates the identifiers of an app.
  const AppIdentity({
    required this.androidApplicationId,
    required this.iosBundleId,
    required this.androidNamespace,
  });

  /// The Android application id, such as `com.example.my_app`.
  final String androidApplicationId;

  /// The iOS bundle identifier, such as `com.example.my-app`.
  final String iosBundleId;

  /// The Android namespace of the app module, used by Gradle and the
  /// manifest.
  final String androidNamespace;
}

/// What a module may know about the app it is generated into.
///
/// It describes the app itself and nothing about the other modules or roles
/// of the run: a module that needs another role declares it and receives its
/// symbols and presence flags instead.
final class ModuleContext {
  /// Creates the context of one generation run.
  const ModuleContext({
    required this.appName,
    required this.orgName,
    required this.appIdentity,
  });

  /// The Dart package name of the app, in snake_case, such as `my_app`.
  ///
  /// Code that imports files of the app uses [ImportRef.app] instead of
  /// building `package:` URIs from this name.
  final String appName;

  /// The organization, in reverse domain notation, such as `com.example`.
  final String orgName;

  /// The platform identifiers of the app.
  final AppIdentity appIdentity;
}
