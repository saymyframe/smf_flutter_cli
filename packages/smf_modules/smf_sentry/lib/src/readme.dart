import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_sentry/src/sentry_module.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Sentry';

/// The name of the file with the crash reporter of the module.
const reporterFileName = 'sentry_crash_reporter.dart';

/// The path in the app of the file with the crash reporter of the module.
const reporterFile = 'lib/core/crash_reporting/$reporterFileName';

/// The version of the Gradle plugin of Sentry that the section names.
const sentryGradlePluginVersion = '6.27.0';

/// The version of the Dart plugin of Sentry that the section names.
const sentryDartPluginVersion = '3.5.0';

/// The name of the key of the DSN in `.env`.
final String _dsn = SentryModule.dsnKey.name;

/// The file of the values of the app.
const String _env = EnvRole.dotEnvFile;

/// The block of the Gradle plugin of Sentry with which a release build
/// passes without a token, sends nothing and changes no bytecode.
const _gradleBlock = '''
sentry {
    autoUploadProguardMapping.set(providers.environmentVariable("SENTRY_AUTH_TOKEN").isPresent)
    uploadNativeSymbols.set(false)
    telemetry.set(false)
    autoInstallation { enabled.set(false) }
    tracingInstrumentation { enabled.set(false) }
}''';

/// The section of the module in the README of the app: the DSN and the
/// projects of development and of the release, the environment, the debug
/// builds and the line that keeps them out, what reaches Sentry, the native
/// crashes next to another crash reporter, the quota, the three cases of
/// symbols, and what the app sends for its privacy policy.
final String readmeSection = '''
The app reports its errors to [Sentry](https://sentry.io) with [sentry_flutter](https://pub.dev/packages/sentry_flutter). `$reporterFile` starts Sentry in `bootstrap()` with the DSN of `$_dsn` in `$_env`, and implements the crash reporter of the app on it. While `$_dsn` has no value in a build, the app starts without Sentry and reports nothing to it, and a debug build prints why.

Create a Flutter project in Sentry and copy its DSN into `$_dsn`. The section ${AppEntryRole.setupHeading} lists this among the steps that you do by hand. A DSN only lets an app send events to its project, and it goes into the app, where anyone can read it, so it is no secret. In the settings of the project, give the key of the DSN a rate limit, so that one app that fails in a loop does not use up the quota of the organization. Keep a second project for development: its DSN goes into your local `$_env`, and the DSN of the project of the release goes into the values that a build for a store gets, such as those of the environment `${AppEntryRole.releaseFlavor.name}` of your CI.

The environment of each event is the flavor of the build, such as `${AppEntryRole.defaultFlavor.name}` or `${AppEntryRole.releaseFlavor.name}`, so Sentry tells the events of a test build from those of the release. A debug build sends its events too. To keep debug builds out of Sentry, start `initSentryCrashReporter()` with this line:

```dart
if (kDebugMode) throw StateError('Sentry reports nothing from a debug build.');
```

What each start of the app sends to Sentry:

- the errors that the crash reporting of the app reports: those that nothing catches, as fatal, and those that the code reports with `recordError()`, each with the messages of `log()` before it as breadcrumbs and with the id of the user that `setUserId()` set. An error that comes before Sentry has started in `bootstrap()` is not reported;
- the native crashes of Android and iOS, which the SDKs of Sentry for the platforms record and send at the next start, and on Android an app that does not respond (ANR), on iOS an app that hangs;
- a session, from which Sentry counts the users and the starts without a crash.

Next to another crash reporter, both record the native crashes that each of them catches: an uncaught exception of Java or Kotlin reaches both, and a signal of native code on Android may reach Sentry alone. On iOS, another crash reporter may warn in the log that another handler of exceptions is installed, which does no harm. The free plan of Sentry has a monthly quota of errors, which the [pricing](https://sentry.io/pricing/) of Sentry tells.

Without `--obfuscate`, the Dart frames of an event have their functions, files and lines, also in a release build. The other cases need files that a release build writes, uploaded with an auth token of Sentry that may upload debug files, in `SENTRY_AUTH_TOKEN`:

1. The native frames of iOS need the dSYMs of the archive. After `flutter build ipa`, upload them with [sentry-cli](https://docs.sentry.io/cli/installation/):

   ```bash
   sentry-cli debug-files upload --org <org> --project <project> build/ios/archive/Runner.xcarchive/dSYMs
   ```

2. The Java and Kotlin frames of the plugins in an Android release, which R8 shrinks, need its mapping. The Gradle plugin of Sentry uploads it. Add `id("io.sentry.android.gradle") version "$sentryGradlePluginVersion"` to the `plugins` of `android/app/build.gradle.kts`, and this block below them, without which the plugin fails every release build without a token, sends telemetry of its own, and changes the bytecode of every plugin:

   ```kotlin
${_indented(_gradleBlock, 3)}
   ```

3. The Dart frames of a build with `--obfuscate` need its symbols. Build with `--obfuscate --split-debug-info=build/debug-info --extra-gen-snapshot-options=--save-obfuscation-map=build/app/obfuscation.map.json`, add [sentry_dart_plugin](https://pub.dev/packages/sentry_dart_plugin) `^$sentryDartPluginVersion` to the `dev_dependencies`, give the `pubspec.yaml` of the app this block, and run `dart run sentry_dart_plugin`:

   ```yaml
   sentry:
     org: <org>
     project: <project>
     dart_symbol_map_path: build/app/obfuscation.map.json
   ```

For the privacy policy of the app, which the App Store and Google Play ask for in the listing of the app and inside the app: Sentry gets crash and diagnostic data, the id of the user once the code sets one, and the IP address of the device, which Sentry may store unless "Prevent Storing of IP Addresses" is on in the settings of the project. The SDK of Sentry for iOS declares what it collects in its privacy manifest.
''';

/// [text] with [spaces] spaces before each line, for a block of code in an
/// item of a list.
String _indented(String text, int spaces) =>
    text.split('\n').map((line) => '${' ' * spaces}$line').join('\n');
