part of '../services.dart';

/// The purchases role; see [PurchasesRole].
const purchasesRole = PurchasesRole._();

/// The role of purchases: premium access to the app, which the user buys
/// with a plan of the current offer of a provider, such as a subscription
/// or a payment once, and restores on another device.
///
/// What the app sells is access, not a kind of product: every plan of the
/// offer gives the same premium access, and [premium] is the condition of
/// a route whose screen is only for a user with it.
///
/// The role's template generates these files, whichever module provides
/// the role:
/// - [serviceFile] with `PurchasesService`, the interface that the provider
///   implements, and the types of its answers: the sealed `AppAccess` with
///   `NoAccess` and `PremiumAccess`, `Plan`, `IntroOffer`, `BillingPeriod`
///   with its `BillingUnit`, and `PurchasesFailure` with its
///   `PurchasesFailureReason`;
/// - [controllerFile] with `appPurchases`, the `AppPurchasesController` of
///   the app. The file exports the types of [serviceFile] but
///   `PurchasesService`, so the code of the app imports this file alone.
///
/// The provider contributes its implementation of `PurchasesService` as a
/// [RoleImplementation], created with the app or asynchronously. The role
/// registers nothing in a DI container: the code of an app uses
/// `appPurchases`, a top-level variable, and no module or template of
/// another role reaches the service of the provider.
///
/// The template also writes the section [readmeHeading] of the README of
/// the app, from its render hook, since the section tells whose the
/// purchases are and where the user restores them, which depends on the
/// roles of the app. In the guide for coding agents of the app, the
/// template writes the note of the role under its description, a note of
/// whose the purchases are in an app with the [AuthRole], and a note of the
/// entry of the settings screen in an app with the [SettingsScreenRole]. It
/// lists the steps by hand [storeAgreementsStep] and [storeProductsStep],
/// which every provider that sells in the stores needs; a provider lists
/// those of its own backend.
///
/// ## The controller
///
/// `appPurchases.value` is the `AppAccess` of the user: `NoAccess`, or
/// `PremiumAccess` while a plan that the user bought is active, with when
/// the access ends, whether the plan renews, whether the access is a free
/// trial, how often the plan is billed and the page of the store where the
/// user manages it. `appPurchases.hasPremium` is the `ValueListenable<bool>`
/// that a guard of the routes reads. It is computed from the value when it
/// is read, and its listeners are those of the controller.
///
/// `Future<void> initPurchases()` creates the service with the provider's
/// function and starts `appPurchases` with it. `bootstrap()` awaits it in
/// its platform phase, so the access is known before the first frame, from
/// what the device keeps. The start waits for the access at most 3 seconds,
/// and an access that comes later still becomes the value. In an app with
/// the [AuthRole], `initAuth()` comes first, and `appPurchases` follows
/// `appSession`: the user whose purchases count is the user of the session,
/// by its id, and the user of the device while nobody is signed in. The
/// line of `initPurchases()` in `bootstrap()` lists the auth role in its
/// condition for that, since an order of the start-up follows the
/// conditions of the code of one socket.
///
/// `appPurchases.plans()` gives the plans of the current offer,
/// `purchase(plan)` buys one and completes with `false` when the user
/// cancelled, which is no failure, and `restore()` gives the user what the
/// store account bought. Each fails only with a `PurchasesFailure`: the
/// provider maps its errors to the reasons, and the controller turns any
/// other error into the reason `unknown`, with the error as the
/// `developerHint`. A purchase whose answer gives no premium access fails
/// with `notConfigured`, whichever provider gave it, since every plan gives
/// that access.
///
/// The calls run one after another, in the order they were made, and so
/// does what the controller does itself. Before each, the controller
/// identifies the user with the service, unless the service has that user
/// already, and the call fails with the failure of that identification. A
/// change of the user waits for the call on its way, so a purchase belongs
/// to the user who made it. Until the service has the new user, the value is
/// `NoAccess`, and the controller takes no change that the service tells of.
/// Changes that wait for their turn take one turn together. Each time the
/// user comes back to the app, the controller asks the service for the
/// access again, so that an expiry, a refund or a grant made elsewhere
/// shows.
///
/// A call made before the first start waits for it and runs once the start
/// has the access. The start completes after such calls, and after the
/// calls that their completions make right away, such as a purchase of a
/// plan that `plans()` gave: it completes once no call is on its way in the
/// microtask after the last one ended.
///
/// An error that no caller sees, of the start, of a change of the user, of
/// a return to the app or of the changes that the service tells of, changes
/// nothing. A failure `notConfigured` prints its hint once in debug mode.
/// `network`, `unavailable` and `storeProblem`, which pass, say nothing, so
/// a store that does not answer reaches no crash report and fails no test.
/// Any other error reaches the handlers of the uncaught errors of the app.
/// So an app whose provider lacks a key starts and runs without purchases.
///
/// ## Whose purchases they are
///
/// `identify(userId)` of the service says whose purchases count: the id of
/// a user of the app, or `null` for the user of this device, who has no
/// account of the app. Every provider keeps to this:
/// - `identify(null)` that follows another user, also one of an earlier
///   launch of the app, starts a new user of this device, with nothing
///   bought. What a user of the device had before comes back only through a
///   restore;
/// - when the user of this device is identified as a user that no
///   `identify` named before, on any device, that user takes over the
///   purchases of the user of this device, who no longer has them. So a
///   purchase before a sign-up stays with the new account, and an anonymous
///   user of the [AuthRole], whose id the account keeps, keeps them too;
/// - any other identification keeps the purchases of each user apart. A
///   sign-in to an account that exists already leaves the purchases with the
///   user of the device, and without a restore the next user of the device
///   never gets the purchases of the one who signed out;
/// - a restore gives the user who is identified what the store account
///   bought, and may move purchases from another user to this one, as the
///   backend of the provider decides. So no test relies on a restore that
///   moves them, or on one that leaves them.
///
/// ## What a provider keeps to
///
/// The contract of `PurchasesService` is in [serviceFile]. In short:
/// - the function of the implementation creates the service without a
///   user, asks the user nothing and never throws. It may be called again,
///   and the new service has what the store and the provider kept;
/// - `identify` comes before any other call. Identifying the user who is
///   identified already does nothing and does not fail, `null` too;
/// - `access` completes from what the device keeps, without the network
///   when it keeps anything, and `accessChanges` tells of each change of the
///   access of the user that the provider learns of, such as a renewal, an
///   expiry or a grant made elsewhere;
/// - `plans` gives at least one plan, in the order of the provider. A
///   backend with nothing to offer fails with `notConfigured` and a hint;
/// - `purchase` completes with the premium access once the store took the
///   payment, and with `null` when the user cancelled. An answer that gives
///   no premium access fails the call of `appPurchases` with
///   `notConfigured`. It fails with
///   `pending` while the payment waits for an approval, whose access
///   `accessChanges` tells of later, and with `alreadyOwned` for a plan that
///   the store account owns;
/// - every call fails only with a `PurchasesFailure`. Without what it needs,
///   such as a key, the provider fails every call with `notConfigured` and a
///   hint that names what is missing, and never stops the app.
///
/// Only a running app shows whether a provider keeps to it.
///
/// ## Rules
///
/// The structural rules of the role read the index of each Dart file of an
/// app, so they see what a file itself imports and calls:
/// - `purchases.factory_calls`: no file of a module, and none of the
///   template of another role, calls `createPurchasesService()`, and of such
///   files only those of the provider's implementation, the files of its
///   class and of its function, import or export [serviceFile];
/// - `purchases.start_calls`: only the file of `bootstrap()` calls
///   `initPurchases()`, and no file of a module or of the template of
///   another role calls `appPurchases.start()`, which `initPurchases()` and
///   tests call;
/// - `purchases.implementation_factories`: the function of the
///   implementation is in its file and takes no arguments.
///
/// They do not see a `part` file of a library that imports
/// [controllerFile], a file that reaches [controllerFile] through an export
/// of another file of the app, or `appPurchases` under another name.
///
/// ## Tests
///
/// A test gives `appPurchases.start()` a service of its own to script what a
/// provider answers, with a user of its own, such as the value of a
/// `ValueNotifier`, and runs `initPurchases()` again to see what the next
/// launch of the app finds. A call of `appPurchases` made before
/// `bootstrap()`, such as `plans().then(...)` that buys a plan, runs within
/// the first start, so the app starts with premium access. A test makes
/// such a call outside the body of a test, as in a `setUpAll`, as with the
/// session of the [AuthRole]. A test that brings the user back to the app
/// may go through any state of the lifecycle: the controller looks only at
/// `AppLifecycleState.resumed`.
///
/// The mocks of the platform side of every provider, with which the tests
/// of the apps run, keep to one convention, so that the tests of the role
/// and of the modules hold with each:
/// - a first launch finds nothing bought, and the offer has at least one
///   plan, each with an id of its own, a title and a price that are not
///   empty, an amount of 0 or more and a `currencyCode` of three upper-case
///   letters;
/// - any text is the id of a user of the app;
/// - a purchase by a user without premium access completes at once and
///   succeeds. Its answer, like that of a restore, is the access that
///   `access()` gives right after it, field by field, and the service tells
///   of no other change of the access while the purchase is on its way or
///   right after it;
/// - a plan with a free intro offer that the user may take gives an access
///   in trial, and any other plan gives an access that is not in trial. A
///   plan with a period renews, and its access ends after the time of the
///   device at the purchase;
/// - the purchases are kept by the user of the app, with the rules of the
///   user of the device above, also from one launch of the app to the next,
///   where the user has the same access as before, not one computed anew
///   from the time of the start;
/// - a restore gives the user who is identified what was bought on the
///   device. Whether it takes them away from another user is up to the
///   backend of each provider, so no test relies on it.
///
/// In an app with the [AuthRole], the tests also rely on `appSession`, which
/// tells `appPurchases` of a change of its user before the call of the
/// session that made the change completes.
final class PurchasesRole extends Role<RoleImplementation> {
  const PurchasesRole._();

