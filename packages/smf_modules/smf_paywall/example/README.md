# Generate a Flutter app with a paywall

`paywall` is the feature with the paywall of the apps that the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) generates. It sells the premium access of the app with the plans of the current offer, and has a screen of the subscription for a user with that access. Choose it with `-m`, here with BLoC for the state of the screens and RevenueCat for the purchases:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m paywall,bloc,revenuecat --no-input
```

The paywall needs a router, a module that provides the purchases, a module that provides the values in `.env` and a module that manages state. `smf create` adds a module when it is the only one that provides what another one requires, and says which module needs it.

The module writes its files into `lib/features/paywall/`. The route of the screen of the subscription needs premium access, so a button of the app sells by navigating to it:

```dart
FilledButton(
  onPressed: () => context.nav.paywall.subscription().push<void>(),
  child: const Text('Go premium'),
)
```

For a user without premium access, the router opens the paywall over the page first. Once the user has bought a plan, the router closes the paywall and shows the screen of the subscription. A widget reads the access of the user from the cubit that the module puts around the root of the app:

```dart
final premium = context.watch<PremiumCubit>().state is PremiumAccess;
```

Fill in the addresses of your terms of use and of your privacy policy under `PAYWALL_TERMS_URL` and `PAYWALL_PRIVACY_URL` in `.env`. The README of the app tells what the paywall shows and how to change its benefits.

The documentation has more on [the paywall module](https://doc.saymyframe.com/modules/paywall).
