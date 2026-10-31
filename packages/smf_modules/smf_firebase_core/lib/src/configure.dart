import 'package:smf_contracts/smf_contracts.dart';

/// The path of the script of the app that configures Firebase for a flavor;
/// see `FirebaseCoreModule.configureScript`.
const configureScriptPath = 'tool/configure_firebase.dart';

/// The command that configures Firebase for [flavor], as the developer of the
/// app types it in its directory.
String configureCommandOf(AppFlavor flavor) =>
    'dart $configureScriptPath ${flavor.name} --project=<id>';

/// The flavors of the app with [identity] as the code of a constant map of
/// the script [configureScriptPath]: for each flavor of the role, by its name,
/// its id on each platform, `null` for a platform that the app does not have,
/// and its Xcode build configurations.
///
/// flutterfire would otherwise read the ids from the files of the app
/// (`lib/src/flutter_app.dart` of flutterfire_cli 1.4.1): the first
/// `PRODUCT_BUNDLE_IDENTIFIER` of the Xcode project and the `applicationId` of
/// the Android project, which are those of one flavor at most, and it would
/// register every flavor under them.
String flavorIdsCode(AppIdentity identity) {
  final platforms = identity.platforms;
  String idCode(String platform, String id) =>
      platforms.contains(platform) ? "'$id'" : 'null';

  String flavorCode(AppFlavor flavor) {
    final android = idCode('android', flavor.applicationIdIn(identity));
    final ios = idCode('ios', flavor.bundleIdIn(identity));
    final configurations = _listCode(flavor.xcodeConfigurations);
    return "'${flavor.name}': "
        '(android: $android, ios: $ios, configurations: $configurations)';
  }

  return '{${AppEntryRole.flavors.map(flavorCode).join(', ')}}';
}

/// The code of a constant list of [items].
String _listCode(List<String> items) =>
    "[${items.map((item) => "'$item'").join(', ')}]";
