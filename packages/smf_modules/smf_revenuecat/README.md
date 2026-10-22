# smf_revenuecat

The SMF module of [RevenueCat](https://www.revenuecat.com) with [purchases_flutter](https://pub.dev/packages/purchases_flutter). It provides the purchases role of SMF: the app sells its premium access with the plans of the current offering of a RevenueCat project, restores it on another device, and knows before its first frame whether the user has it.

The purchases role generates `appPurchases`, through which the code of the app buys and restores, and the `PurchasesService` interface. This module adds `purchases_flutter` to the app and implements the interface on `Purchases`. The premium access is the entitlement `premium` in RevenueCat, which every product of the current offering unlocks, and a plan of the app is a package of that offering.

The public API keys of RevenueCat go into `.env` of the app, through the env role, which the module requires: `REVENUECAT_APPLE_KEY`, `REVENUECAT_GOOGLE_KEY` and `REVENUECAT_TEST_KEY`. A debug build takes the key of the Test Store of RevenueCat when you fill it in, so you buy a plan right after generating the app with nothing but a RevenueCat account. A profile or release build takes the key of the store of the platform, since RevenueCat stops such a build that is configured with a key of the Test Store. While the key that a build takes is empty, the app runs without purchases and never calls RevenueCat. The README of the app tells how to set up RevenueCat, and its section "Finish the setup" lists the steps that you do by hand in RevenueCat and in the stores.

## Use with the SMF CLI

`smf create` asks which module provides the purchases of the app, and offers none as well. To choose this one without the question:

```bash
smf create my_app -m revenuecat
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The revenuecat module](https://doc.saymyframe.com/modules/revenuecat)