  /// The path of the file with `PurchasesService`, which the provider
  /// implements.
  static const serviceFile = 'lib/core/purchases/purchases_service.dart';

  /// The path of the file with `appPurchases`, which the code of the app
  /// uses.
  static const controllerFile = 'lib/core/purchases/app_purchases.dart';

  /// The path of the file with `RestorePurchasesSetting`, the entry of the
  /// settings screen, which only an app with the [SettingsScreenRole] has.
  /// So it is no file of the [interface] of the role: the provider of the
  /// settings screen creates the entry, and no other code names it.
  static const settingFile =
      'lib/core/purchases/restore_purchases_setting.dart';

  /// The heading of the section of the README of the app in which the
  /// template tells how the app sells premium access. The section of a
  /// provider can refer to it.
  static const readmeHeading = 'Purchases';

  /// A user with premium access: the condition that a route asks for when
  /// its screen is only for such a user ([Route.conditions]).
  ///
  /// A module that requires the role stands for the condition with a guard
  /// ([RouteGuard.condition]) of the stage [GuardStage.identity], whose
  /// function returns `appPurchases.hasPremium` from a file of that module,
  /// as a module with the screens of sign-in does for [AuthRole.account].
  /// In an app without such a guard, the routes that ask for it show to
  /// every user.
  static const premium = RouteCondition(purchasesRole, 'premium');

