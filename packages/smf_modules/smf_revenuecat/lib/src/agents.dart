import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_revenuecat/src/readme.dart';
import 'package:smf_revenuecat/src/revenuecat_module.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the purchases: which file is on purchases_flutter, what the
/// premium access is in RevenueCat, which key a build takes and why, when
/// the app may call RevenueCat, how a grant made elsewhere reaches the app,
/// and what a test of the app needs in place of the platform side of the
/// package.
final String agentNote = '''
With `purchases_flutter`:

- `RevenueCatPurchasesService` in `$serviceFile` implements `PurchasesService` on `Purchases`. In `lib/`, only that file imports the package: other code buys and restores through `appPurchases`.
- The premium access is the entitlement `${RevenueCatModule.entitlement}` in RevenueCat, which every package of the current offering unlocks. The id of a `Plan` is the identifier of its package.
- `revenueCatKey()` chooses the key from `${EnvRole.dotEnvFile}`: `${RevenueCatModule.testKey.name}` only when `kDebugMode` is true and it is filled in, and otherwise `${RevenueCatModule.appleKey.name}` on iOS and `${RevenueCatModule.googleKey.name}` on Android. Keep that rule: RevenueCat stops a profile or release build that is configured with a key of the Test Store. A secret key (`sk_`) never goes into the app.
- Never call `Purchases` before `Purchases.configure()` has completed, or without a key: iOS stops the app. Every call of the service waits for its configuration, and without a key it fails with `notConfigured` and calls nothing.
- RevenueCat answers from a cache of the customer info. A grant made on the dashboard or with the API of RevenueCat shows after `Purchases.invalidateCustomerInfoCache()` and the next read of the customer info.
- The package has no platform side for tests. A test that runs `${AppEntryRole.bootstrap.name}()` answers the method channel `purchases_flutter` itself, with `setMockMethodCallHandler` of `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger`. The listeners and the last customer info of `Purchases` are static, so they last for a whole test file.
''';
