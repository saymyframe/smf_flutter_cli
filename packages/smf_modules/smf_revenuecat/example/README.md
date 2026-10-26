# Generate a Flutter app that sells premium access with RevenueCat

`revenuecat` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) with which the app sells its premium access through RevenueCat. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m revenuecat --no-input
```

The module reads the keys of RevenueCat from `.env` through the env role, so `smf create` adds a provider of that role:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding dart_define: the only provider of the env role, which revenuecat requires.
```

The module adds purchases_flutter to the `pubspec.yaml` of the app, and `lib/core/purchases/revenuecat_purchases_service.dart` with the purchases service on `Purchases`. The purchases role adds `lib/core/purchases/app_purchases.dart` with `appPurchases`, which the rest of the app uses. `bootstrap()` starts the purchases before the first frame, so the app knows the access of the user from what the device keeps:

```dart
Future<void> bootstrap() async {
  await initPurchases();
}
```

A screen of the app shows the plans of the current offering of RevenueCat and buys one:

```dart
import 'core/purchases/app_purchases.dart';

Future<void> buyFirstPlan() async {
  final plans = await appPurchases.plans();
  final bought = await appPurchases.purchase(plans.first);
  if (!bought) return; // The user cancelled.
  // appPurchases.value is PremiumAccess now.
}
```

Fill in the public API key of the Test Store of your RevenueCat project under `REVENUECAT_TEST_KEY` in `.env`, and a debug build buys in the Test Store without an account in a store. The README of the app tells how to set up the entitlement `premium` and the offering, and what a release needs.

The documentation has more on [the revenuecat module](https://doc.saymyframe.com/modules/revenuecat).