  /// The step by hand in which the developer of the app sets up payments in
  /// both stores: the agreements, the bank account and the taxes that the
  /// stores ask for before an app sells anything. Every provider that sells
  /// in the stores needs it, so the step is of the role.
  static const storeAgreementsStep = ManualStep(
    ManualStepId.role(purchasesRole, 'store_agreements'),
    'Set up payments in App Store Connect and Google Play Console',
  );

  /// The step by hand in which the developer of the app creates in both
  /// stores the products that the plans of the app sell.
  static const storeProductsStep = ManualStep(
    ManualStepId.role(purchasesRole, 'store_products'),
    'Create the products of your plans in App Store Connect and Google Play '
    'Console',
  );

  /// The title of the entry of the settings screen, a text of the template
  /// of the role in an app with a settings screen.
  static const restoreTitle = LocalizedText(
    'restoreTitle',
    en: 'Restore purchases',
    translations: {'uk': 'Відновити покупки'},
  );

  /// What the entry shows when a restore found premium access.
  static const restoreActive = LocalizedText(
    'restoreActive',
    en: 'Your premium access is back.',
    translations: {'uk': 'Преміум-доступ відновлено.'},
  );

  /// What the entry shows when a restore found nothing.
  static const restoreNone = LocalizedText(
    'restoreNone',
    en: 'No purchases to restore.',
    translations: {'uk': 'Немає покупок для відновлення.'},
  );

