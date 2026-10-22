import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_revenuecat/bundles/revenuecat_bundle.dart';
import 'package:smf_revenuecat/src/agents.dart';
import 'package:smf_revenuecat/src/readme.dart';

/// The module that sells the premium access of the app through
/// [RevenueCat](https://www.revenuecat.com), and so provides the purchases
/// role: the plans of the current offering, a purchase, a restore and the
/// access of the user.
///
/// The template of the role generates `PurchasesService`, the interface of
/// the service of a provider, `appPurchases`, through which the code of the
/// app buys and restores, and `initPurchases()`, which `bootstrap()` awaits
/// before the first frame. This module adds `purchases_flutter` to the
/// dependencies of the app and implements the service in [serviceFile] on
/// `Purchases`. The premium access is the entitlement [entitlement] in
/// RevenueCat, which every product of the current offering unlocks, and a
/// plan is a package of that offering.
///
/// The module requires the env role for its keys, the public API keys of
/// RevenueCat, which the developer of the app fills in in `.env`:
/// [appleKey], [googleKey] and [testKey]. A debug build takes the key of
/// the Test Store of RevenueCat when it is filled in, so the developer
/// buys a plan right after generating the app with nothing but a
/// RevenueCat account; a profile or release build takes the key of the
/// store of the platform, since RevenueCat stops such a build that is
/// configured with a key of the Test Store. The service refuses a secret
/// key of RevenueCat. Without a key, it never calls RevenueCat, and the
/// app runs without purchases: every call fails with `notConfigured` and a
/// hint that names the key.
///
/// The service keeps what the role promises and the package does not:
/// - it calls RevenueCat only once RevenueCat is configured, since iOS
///   stops an app that calls it before;
/// - `identify(null)` logs out a user of the app, and a log out of the
///   anonymous user of RevenueCat, which RevenueCat fails, counts as done;
/// - it reads the code of an error of RevenueCat as a number only when it
///   is one, as the plugin gives an error of its own a code that is not;
/// - a purchase that RevenueCat gives no active entitlement [entitlement]
///   for fails with `notConfigured`, with a hint that tells which product
///   to attach to it;
/// - on iOS, a plan has its intro offer only when iOS says that the user
///   may take it, and on Android a plan has the title of its product without
///   the name of the app, which Google Play appends.
///
/// No step of the native projects is needed: the Billing Library of
/// Google Play declares its permission itself, and the In-App Purchase
/// capability of iOS has no entitlement. The steps by hand of the module are
/// those of RevenueCat; the steps in the stores are those of the role.
final class RevenueCatModule extends SmfModule {
  /// Creates the module.
  const RevenueCatModule();

  /// The id of the module.
  static const id = ModuleId('revenuecat');

  /// The identifier of the entitlement in RevenueCat that is the premium
  /// access of the app.
  static const entitlement = 'premium';

  /// The key of the public API key of the App Store app in RevenueCat.
  static const appleKey = EnvKey(
    'REVENUECAT_APPLE_KEY',
    description: 'The public API key of the App Store app in RevenueCat, '
        'which starts with appl_',
  );

  /// The key of the public API key of the Play Store app in RevenueCat.
  static const googleKey = EnvKey(
    'REVENUECAT_GOOGLE_KEY',
    description: 'The public API key of the Play Store app in RevenueCat, '
        'which starts with goog_',
  );

  /// The key of the public API key of the Test Store of RevenueCat, which
  /// only a debug build takes.
  static const testKey = EnvKey(
    'REVENUECAT_TEST_KEY',
    description: 'The public API key of the Test Store in RevenueCat '
        '(test_), which only a debug build uses',
  );

  /// The keys of the module, in the order of `.env`.
  static const List<EnvKey> keys = [appleKey, googleKey, testKey];

  /// The step by hand in which the developer creates the entitlement
  /// [entitlement] in RevenueCat, attaches the products to it and makes an
  /// offering with their packages current.
  static const entitlementAndOfferingStep = ManualStep(
    ManualStepId(id, 'entitlement_and_offering'),
    'Set up the entitlement premium and a current offering in RevenueCat',
  );

  /// The step by hand in which the developer copies the public API keys of
  /// the apps of the RevenueCat project into `.env`.
  static const apiKeysStep = ManualStep(
    ManualStepId(id, 'api_keys'),
    'Copy the API keys of your RevenueCat apps into .env',
  );

  /// The step by hand in which the developer gives RevenueCat the In-App
  /// Purchase key of App Store Connect, with which it checks the purchases
  /// on iOS.
  static const appStoreKeyStep = ManualStep(
    ManualStepId(id, 'app_store_key'),
    'Give RevenueCat your In-App Purchase key from App Store Connect',
  );

  /// The step by hand in which the developer gives RevenueCat a service
  /// account of Google Play, with which it checks the purchases on Android.
  static const playServiceAccountStep = ManualStep(
    ManualStepId(id, 'play_service_account'),
    'Give RevenueCat access to Google Play with a service account',
  );

  static const _file = ImportRef.app('core/purchases/$serviceFileName');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'RevenueCat with purchases_flutter',
        kind: ModuleKinds.infrastructure,
        requires: {envRole},
        providers: [RoleProvider.plain(purchasesRole)],
      );

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          revenuecatBundle,
          vars: {
            ...envRole.varsOf(id, keys),
            'entitlement': entitlement,
          },
        ),
        const PubspecContribution.hosted('purchases_flutter', '^10.18.0'),
        purchasesRole.data(
          const RoleImplementation(
            type: TypeRef('RevenueCatPurchasesService', import: _file),
            create: FactoryRef(
              'createRevenueCatPurchasesService',
              import: _file,
            ),
          ),
        ),
        for (final key in keys) envRole.data(key),
        entitlementAndOfferingStep,
        apiKeysStep,
        appStoreKeyStep,
        playServiceAccountStep,
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(
          purchasesRole.description,
          AgentNote(agentNote),
        ),
      ];
}
