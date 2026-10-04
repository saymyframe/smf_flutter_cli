import 'package:smf_contracts/smf_contracts.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the preferences: what holds with the shared_preferences
/// package, which the preferences role leaves to its provider, and what a
/// test of the app needs in place of the platform side of the package.
final String agentNote = '''
With `shared_preferences`:

- In `lib/`, only `lib/core/preferences/shared_app_preferences.dart` imports the package. Other code uses `AppPreferences`.
- A number is read only as the type that it was saved as: `getDouble()` returns `null` for a key with an `int`, and `getInt()` for a key with a `double`.
- In a test that runs `${AppEntryRole.bootstrap.name}()`, first set `SharedPreferencesAsyncPlatform.instance = InMemorySharedPreferencesAsync.empty()`. Without it, opening the preferences throws. Both names are from the package `shared_preferences_platform_interface`: add it as a dev dependency.
''';
