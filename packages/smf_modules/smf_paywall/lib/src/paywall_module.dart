import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_paywall/bundles/paywall_bloc_bundle.dart';
import 'package:smf_paywall/bundles/paywall_bloc_setting_bundle.dart';
import 'package:smf_paywall/bundles/paywall_bundle.dart';
import 'package:smf_paywall/bundles/paywall_riverpod_bundle.dart';
import 'package:smf_paywall/bundles/paywall_riverpod_setting_bundle.dart';
import 'package:smf_paywall/bundles/paywall_setting_bundle.dart';
import 'package:smf_paywall/bundles/paywall_step_bundle.dart';
import 'package:smf_paywall/src/agents.dart';
import 'package:smf_paywall/src/readme.dart';
import 'package:smf_paywall/src/texts.dart';

/// The module of the paywall of the app: a feature with the screen that
/// sells the premium access of the purchases role, and the screen of the
/// subscription, which only a user with that access sees.
///
/// ## The screens
///
/// `PaywallScreen` is at `/` of the module, so its full path is
/// `/paywall`. It shows a card in the colours of Say My Frame with the cell
/// of the app ([SmfNames.elementSymbolOf] and [SmfNames.elementNumberOf]),
/// three benefits, and a card for each plan of the current offer of the
/// provider of the purchases role, with the price that the store gives,
/// the period of the plan and its intro offer. Below the plans are the
/// button that buys the selected plan, what the plan costs after its intro
/// offer, the terms of the store, and the links to restore purchases, to
/// the terms of use and to the privacy policy. Whenever a page is below it,
/// its close button is at the top, outside what scrolls.
///
/// `SubscriptionScreen`, at `/paywall/subscription`, shows what the user
/// has: the plan, when it renews or ends, or that it is for good, and a
/// button to the page of the store where the user manages it. Its route
/// asks for [PurchasesRole.premium], so it is a top-level route of the
/// module, not one below the paywall: a route that asks for a condition is
/// outside the flow of the guards of its module.
///
/// ## The guard
///
/// The module declares the guard [premiumGuard], which stands for
/// [PurchasesRole.premium] with the function `paywallHasPremium()` of
/// `lib/features/paywall/paywall_guards.dart`, which returns
/// `appPurchases.hasPremium`. Its target is the paywall, and it has the
/// stage [GuardStage.identity], since premium access depends on who the
/// user is. It brings the user back ([RouteGuard.resumes]): when the access
/// ends, the user stays the same.
///
/// So the paywall never closes itself after a purchase or a restore, and
/// nothing navigates to it: a request for a route that asks for premium
/// opens the paywall over the page that the user is on, and once the user
/// has the access, the router closes the paywall and shows the route. Code
/// of the app may also push the paywall for a user without the access; the
/// router closes it once the user has it. For a user with the access, the
/// flow of the guard is over, so a request for the paywall shows the screen
/// that the app starts on.
///
/// ## Values of .env
///
/// The module requires the env role for the addresses of the terms of use
/// and of the privacy policy, which the App Store asks a paywall to link
/// to: [termsKey] and [privacyKey]. A link whose value is empty or is no
/// web address is left out, but for the terms of use on iOS, which then
/// lead to the standard license agreement of Apple. A debug build names the
/// keys that are empty in a note for the developer, with what the provider
/// of purchases says is missing.
///
/// ## Look and state
///
/// The look of the screens is the same in every app: the views
/// `PaywallView` and `SubscriptionView` and their widgets, plain Flutter
/// widgets that take the state and callbacks. What keeps the state depends
/// on the module that manages state in the app, so the module has
/// [Variants] of the state management role:
/// - for [blocVariant], a cubit for each screen, which the screen provides,
///   `PremiumCubit` around the root of the app, and a composition file that
///   creates them with `appPurchases`;
/// - for [riverpodVariant], `paywallProvider`, which lasts as long as the
///   paywall, `premiumProvider`, and `appPurchasesProvider`, through which
///   they reach `appPurchases`.
///
/// Each variant adds the package of its state manager with the constraint
/// `any`. The module also adds `url_launcher`, which opens the links of the
/// screens in the browser or the store.
///
/// ## The settings screen
///
/// The module only uses the settings screen role. In an app with a
/// settings screen, it gives the role the entry `SubscriptionSetting`,
/// which shows whether the user has premium access and opens the screen of
/// the subscription. For a user without the access, the router opens the
/// paywall over the settings screen first.
///
/// ## The onboarding
///
/// The module only uses the onboarding screen role. In an app with an
/// onboarding, it gives the role the step [step], of the stage
/// [OnboardingStage.offer], after the steps that ask for permissions. The
/// onboarding shows the step while the user has no premium access
/// (`paywallStepShows()` of `lib/features/paywall/paywall_step.dart`), and
/// its button shows the paywall over the onboarding (`showPaywall()` there):
/// while the onboarding is on, a guard of the routes may keep the router
/// from showing the route of the paywall, so the paywall is a route without
/// a page on the navigator at the root of the app. The router does not
/// close that route once the user has premium access, so `showPaywall()`
/// closes it itself then, and the onboarding goes on once it is closed.
/// The second button of the step goes on without the paywall.
///
/// ## Texts
///
/// The texts of the screens are in English and in Ukrainian. The module
/// only uses the localization role: in an app with the role they are texts
/// of the app, and in an app without it they are English. The texts of the
/// entry are given to the role only in an app with a settings screen, and
/// those of the step only in an app with an onboarding.
final class PaywallModule extends SmfModule {
  /// Creates the module.
  const PaywallModule();

