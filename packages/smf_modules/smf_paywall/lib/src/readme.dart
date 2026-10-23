import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_paywall/src/paywall_module.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Paywall';

/// The names of the keys of the module in `.env`.
final String _terms = PaywallModule.termsKey.name;
final String _privacy = PaywallModule.privacyKey.name;

/// The section of the module in the README of the app, which also has the
/// section of the purchases role: where the plans come from, how the app
/// sells from a button and keeps a screen of its own for premium access,
/// what the paywall shows of the rules of the stores, the lengths of intro
/// offers that it names, the values of `.env`, where the benefits are,
/// where the screen of the subscription is reached from, and the step of
/// the onboarding in an app with one.
final String readmeSection = '''
The paywall is at `/paywall`, in `lib/features/paywall/`. It shows the plans of the current offer of the purchases of the app (see the section ${PurchasesRole.readmeHeading}): a card for each plan, with the price that the store gives, how often the plan renews and its free trial or lower price at first. A yearly plan that costs less than twelve months of a monthly plan in the same currency is the best value. The button buys the selected plan, and the paywall restores purchases and links to your terms of use and your privacy policy.

The screen of the subscription, at `/paywall/subscription`, is only for a user with premium access. It shows the plan, when it renews or ends, and a button to the page of the store where the user manages or cancels it. A request for it from a user without the access opens the paywall over the page first. In an app with a settings screen, its entry Subscription leads there. In an app without one, open it from a screen of yours with `context.nav.paywall.subscription().push<void>()`, so that the user finds where to cancel.

No screen of the paywall closes itself or navigates after a purchase. The route `/paywall/subscription` asks for premium access, and the guard `paywall.hasPremium` stands for it: once the user has the access, the router closes the paywall and shows the route. To sell from a button of yours, navigate to a route that needs premium access, as above. To keep a screen of your own for users with the access, list `PurchasesRole.premium` in the `conditions` of its route in a module, or add its full name to the `routes` of `paywall.hasPremium` in `${RouterRole.routeGuards}`. Do not navigate to `/paywall` itself for a user with premium access: the router shows the screen that the app starts on then.

The paywall shows what the App Store and Google Play ask of a screen that sells a plan: the full price of each plan most clearly, the length of a free trial and the price after it right below the button, that the plan renews until the user cancels it in the store, a way to restore purchases, the links to the terms of use and the privacy policy, and a close button that stays in sight. A plan paid once says that it is no subscription. The close button is there only when a page is below the paywall, so push `/paywall` rather than go to it: a paywall that `go()` shows alone has no close button.

A text of the app has no parameters, so the paywall names the periods and the lengths of intro offers that the stores have: a plan that renews every week, every 1, 2, 3 or 6 months, or every year, and an intro offer of 3 days, 1 or 2 weeks, 1, 2, 3 or 6 months, or 1 year. A plan of another period shows the title of its product in the store, and an intro offer of another length is a free trial or an introductory price without its length. `lib/features/paywall/paywall_texts.dart` puts these texts together.

The benefits on the paywall are texts of the module, `benefitAll`, `benefitNew` and `benefitSupport`. Change them to what premium access gives in your app. In an app with localization, they are texts of the app, which `lib/features/paywall/paywall_view.dart` reads as `context.l10n.paywallBenefitAll`, `paywallBenefitNew` and `paywallBenefitSupport`: change them where the provider of the localization keeps the texts of the app, in each language. In an app without it, they are the English texts in that file.

Put the addresses of your terms of use and of your privacy policy into `$_terms` and `$_privacy` in `${EnvRole.dotEnvFile}` (see the section ${EnvRole.readmeHeading}). The App Store asks a paywall to link to both. While a value is empty or is no web address, the paywall leaves its link out, but on iOS the terms of use then lead to the standard license agreement of Apple. A debug build shows a note for you at the bottom of the paywall, which names the keys that are empty and what the provider of purchases says is missing, such as its key.

In an app with an onboarding, the onboarding offers premium access on a page of its own, after the pages that ask for permissions, while the user has none. Its button shows the paywall over the onboarding, and the onboarding goes on once the user closes the paywall or buys a plan. Not now goes on without the paywall. The page shows no price: the prices are on the paywall. Its texts are texts of the module too, and you change them the way you change the benefits.

In an app with sign-in, a user may buy before signing in. A sign-up keeps the purchase in the new account, while a sign-in to an account that exists already leaves the purchase with the user of the device until the user restores it.
''';
