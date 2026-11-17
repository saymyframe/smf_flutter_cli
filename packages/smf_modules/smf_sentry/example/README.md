# Generate a Flutter app that reports its crashes to Sentry

`sentry` is the module of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) that reports the errors of the app to Sentry. Choose it with `-m`:

```bash
dart pub global activate smf_flutter_cli
smf create my_app -m sentry --no-input
```

The module reads the DSN of Sentry from `.env` through the env role, so `smf create` adds a provider of that role:

```text
Adding flutter_core: the only provider of the app entry role, which every app needs.
Adding dart_define: the only provider of the env role, which sentry requires.
```

The module adds sentry_flutter to the `pubspec.yaml` of the app, and `lib/core/crash_reporting/sentry_crash_reporter.dart`, which starts Sentry and reports to it. The crash reporting role adds `lib/core/crash_reporting/crash_reporter.dart` with the `CrashReporter` interface, `createCrashReporter()` and `installCrashReporting()`. `bootstrap()` starts Sentry and then installs the reporting:

```dart
Future<void> bootstrap() async {
  await initCrashReporting();
  installCrashReporting();
}
```

Copy the DSN of your Sentry project into `SENTRY_DSN` in `.env`. From then on, the errors of the main isolate that the app does not handle go to Sentry, as fatal. The code of the app reports other errors with `createCrashReporter().recordError(error, stackTrace)`.

The documentation has more on [the sentry module](https://doc.saymyframe.com/modules/sentry).