  /// The id of the module.
  static const id = ModuleId('paywall');

  /// The id of the provider of the state management role whose variant of
  /// the screens keeps their state in cubits.
  static const blocVariant = ModuleId('bloc');

  /// The id of the provider of the state management role whose variant of
  /// the screens keeps their state in providers.
  static const riverpodVariant = ModuleId('riverpod');

  /// The name of the guard of the module that stands for
  /// [PurchasesRole.premium]; its full name is `paywall.hasPremium`, after
  /// what it reads.
  static const premiumGuard = 'hasPremium';

  /// The key of the address of the terms of use in `.env`.
  static const termsKey = EnvKey(
    'PAYWALL_TERMS_URL',
    description: 'The address of the terms of use that the paywall links to',
  );

  /// The key of the address of the privacy policy in `.env`.
  static const privacyKey = EnvKey(
    'PAYWALL_PRIVACY_URL',
    description: 'The address of the privacy policy that the paywall links to',
  );

  /// The keys of the module, in the order of `.env`.
  static const List<EnvKey> keys = [termsKey, privacyKey];

  /// The step by hand in which the developer publishes the terms of use
  /// and the privacy policy and fills in their addresses in `.env`.
  static const legalPagesStep = ManualStep(
    ManualStepId(id, 'legal_pages'),
    'Publish your terms of use and privacy policy and put their links into '
    '.env',
  );

  /// The texts of the screens, which every app with the module has: those
  /// of the paywall, with the names, the suffixes of the prices and the
  /// lengths of intro offers for the periods that the stores have, and those
  /// of the screen of the subscription.
  static const TextsData texts = paywallTexts;

  /// The texts of the entry of the settings screen, which only an app with
  /// a settings screen has.
  static const TextsData settingTexts = entryTexts;

  /// The texts of the step of the onboarding, which only an app with an
  /// onboarding has.
  static const TextsData stepTexts = onboardingStepTexts;

  /// The name of the step of the module in the onboarding, `offer`; its
  /// full name is `paywall.offer`.
  static const stepName = 'offer';

  /// The step of the onboarding that offers premium access: it shows while
  /// the user has none, and its button shows the paywall over the
  /// onboarding. Its page has no price, which the paywall shows.
  static const step = OnboardingStep(
    name: stepName,
    stage: OnboardingStage.offer,
    icon: Fragment(
      'Icons.workspace_premium_outlined',
      imports: [ImportRef('package:flutter/material.dart')],
    ),
    title: stepTitle,
    text: stepText,
    action: stepAction,
    later: stepLater,
    run: FunctionRef('showPaywall', import: _step),
    showIf: FunctionRef('paywallStepShows', import: _step),
  );

  /// The name of the route of the paywall, the target of the guard.
  static const _route = 'paywall';

  static const _folder = 'features/paywall';

  /// The file with the function of the guard.
  static const _guards = ImportRef.app('$_folder/paywall_guards.dart');

