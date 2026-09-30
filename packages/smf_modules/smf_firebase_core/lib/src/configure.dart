import 'package:smf_contracts/smf_contracts.dart';

/// The arguments of `flutterfire configure` for the app with [identity]:
/// the platforms of the app, [AppIdentity.platforms], the options written
/// over the placeholder, and the ids of its Android and iOS apps, each only
/// when its platform is one of them.
///
/// Without the ids, flutterfire reads them from the files of the app
/// (`lib/src/flutter_app.dart` of flutterfire_cli 1.4.1): the bundle id from
/// the first `PRODUCT_BUNDLE_IDENTIFIER` of the Xcode project, but only when
/// it is not in quotes. flutterfire saves the Xcode project with the Ruby gem
/// xcodeproj, which puts a bundle id with a hyphen, such as
/// `com.example.my-app`, in quotes, so configuring the app again would ask
/// for the bundle id, or fail without a terminal. The ids are those of
/// [identity], which the Android and iOS projects of the app have.
///
/// flutterfire checks an id that an option gives more strictly than Android
/// and Apple do (`validateAppBundleId` and `validateAndroidPackageName` in
/// `lib/src/common/utils.dart` of flutterfire_cli 1.4.1), and stops when it
/// fails: it takes no underscore in the first part of an application id,
/// such as `my_org.my_app`, and no hyphen at the end of a part of a bundle
/// id. Such an id is left out, and flutterfire reads it from the files of the
/// app instead.
List<String> configureArguments(AppIdentity identity) {
  final platforms = identity.platforms;
  return [
    'configure',
    '--platforms=${platforms.join(',')}',
    '--overwrite-firebase-options',
    if (platforms.contains('ios') && _bundleId.hasMatch(identity.iosBundleId))
      '--ios-bundle-id=${identity.iosBundleId}',
    if (platforms.contains('android') &&
        _packageName.hasMatch(identity.androidApplicationId))
      '--android-package-name=${identity.androidApplicationId}',
  ];
}

/// A bundle id that `flutterfire configure` takes with `--ios-bundle-id`, as
/// `validateAppBundleId` of flutterfire_cli 1.4.1 checks it.
final _bundleId = RegExp(
  r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?|([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+))$',
);

/// An application id that `flutterfire configure` takes with
/// `--android-package-name`, as `validateAndroidPackageName` of
/// flutterfire_cli 1.4.1 checks it.
final _packageName =
    RegExp(r'^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z_][a-zA-Z0-9_]*)+$');