  /// What the entry shows when a restore failed.
  static const restoreFailed = LocalizedText(
    'restoreFailed',
    en: "Couldn't restore purchases. Try again.",
    translations: {'uk': 'Не вдалося відновити покупки. Спробуйте ще раз.'},
  );

  /// The implementation of `PurchasesService`, which the template renders
  /// from the provider's [RoleImplementation]; modules do not contribute to
  /// it.
  static const implementations = SocketRef<CodeSocket>.role(
    purchasesRole,
    'implementations',
    CodeSocket(),
  );

  @override
  String get id => 'purchases';

  @override
  String get description => 'Purchases';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  /// The sign-in, whose user the purchases belong to, the settings screen,
  /// to which the template gives the entry that restores purchases, and the
  /// languages of the app, in which that entry shows its texts.
  @override
  Set<Role> get uses => {authRole, settingsScreenRole, localizationRole};

  @override
  List<SocketRef> get sockets => const [implementations];

  @override
  RoleInterface get interface => const RoleInterface(
        files: [serviceFile, controllerFile],
      );

  @override
  RoleTemplate<RoleImplementation> get template => const _PurchasesTemplate();

  @override
  List<ModuleRule<RoleImplementation>> get moduleRules =>
      const [_implementationsRule];

  @override
  List<StructuralRule<RoleImplementation>> get structuralRules => const [
        StructuralRule(
          id: 'purchases.factory_calls',
          description: 'No module calls createPurchasesService(), and only '
              'the files of the implementation of the provider import the '
              'file of PurchasesService: the code of the app buys and '
              'restores through appPurchases.',
          check: _checkPurchasesService,
        ),
        StructuralRule(
          id: 'purchases.start_calls',
          description: 'Only bootstrap() calls initPurchases(), and no '
              'module calls appPurchases.start().',
          check: _checkPurchasesStart,
        ),
        StructuralRule(
          id: 'purchases.implementation_factories',
          description: 'The function of every implementation is in its file '
              'and takes no arguments.',
          check: _checkImplementationFactories,
        ),
      ];
}

