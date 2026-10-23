# smf_paywall

The SMF module of the paywall of the app. It is a feature: a paywall in the look of SMF, which sells the premium access of the purchases role with the plans of the current offer, and a screen of the subscription, which only a user with that access sees. The module that provides the router renders their routes and asks their guard.

The module keeps no purchases. It requires a module that provides the purchases role, such as `revenuecat`, and reaches it only through `appPurchases`, so the screens are the same whichever module that is.

The paywall is at `/paywall`. A card for each plan shows the price that the store gives, how often the plan renews, and its free trial or lower price at first. Below the plans are the button that buys the selected plan, what the plan costs after its trial, the terms of the store, and the links that restore purchases and lead to the terms of use and the privacy policy. The screen of the subscription, at `/paywall/subscription`, shows the plan, when it renews or ends, and a button to the page of the store where the user manages it.

No screen of the module closes itself after a purchase. A request for a route that needs premium access opens the paywall over the page, and once the user has the access, the router closes the paywall and shows the route. The exception is the paywall that the step of the onboarding shows, described below: the step closes it itself, since the router does not show it. In an app with a settings screen, the entry Subscription leads to the screen of the subscription.

In an app with an onboarding, the module adds a step to it, after the steps that ask for permissions. The step shows while the user has no premium access, and its button shows the paywall over the onboarding. The onboarding goes on once the user closes the paywall or buys a plan. The page of the step shows no price: the prices are on the paywall.

The addresses of the terms of use and of the privacy policy go into `.env` of the app, through the env role, which the module requires: `PAYWALL_TERMS_URL` and `PAYWALL_PRIVACY_URL`. The texts of the screens are in English and in Ukrainian. The state of the screens has a variant for BLoC and one for Riverpod.

## Use with the SMF CLI

`smf create` asks which features the app has. To choose this one without the question, here with BLoC and RevenueCat:

```bash
smf create my_app -m paywall,bloc,revenuecat
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The paywall module](https://doc.saymyframe.com/modules/paywall)
