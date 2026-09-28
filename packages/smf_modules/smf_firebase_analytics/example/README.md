# Generate a Flutter app with Firebase Analytics and screen tracking

`firebase_analytics` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that records events and screen views with Firebase Analytics. Choose it with `-m` in a terminal, here with the start screen `home`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home,firebase_analytics
```

It depends on `firebase_core`, which sets up Firebase, and the screen needs a router, so `smf create` adds both:

```text
Adding firebase_core: a dependency of firebase_analytics.
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding go_router: the only provider of the router role, which home requires.
```

The module adds firebase_analytics to the `pubspec.yaml` of the app, and `lib/core/analytics/firebase_analytics_service.dart` with the service on `FirebaseAnalytics.instance`. The analytics role adds `lib/core/analytics/analytics_service.dart` with the `AnalyticsService` interface, with `logEvent`, `logSignIn` and `logSignUp` among its methods, and `createAnalyticsService()`.

With a router, the module gives it `logFirebaseScreenView`, a listener of the screen that the user sees. The router of the app calls it whenever that screen changes, tab switches included:

```dart
final List<void Function(String? route, String location)> _screenListeners = [
  logFirebaseScreenView,
];
```

The listener logs a `screen_view` event named after the full name of the route, such as `home.home`, and leaves out the error screen of the router. Without a router, the app records only the events it logs itself.

The documentation has more on [the firebase_analytics module](https://doc.saymyframe.com/modules/firebase-analytics) and on [Firebase in SMF](https://doc.saymyframe.com/guides/firebase).
