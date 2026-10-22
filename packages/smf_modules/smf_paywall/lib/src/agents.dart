import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_paywall/src/paywall_module.dart';

/// The heading of the section of the module in the guide for coding agents
/// of the app.
const agentHeading = 'Paywall';

/// The note of the module in the guide for coding agents, in every app with
/// the module: where its screens are and what shows and closes them, how to
/// sell from a button, which files are the look and which the state, where
/// the plans get their words and a failure its text, what the links need
/// in `.env`, whose a purchase made before a sign-in is, and what a widget
/// test minds while a call is on its way.
///
/// What a router does with a guard of the routes is for the router role to
/// tell, and what `appPurchases` does is for the purchases role: each has
/// a section of its own in the guide of every app with the module.
final String agentNote = '''
- The paywall is `PaywallScreen`, the route `paywall.paywall` at `/paywall`, in `lib/features/paywall/`. The screen of the subscription is `SubscriptionScreen`, the route `paywall.subscription` at `/paywall/subscription`, which asks for the condition `PurchasesRole.premium`. The guard `paywall.hasPremium` of `${RouterRole.routeGuards}` stands for it, with `paywallHasPremium()` of `lib/features/paywall/paywall_guards.dart`, which returns `appPurchases.hasPremium`.
- No screen of the paywall closes itself or navigates after a purchase or a restore. The access changes, and the router closes the paywall and shows the route that was asked for. To sell from a button, navigate to a route that needs premium access, such as `context.nav.paywall.subscription().push<void>()`. For a user without the access, the router opens the paywall over the page first. A route of your own needs the access when a module lists `PurchasesRole.premium` in its `conditions`, or when its full name is among the `routes` of `paywall.hasPremium` in `${RouterRole.routeGuards}`.
- Never push `/paywall` for a user with premium access: the flow of the guard is over, so the router shows the screen that the app starts on.
- The look and the state are in different files. The look is `PaywallView` of `lib/features/paywall/paywall_view.dart` and `SubscriptionView` of `lib/features/paywall/subscription_view.dart`, with the widgets of `lib/features/paywall/paywall_widgets.dart` and the card of `lib/features/paywall/paywall_card.dart`. They are plain Flutter widgets: a view gets the state and callbacks, and imports nothing that manages state. Its state is a `PaywallState` of `lib/features/paywall/paywall_state.dart`, which stays busy after a purchase or a restore for as long as the user has premium access.
- The benefits on the paywall are texts of the module, `benefitAll`, `benefitNew` and `benefitSupport`: change them to what your premium access gives.
- A plan gets its name, the suffix of its price and the length of its intro offer in `lib/features/paywall/paywall_texts.dart`, from the `period` of the plan and of its `introOffer`. A text has no parameters, so the file has a text for each period that the stores have, and the price is the one that the store gives. A failure gets its text in `failureTextOf()` there, which has a text for every `PurchasesFailureReason`, and `PaywallMessage` shows the `developerHint` of a failure in debug mode only.
- `lib/features/paywall/paywall_links.dart` reads the addresses of the terms of use and of the privacy policy from `${PaywallModule.termsKey.name}` and `${PaywallModule.privacyKey.name}` of `${EnvRole.dotEnvFile}`, and opens a link with `url_launcher`. While a value is empty, the paywall leaves its link out, but for the terms of use on iOS, which lead to the standard license agreement of Apple, and a debug build names the key in a note for the developer.
- In an app with sign-in, a user may buy before signing in. A sign-up keeps the purchase in the new account, while a sign-in to an account that exists already leaves it with the user of the device until a restore.
- While a purchase is on its way, and after one that gave premium access, the button spins, and so does the link of a restore. A widget test that waits with `pumpAndSettle()` returns only once the router closed the paywall, so until then it shows frames with `pump()`.
''';

/// What the note of the module adds in an app whose screens keep their
/// state in cubits: where the state of a screen is, which file gives it the
/// purchases of the app, and how a widget reads the access of the user.
const blocAgentNote = '''
- The state of each screen is a cubit in a file next to it: `PaywallCubit` and `SubscriptionCubit`. The screen provides its cubit and builds its view from the state. A cubit takes the purchases through its constructor, so a test creates one with an `AppPurchasesController` of its own. `lib/features/paywall/paywall_composition.dart` creates the cubits with `appPurchases`.
- A widget reads the access of the user with `context.watch<PremiumCubit>().state`, an `AppAccess`. The root of the app provides the `PremiumCubit` of `lib/features/paywall/premium_cubit.dart`, which follows `appPurchases`.
''';

/// What the note of the module adds in an app whose screens keep their
/// state in providers: where the state of the paywall is, which provider
/// gives it the purchases of the app, and how a widget reads the access of
/// the user.
const riverpodAgentNote = '''
- The state of the paywall is `paywallProvider` of `lib/features/paywall/paywall_notifier.dart`, with its `Notifier`, which lasts as long as the paywall. It buys through `appPurchasesProvider` of `lib/features/paywall/purchases_provider.dart`, which a test overrides with an `AppPurchasesController` of its own, and opens a link with `paywallLinkOpenerProvider` there.
- A widget reads the access of the user with `ref.watch(premiumProvider)`, an `AppAccess`. `premiumProvider` of `lib/features/paywall/purchases_provider.dart` follows `appPurchases`.
''';
