import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_revenuecat/src/revenuecat_module.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'RevenueCat';

/// The name of the file with the service of the module.
const serviceFileName = 'revenuecat_purchases_service.dart';

/// The path in the app of the file with the service of the module.
const serviceFile = 'lib/core/purchases/$serviceFileName';

/// The names of the keys of the module in `.env`.
final String _apple = RevenueCatModule.appleKey.name;
final String _google = RevenueCatModule.googleKey.name;
final String _test = RevenueCatModule.testKey.name;

/// The identifier of the entitlement that is the premium access.
const String _entitlement = RevenueCatModule.entitlement;

/// The file of the values of the app.
const String _env = EnvRole.dotEnvFile;

/// The section of the module in the README of the app, which also has the
/// sections of the purchases role and of the values in `.env`: what the
/// app sells in RevenueCat, the way to a first purchase in the Test Store,
/// what a release needs, which key a build takes, that the keys are public,
/// and what the app does without a key.
final String readmeSection = '''
The app sells its premium access with [RevenueCat](https://www.revenuecat.com) and [purchases_flutter](https://pub.dev/packages/purchases_flutter): `$serviceFile` implements the purchases service of the app on it (see the section ${PurchasesRole.readmeHeading}). The premium access is the entitlement `$_entitlement` in RevenueCat, and the plans of the app are the packages of the current offering. Every package of that offering unlocks the same access, so attach each of its products to `$_entitlement`.

To buy a plan right after generating the app, with no account in a store:

1. Create a project in RevenueCat. A new project has a Test Store with products.
2. Create an entitlement with the identifier `$_entitlement` and attach the products to it.
3. Add the packages of those products to an offering, and make that offering the current one.
4. Copy the public API key of the Test Store, which starts with `test_`, into `$_test` in `$_env`.
5. Run a debug build as the section ${EnvRole.readmeHeading} says, and buy a plan. The Test Store shows a dialog of its own, where "Test valid purchase" completes the purchase.

For a release, add the App Store app and the Play Store app to the project in RevenueCat. Give RevenueCat the In-App Purchase key of App Store Connect and a service account of Google Play, so that it checks the purchases in the stores. Create the products in the stores, attach them to `$_entitlement` and add their packages to the offering. Then copy the public API keys of the two apps into `$_apple` (`appl_`) and `$_google` (`goog_`). The section ${AppEntryRole.setupHeading} lists these steps.

A debug build takes `$_test` when it is filled in, and the key of the store of the platform otherwise. A profile or release build never takes it: RevenueCat stops such a build that is configured with a key of the Test Store, on purpose. So to try the sandbox of a store in a debug build, leave `$_test` empty.

These keys are the public API keys of RevenueCat, which go into the app, where anyone can read them. A secret API key of RevenueCat, which starts with `sk_`, never goes into `$_env`, and the app refuses one. While the key that a build takes has no value, the app runs without purchases: it never calls RevenueCat, every call of `appPurchases` fails with the reason `notConfigured`, and a debug build prints which key to fill in.
''';
