// The platform side of shared_preferences for the tests that continuous
// integration runs in the apps with the module: the preferences in memory
// that the package has for tests, in place of the storage of a device. The
// matrix sets it up before the tests of every module of such an app
// (MatrixAppTest.mocks), so that any of them may run the start-up of the
// app, which opens the preferences.
import 'package:shared_preferences_platform_interface/in_memory_shared_preferences_async.dart';
import 'package:shared_preferences_platform_interface/shared_preferences_async_platform_interface.dart';

/// Keeps what shared_preferences saves in memory, empty at first: it lasts
/// as long as the tests of a test file, and each open of the preferences
/// reads it, as each launch of the app reads the storage of a device.
void mockSharedPreferences() {
  SharedPreferencesAsyncPlatform.instance =
      InMemorySharedPreferencesAsync.empty();
}