  /// The file with the functions of the step of the onboarding.
  static const _step = ImportRef.app('$_folder/paywall_step.dart');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'A paywall with the plans of the purchases of the app, '
            'and a subscription screen',
        kind: ModuleKinds.feature,
        requires: {purchasesRole, envRole},
        uses: {localizationRole, settingsScreenRole, onboardingScreenRole},
        variants: Variants(
          role: stateManagementRole,
          // Each variant imports the package of its provider, whose
          // constraint the provider owns.
          byProvider: {blocVariant: _bloc, riverpodVariant: _riverpod},
        ),
      );

  /// The screens with their state in cubits, the cubit with the access of
  /// the user around the root of the app, the entry of the settings screen,
  /// and what the note of the module says of them.
  static List<Contribution> _bloc(ModuleContext context) => [
        BrickContribution(paywallBlocBundle),
        BrickContribution(
          paywallBlocSettingBundle,
          when: const {settingsScreenRole},
        ),
        const PubspecContribution.hosted('flutter_bloc', 'any'),
        // The access of the user, for every widget of the app.
        const SocketContribution.wrap(
          AppEntryRole.rootWrappers,
          Fragment.wrap(
            'BlocProvider(create: (_) => createPremiumCubit(), child: ',
            ')',
            imports: [
              ImportRef(
                'package:flutter_bloc/flutter_bloc.dart',
                show: ['BlocProvider'],
              ),
              ImportRef.app(
                '$_folder/paywall_composition.dart',
                show: ['createPremiumCubit'],
              ),
            ],
          ),
        ),
        AppEntryRole.agentSections.entry(
          agentHeading,
          AgentNote(blocAgentNote),
        ),
      ];

  /// The screens with their state in providers, the entry of the settings
  /// screen, and what the note of the module says of them.
  static List<Contribution> _riverpod(ModuleContext context) => [
        BrickContribution(paywallRiverpodBundle),
        BrickContribution(
          paywallRiverpodSettingBundle,
          when: const {settingsScreenRole},
        ),
        const PubspecContribution.hosted('flutter_riverpod', 'any'),
        AppEntryRole.agentSections.entry(
          agentHeading,
          AgentNote(riverpodAgentNote),
        ),
      ];

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          paywallBundle,
          vars: {
            'app_symbol': SmfNames.dartString(
              SmfNames.elementSymbolOf(context.appName),
            ),
            'app_number': SmfNames.elementNumberOf(context.appName),
            'terms_key': termsKey.name,
            'privacy_key': privacyKey.name,
            ...localizationRole.varsOf(id, texts),
            ...envRole.varsOf(id, keys),
          },
        ),
        const PubspecContribution.hosted('url_launcher', '^6.3.2'),
        routerRole.data(
          const RoutesData(
            [
              Route(
                '/',
                name: _route,
                screen: ScreenRef(
                  'PaywallScreen',
                  import: ImportRef.app('$_folder/paywall_screen.dart'),
                ),
              ),
              // For a user with premium access only. It is shown over the
              // page that the user asked for it on, and it is no route
              // below the paywall: the flow of the guard is the paywall.
              Route(
                '/subscription',
                name: 'subscription',
                screen: ScreenRef(
                  'SubscriptionScreen',
                  import: ImportRef.app('$_folder/subscription_screen.dart'),
                ),
                conditions: [PurchasesRole.premium],
              ),
            ],
            guards: [
              // When the access ends, the user stays the same, so the
              // guard brings the user back.
              RouteGuard(
                name: premiumGuard,
                allows: FunctionRef('paywallHasPremium', import: _guards),
                redirectTo: _route,
                stage: GuardStage.identity,
                condition: PurchasesRole.premium,
              ),
            ],
          ),
        ),
        for (final key in keys) envRole.data(key),
        // Only an app with a settings screen gets the row of the entry and
        // its texts, and only there does the entry apply.
        BrickContribution(
          paywallSettingBundle,
          vars: localizationRole.varsOf(id, settingTexts),
          when: const {settingsScreenRole},
        ),
        localizationRole.data(texts),
        localizationRole.data(settingTexts, when: const {settingsScreenRole}),
        settingsScreenRole.data(
          const SettingsEntry(
            widget: TypeRef(
              'SubscriptionSetting',
              import: ImportRef.app('$_folder/subscription_setting.dart'),
            ),
          ),
        ),
        // Only an app with an onboarding gets the functions of the step and
        // its texts, and only there does the step apply.
        BrickContribution(
          paywallStepBundle,
          when: const {onboardingScreenRole},
        ),
        onboardingScreenRole.data(step),
        localizationRole.data(stepTexts, when: const {onboardingScreenRole}),
        legalPagesStep,
        AppEntryRole.readmeSections.entry(readmeHeading, readmeSection),
        AppEntryRole.agentSections.entry(agentHeading, AgentNote(agentNote)),
        AppEntryRole.agentSections.entry(
          agentHeading,
          AgentNote(stepAgentNote),
          when: const {onboardingScreenRole},
        ),
      ];
}