/// The problems with the service of the provider in [input]; see
/// [_checkServiceReach].
///
/// Code that reached the service would buy around `appPurchases`, which is
/// what tells the service whose purchases count and runs the calls one
/// after another.
List<SmfIssue> _checkPurchasesService(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkServiceReach(
      input,
      factory: 'createPurchasesService',
      service: 'PurchasesService',
      serviceFile: PurchasesRole.serviceFile,
      controllerFile: PurchasesRole.controllerFile,
      hint: 'Buy and restore through appPurchases of '
          '${PurchasesRole.controllerFile}, which also exports the types of '
          'its answers.',
    );

/// The problems with the start of `appPurchases` in [input]; see
/// [_checkControllerStart].
List<SmfIssue> _checkPurchasesStart(
  StructuralRuleInput<RoleImplementation> input,
) =>
    _checkControllerStart(
      input,
      init: 'initPurchases',
      controller: 'appPurchases',
      controllerFile: PurchasesRole.controllerFile,
      hint: 'The role starts the purchases in bootstrap(), before the first '
          'frame. Read the access of the user from appPurchases.',
    );

/// The texts of the entry of the settings screen, each with the variable
/// of its brick that reads it.
const Map<String, LocalizedText> _restoreTexts = {
  'text_title': PurchasesRole.restoreTitle,
  'text_active': PurchasesRole.restoreActive,
  'text_none': PurchasesRole.restoreNone,
  'text_failed': PurchasesRole.restoreFailed,
};

/// What a screen that sells a plan shows, as the App Store and Google Play
/// ask of a subscription, in the section of the role in the README of the
/// app.
const String _storeRules = '''
A screen that sells a plan shows what the App Store and Google Play ask of it:
- the name of the plan, how long a period lasts and what the user gets;
- the full price that the store charges for each period, shown more clearly than any other price on the screen, and for a yearly plan never mainly as a price per month;
- for a free trial or a lower price at first, how long it lasts and the price after it;
- that the plan renews until the user cancels, and how to cancel it in the store;
- a way to restore purchases;
- links to the terms of use and the privacy policy of the app;
- a visible way to close the screen without buying.''';

/// Whose the purchases are in the section of the role in the README of an
/// app, with the [AuthRole] or without it.
String _whosePurchases({required bool auth}) => auth
    ? '''
The purchases belong to the user of `appSession`, by the id of the user: the user of an account, or an anonymous user. While nobody is signed in, they belong to the user of this device. A user who buys before signing up keeps the purchase in the new account, which takes it over from the user of this device, and an anonymous user keeps it when the account takes the id of that user. A user who signs in to an account that exists already leaves the purchases with the user of this device. After a sign-out, the user of this device is a new one, with nothing bought. In both cases a purchase comes back only through a restore, which may also move purchases from another user, as the backend of the provider decides. Without a restore, the next user of the device never gets the purchases of a user who signed out.'''
    : '''
The purchases belong to this installation of the app. On another device, or after the app was installed again, the user restores them.''';

/// Where the user restores purchases in the section of the role in the
/// README of an app, with the [SettingsScreenRole] or without it.
String _whereRestored({required bool settings}) => settings
    ? 'The entry `RestorePurchasesSetting` of the settings screen, in '
        '`${PurchasesRole.settingFile}`, restores purchases.'
    : 'This app has no settings screen, so the screen that sells has to '
        'offer the restore itself.';

/// The section of the role in the README of an app: what `appPurchases`
/// tells and does, what a screen that sells shows, the premium routes,
/// whose the purchases are and where the user restores them, which depend
/// on the roles of the app, and what the app does while purchases are not
/// set up. It holds with every provider and names none.
String _purchasesReadme({required bool auth, required bool settings}) => '''
The app sells premium access through `appPurchases` in `${PurchasesRole.controllerFile}`. Every plan of the current offer gives the same access, whether it renews or the user pays once.

`appPurchases.value` is `NoAccess` or `PremiumAccess`, and `appPurchases.hasPremium` tells which. The app knows it before the first frame, from what the device keeps. `PremiumAccess` tells when the access ends (`expiresAt`, `null` for an access that never ends), whether the plan `renews`, whether the access is a free trial (`inTrial`), and `manageUrl`, the page of the store where the user manages or cancels the plan. `appPurchases.plans()` gives the plans to sell, `appPurchases.purchase(plan)` buys one and returns `false` when the user cancels, and `appPurchases.restore()` gives the user what the store account bought. A call fails only with a `PurchasesFailure`: show a text of the app for its `reason`, and its `developerHint` in debug mode only.

$_storeRules

A screen that only users with premium access may see stands behind a guard of the routes that reads `appPurchases.hasPremium`. Without such a guard, every user gets to it.

${_whosePurchases(auth: auth)} ${_whereRestored(settings: settings)}

Until the provider of purchases has what it needs, such as its keys, the app runs without purchases: `appPurchases.value` stays `NoAccess`, every call fails with the reason `notConfigured`, whose `developerHint` names what is missing, and in debug mode the app prints that hint once.
''';

/// What the role adds to its note in an app with sign-in: whose the
/// purchases are.
const String _whoseAgentNote = '''
- The purchases belong to the user of `appSession`, by `appSession.value.uid`, and to the user of this device while nobody is signed in. A user who buys before signing up keeps the purchase in the new account, which takes it over from the user of this device. A user who signs in to an account that exists already leaves the purchases with the user of this device, and after a sign-out the user of this device is a new one, with nothing bought. A purchase then comes back only through a restore, which may also move purchases from another user, as the backend of the provider decides. The app does not restore on its own: call `appPurchases.restore()` where the user asks for it.
''';

/// What the role adds to its note in an app with a settings screen: the
/// entry that restores purchases, which only such an app has.
const String _restoreAgentNote = '''
- `RestorePurchasesSetting` in `${PurchasesRole.settingFile}`, an entry of the settings screen, restores purchases on a tap and shows what it found.
''';

/// The template of the [PurchasesRole]: the files of the role, the
/// implementation of the provider and the start of the purchases in
/// `bootstrap()`, the entry of the settings screen with its texts, the
/// section of the role in the README of the app, its notes for coding
/// agents and its steps by hand.
final class _PurchasesTemplate extends _ServiceTemplate<RoleImplementation> {
  const _PurchasesTemplate();

  @override
  Role<RoleImplementation> get role => purchasesRole;

  @override
  MasonBundle get bundle => purchasesRoleBundle;

  @override
  String get file => PurchasesRole.controllerFile;

  @override
  String get service => 'PurchasesService';

  @override
  String get factory => 'createPurchasesService';

  @override
  String get initFunction => 'initPurchases';

  @override
  String get variable => '_purchasesService';

  @override
  SocketRef<CodeSocket> get implementations => PurchasesRole.implementations;

  /// The note of the role in the guide for coding agents: what the access
  /// of the user is and where a screen reads it, how the app buys and
  /// restores and shows a failure, what a screen that sells shows, how a
  /// premium screen is kept from the other users, what the app does while
  /// purchases are not set up, and which functions of the role are not for
  /// the code of the app.
  @override
  String get agentNote => '''
- `appPurchases` in `$file` tells whether the user has premium access, and knows it before the first frame. Its `value` is `NoAccess` or `PremiumAccess`, and `appPurchases.hasPremium` is the `ValueListenable<bool>` that widgets and guards of the routes read. Every plan gives the same premium access. The app has one controller, so create no other `AppPurchasesController`.
- `appPurchases.plans()` gives the plans to sell, each a `Plan` with its `price`, its `period` (`null` for a plan paid once) and its `introOffer`. `appPurchases.purchase(plan)` returns `false` when the user cancels, which is no failure, and `appPurchases.restore()` gives the user what the store account bought. A call fails only with a `PurchasesFailure`: show a text of the app for its `reason`, and its `developerHint` in debug mode only. After `pending`, the access arrives later without another call.
- A screen that sells shows the full price of each period most clearly, the length of a free trial and the price after it, that the plan renews until the user cancels, a way to restore purchases, links to the terms of use and the privacy policy, and a visible way to close it, as the App Store and Google Play ask.
- `PremiumAccess.manageUrl` is the page of the store where the user manages or cancels the plan. A screen only for users with premium access stands behind a guard of the routes that reads `appPurchases.hasPremium`. A screen does not redirect itself.
- While the provider lacks what it needs, such as a key, `value` stays `NoAccess` and every call fails with the reason `notConfigured`, whose `developerHint` names what is missing.
- A new provider implements `$service` of `${PurchasesRole.serviceFile}`, and only the files of that implementation import it. The code of the app imports `$file`, which exports the types of the answers, and calls neither `$initFunction()` nor `$factory()` nor `appPurchases.start()`.
''';

  /// The bricks, the entry with its texts, the notes of the role and its
  /// steps by hand. The role registers nothing in a DI container: the code
  /// of an app uses `appPurchases`, not the service of the provider.
  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(bundle),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(agentNote),
        ),
        // Only an app with sign-in tells whose the purchases are.
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(_whoseAgentNote),
          when: const {authRole},
        ),
        // Only an app with a settings screen gets the entry and its texts.
        BrickContribution(
          purchasesRoleSettingBundle,
          when: const {settingsScreenRole},
        ),
        settingsScreenRole.data(
          const SettingsEntry(
            widget: TypeRef(
              'RestorePurchasesSetting',
              import: ImportRef.app(
                'core/purchases/restore_purchases_setting.dart',
              ),
            ),
          ),
        ),
        localizationRole.data(
          TextsData([..._restoreTexts.values]),
          when: const {settingsScreenRole},
        ),
        AppEntryRole.agentSections.entry(
          role.description,
          AgentNote.ofRole(_restoreAgentNote),
          when: const {settingsScreenRole},
        ),
        PurchasesRole.storeAgreementsStep,
        PurchasesRole.storeProductsStep,
      ];

  /// The implementation, `initPurchases()` with the user of the session in
  /// an app with sign-in, the section of the role in the README of the app,
  /// and the code that reads each text of the entry of the settings screen.
  @override
  RoleOutput render(RoleHookInput<RoleImplementation> input) => RoleOutput(
        fragments: [
          ...super.render(input).fragments,
          AppEntryRole.readmeSections.entry(
            PurchasesRole.readmeHeading,
            _purchasesReadme(
              auth: input.has(authRole),
              settings: input.has(settingsScreenRole),
            ),
          ),
        ],
        vars: {
          for (final MapEntry(key: variable, value: text)
              in _restoreTexts.entries)
            variable: localizationRole.expressionOf(
              input,
              const RoleTemplateOrigin(purchasesRole),
              text,
            ),
        },
      );

  /// `bootstrap()` always awaits `initPurchases()`, which also starts
  /// `appPurchases`, whether the implementation is created asynchronously
  /// or not.
  @override
  String bootstrap({required bool hasAsync}) => 'await $initFunction();';

  /// In an app with sign-in, the line of `initPurchases()` in `bootstrap()`
  /// lists the auth role in its condition. The role only uses the auth role,
  /// which gives no edge of the order of the start-up, and the order of the
  /// code of a socket follows the conditions of that code alone. With the
  /// condition, the line comes after the provider and the template of the
  /// auth role, so `appSession` has the user of the device when
  /// `appPurchases` starts, whatever the names of the modules.
  @override
  Set<Role> _bootstrapWhen(RoleHookInput<RoleImplementation> input) =>
      input.has(authRole) ? const {authRole} : const {};

  /// The file of `appSession`, which `initPurchases()` reads in an app with
  /// sign-in.
  @override
  List<ImportRef> _singleImports(RoleHookInput<RoleImplementation> input) =>
      input.has(authRole) ? const [_sessionImport] : const [];

  /// The service of the provider, and `initPurchases()`, which creates it
  /// with the only implementation in [all] and starts `appPurchases` with
  /// it, with the user of `appSession` in an app with sign-in, as [input]
  /// tells.
  ///
  /// It may run again, so the variable is not final.
  @override
  String _single(
    List<_Prefixed> all,
    RoleHookInput<RoleImplementation> input,
  ) {
    final (:implementation, :prefix) = all.single;
    final factory = implementation.factory.codeWith(prefix);
    final create = implementation.isAsync ? 'await $factory()' : '$factory()';
    final start = input.has(authRole)
        ? '''
  await appPurchases.start(
    $variable,
    userId: () => appSession.value.uid,
    userChanges: appSession,
  );'''
        : '  await appPurchases.start($variable);';
    return '''
late $service $variable;

/// Creates the service of the provider of purchases and starts
/// [appPurchases] with it; `bootstrap()` awaits it before the first frame,
/// and nothing else in the app calls it.
///
/// It may run again, as a test does to see what the next launch of the app
/// finds: it creates the service anew, with what the store and the provider
/// kept, and starts [appPurchases] with it.
Future<void> $initFunction() async {
  $variable = $create;
$start
}''';
  }
}

/// The file of `appSession`, the session of an app with sign-in, as code
/// imports it.
const _sessionImport = ImportRef.app('core/auth/app_session.dart');
