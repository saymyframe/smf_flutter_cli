import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_sentry/src/readme.dart';
import 'package:smf_sentry/src/sentry_module.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the crash reporting: where Sentry starts, what its start does
/// with the handlers of the errors, what the code of the app must not do
/// with Sentry, and the hook of the tests.
final String agentNote = '''
With `sentry_flutter`:

- `initSentryCrashReporter()` in `$reporterFile` starts Sentry with `${SentryModule.dsnKey.name}` of `${EnvRole.dotEnvFile}`, and `${AppEntryRole.bootstrap.name}()` awaits it. Without a value of the key, the app starts without Sentry.
- Report through `CrashReporter`, not through `Sentry.captureException`. Never call `SentryFlutter.init` elsewhere: its start removes `OnErrorIntegration` and puts `FlutterError.onError` back, so that each error reaches Sentry once.
- The environment of an event is the flavor of the build (`appFlavor`), and a debug build sends its events too.
- `configureSentryForTests` changes the options of Sentry before it starts, for tests only: a test keeps the events in `beforeSend` and gives Sentry a `transport` that sends nothing. `SentryFlutter.init` never completes in the fake time of a widget test, so a test starts Sentry, or runs `${AppEntryRole.bootstrap.name}()`, in real time.
''';
