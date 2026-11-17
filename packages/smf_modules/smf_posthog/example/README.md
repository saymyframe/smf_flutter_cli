# Generate a Flutter app that records its analytics in PostHog

`posthog` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that records events and screens in PostHog. Choose it with `-m`, here with the start screen `home`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m home,posthog --no-input
```

The module reads the project token and the host of PostHog from `.env` through the env role, and the screen needs a router, so `smf create` adds a provider of each:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding go_router: the only provider of the router role, which home requires.
Adding dart_define: the only provider of the env role, which posthog requires.
```

The module adds posthog_flutter to the `pubspec.yaml` of the app, and `lib/core/analytics/posthog_analytics_service.dart`, which starts PostHog and records to it. The analytics role adds `lib/core/analytics/analytics_service.dart` with the `AnalyticsService` interface, with `logEvent`, `logSignIn` and `logSignUp` among its methods, and `createAnalyticsService()`. `bootstrap()` starts PostHog:

```dart
Future<void> bootstrap() async {
  await initAnalytics();
}
```

With a router, the module gives it `logPostHogScreen`, a listener of the screen that the user sees. The router of the app calls it whenever that screen changes, tab switches included:

```dart
final List<void Function(String? route, String location)> _screenListeners = [
  logPostHogScreen,
];
```

Copy the project token of your PostHog project into `POSTHOG_PROJECT_TOKEN` in `.env`, and for EU Cloud its host into `POSTHOG_HOST`. From then on, the listener records a `$screen` event named after the full name of the route, such as `home.home`, and every event has the flavor of the build in `app_flavor`.

The documentation has more on [the posthog module](https://doc.saymyframe.com/modules/posthog).
