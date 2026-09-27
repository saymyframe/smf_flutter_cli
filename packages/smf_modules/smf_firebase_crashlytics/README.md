# smf_firebase_crashlytics

The SMF module of [Firebase Crashlytics](https://firebase.google.com/docs/crashlytics) with [firebase_crashlytics](https://pub.dev/packages/firebase_crashlytics). It provides the crash reporting role of the SMF module model: the app reports to Crashlytics the errors that it does not handle, and those that its code reports.

The crash reporting role generates `lib/core/crash_reporting/crash_reporter.dart`:

- the `CrashReporter` interface: `recordError` and `recordFlutterError` report an error, `log` adds a message to the log sent with the next report, and `setUserId` sets the id of the signed-in user, or clears it with `null`;
- `createCrashReporter()`, which returns the reporter of the app: it forwards every call to the reporters of all the modules that provide crash reporting, so an app can report to more than one service;
- `installCrashReporting()`, which reports as fatal the uncaught errors of the main isolate: those that Flutter catches, which it still presents as it does by default, and the others, which the engine still prints in debug mode.

This module adds `firebase_crashlytics` to the dependencies of the app and implements the reporter in `lib/core/crash_reporting/crashlytics_crash_reporter.dart`, on `FirebaseCrashlytics.instance`:

- an error of Flutter is reported with what `recordFlutterError` of Crashlytics reports, and any other error with `recordError`;
- the reporter prints nothing, since the handlers of the role already show each error: Crashlytics would present each error of Flutter again and, in debug mode, print each report. So an error that the code of the app reports itself is not printed either;
- `setUserId(null)` clears the id of the user with an empty one, as Crashlytics does.

Crashlytics works on the Firebase app, so the module depends on [smf_firebase_core](https://pub.dev/packages/smf_firebase_core), which comes with it: `bootstrap()` initializes Firebase, then calls `installCrashReporting()`. The reporter is created on first use, without waiting. When the app has a module that provides dependency injection, the crash reporting role registers the reporter in its container as a lazy singleton, and the code that creates what the screens of a feature need takes it with `resolve` in the composition file of the feature.

The module adds nothing to the native projects of the app. The setup of Firebase that smf_firebase_core runs after generation sets up the native part of Crashlytics for an app that depends on firebase_crashlytics; see its README.

## Use with SMF CLI

`smf create` asks which modules provide the crash reporting of the app, and the answer may be none. To choose this one without the question, name it with `-m`; smf_firebase_core comes with it:

```bash
smf create my_app -m firebase_crashlytics
```

This package is not intended to be installed directly. Use the SMF CLI to generate a new project and wire modules together.

- SMF Flutter CLI on pub.dev: https://pub.dev/packages/smf_flutter_cli

## 🌐 Links
[Repository](https://github.com/saymyframe/smf_flutter_cli/tree/main/packages/smf_modules/smf_firebase_crashlytics) • [Docs](https://doc.saymyframe.com) • [Issues](https://github.com/saymyframe/smf_flutter_cli/issues)

## License
See LICENSE.
