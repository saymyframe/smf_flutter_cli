# smf_firebase_analytics

The SMF module of [Google Analytics for Firebase](https://firebase.google.com/docs/analytics) with [firebase_analytics](https://pub.dev/packages/firebase_analytics). It provides the analytics role of the SMF module model: the app records what its users do, and the screens they see, in Firebase Analytics.

The analytics role generates `lib/core/analytics/analytics_service.dart`:

- the `AnalyticsService` interface: `logEvent` logs an event with its parameters, `logSignIn` and `logSignUp` log that the user signed in or signed up, `setUserId` and `setUserProperty` describe the user, and clear what they set with `null`, and `setAnalyticsCollectionEnabled` turns the collection of analytics data on or off;
- `createAnalyticsService()`, which returns the analytics service of the app: it forwards every call to the services of all the modules that provide analytics, so an app can record to more than one service.

This module adds `firebase_analytics` to the dependencies of the app and implements the service in `lib/core/analytics/firebase_analytics_service.dart`, on `FirebaseAnalytics.instance`. An event goes to `logEvent` of Firebase Analytics, and a sign-in and a sign-up are its standard `login` and `sign_up` events, with the method in their `method` parameter.

Analytics works on the Firebase app, so the module depends on [smf_firebase_core](https://pub.dev/packages/smf_firebase_core), which comes with it and initializes Firebase in `bootstrap()`. The service is created on first use, without waiting, so the app starts as it would without it. When the app has a module that provides dependency injection, the analytics role registers the service in its container as a lazy singleton, and the code that creates what the screens of a feature need takes it with `resolve` in the composition file of the feature.

## Screen views

When the app has a router, the module gives it a listener of the screen the user sees, which logs a `screen_view` event each time the router tells it that the screen changed: once for each screen the user sees, as it comes on top of the app.

- The first screen of the app is logged, and so is every page that a navigation shows, a page that shows again as the pages above it close, the page on top when it shows another location, such as the details of another item, and the page of the tab, or other branch of the main navigation, that the user switches to, whether it was selected before or not.
- A navigation that puts several pages on a stack at once, such as going to a page whose parents are not on it yet, logs only the page on top; a navigation that leaves the same page on top at the same location logs nothing.
- The `screen_name` of a screen is the full name of its route, after the module and the route, such as `home.home` for the start screen of the `home` feature. A screen that is no route of a module, such as the fallback start screen of an app with no route to start on, or the error screen of the router, is logged under the path of its location, such as `/`: the query of a location that the app cannot show may hold anything, so it is left out.

## Use with SMF CLI

`smf create` asks which modules provide the analytics of the app, and the answer may be none. To choose this one without the question, name it with `-m`; smf_firebase_core comes with it:

```bash
smf create my_app -m firebase_analytics
```

The module adds nothing to the native projects of the app: Firebase Analytics needs no setup of its own besides that of Firebase, which smf_firebase_core runs after generation; see its README.

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_firebase_analytics) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
