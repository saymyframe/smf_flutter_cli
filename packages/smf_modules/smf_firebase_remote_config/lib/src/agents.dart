import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_remote_config/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of remote config: which file is on firebase_remote_config, where
/// a parameter is created, which values of Firebase the app takes, why the
/// app never activates values itself, and what a test of the app needs in
/// place of the platform side of the package.
final String agentNote = '''
With `firebase_remote_config`:

- `FirebaseRemoteConfigService` in `$serviceFile` implements `RemoteConfigService` on `FirebaseRemoteConfig`. In `lib/`, only that file imports the package: other code reads the values through `appRemoteConfig`.
- A parameter that the app reads is created in Firebase Remote Config of the Firebase project of each flavor, with the name and the type of `RemoteValues.defaults`. The section $readmeHeading of the README tells how, and which two APIs of Google the project needs.
- `values` of the service has only the values whose `source` is `ValueSource.valueRemote`: `getAll()` of Firebase has the defaults of the app too. Keep that filter, or a parameter that the project lacks reads a value of Firebase in place of its default.
- `updates` passes on `onConfigUpdated` of Firebase, after which `appRemoteConfig` calls `activate()`. Do not call `activate()`, `fetch()` or `fetchAndActivate()` of the package elsewhere: values that change in the middle of a screen come only through `appRemoteConfig`.
- The package has no platform side for tests. A test that runs `${AppEntryRole.bootstrap.name}()` answers its messages to the platform itself, with `setMockMessageHandler` of `TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger`, on the channels `dev.flutter.pigeon.firebase_remote_config_platform_interface.FirebaseRemoteConfigHostApi.<method>` in the codec of the package, and on the event channel `plugins.flutter.io/firebase_remote_config_updated`. A test of the values alone gives `appRemoteConfig.start()` a service of its own.
''';
