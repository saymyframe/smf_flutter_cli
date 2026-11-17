# smf_in_app_review

The SMF module of store reviews with [in_app_review](https://pub.dev/packages/in_app_review). It provides the review role of SMF: the code of the app calls `appReview.requestIfDue()` at a natural break, such as when the user has finished a task, without knowing the package behind it.

The role decides when a review is due, and this module asks the store for its own review dialog: StoreKit on iOS, the In-App Review API of Google Play on Android. What holds with this provider, as with any other:

- The app asks only where its code calls `appReview.requestIfDue()`. Nothing asks on its own, and the app shows nothing around the dialog.
- A review is due once the app has launched three times and three days have passed since its first launch. It is due at most once per version and once every 14 days, and never in the flow of a guard of the routes, such as the onboarding.
- `appReview.openStorePage()` opens the page of the app in its store. On Android that is the Google Play page for the id of the release flavor, even from a build of another flavor. On iOS it is the App Store page of `REVIEW_APP_STORE_ID` in `.env`.
- In an app with a settings screen, the entry "Rate the app" opens the page for a review. On iOS the entry is hidden while `.env` has no App Store ID.

The module opens a page with `launchUrl` of [url_launcher](https://pub.dev/packages/url_launcher), never with `openStoreListing()` of the package: on Android, that opens the page for the id of the running build. It reads the version of the app with [package_info_plus](https://pub.dev/packages/package_info_plus).

Google Play shows the dialog only in an app that it installed, such as from an internal test track. The README of a generated app tells how to see it there, and what Google Play collects through it.

## Use with the SMF CLI

```bash
smf create my_app -m in_app_review
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The in_app_review module](https://doc.saymyframe.com/modules/in-app-review)
