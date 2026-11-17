# smf_sentry

The SMF module of [Sentry](https://sentry.io) with [sentry_flutter](https://pub.dev/packages/sentry_flutter). It provides the crash reporting role of SMF: the app reports to Sentry the errors that it does not handle, those that its code reports through its `CrashReporter`, and the native crashes of Android and iOS.

An app can have several modules that provide crash reporting, and the reporter of the app forwards each report to all of them. The handlers of the errors that nothing catches belong to the crash reporting of the app, so the module keeps Sentry from installing its own: each error reaches Sentry once, also next to another crash reporter.

The DSN of the Sentry project goes into `.env` of the app, through the env role, which the module requires: `SENTRY_DSN`. While it is empty, the app starts without Sentry and a debug build prints why. The environment of each event is the flavor of the build, and debug builds send their events too. The README of the app tells what reaches Sentry, what to give the privacy policy of the app, and how to make the stack traces of a release readable: the dSYMs of iOS, the mapping of R8 on Android, and the symbols of a Dart build with `--obfuscate`.

## Use with the SMF CLI

`smf create` asks which modules provide the crash reporting of the app, and the answer may be none. To choose this one without the question:

```bash
smf create my_app -m sentry
```

You don't add this package to an app yourself: `smf create` of the [SMF CLI](https://pub.dev/packages/smf_flutter_cli) puts what the module generates into the app.

SMF generates apps for Flutter 3.44 or newer and Dart 3.12 or newer. It is tested on macOS, Linux and Windows.

## Documentation

- [The sentry module](https://doc.saymyframe.com/modules/sentry)
