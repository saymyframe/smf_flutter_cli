// The platform side of Firebase Crashlytics for the tests that continuous
// integration runs in the apps with Firebase Crashlytics: it records what
// reaches it, through the mocks for tests of its package. The mocks of
// Firebase Core come with the tests of firebase_core, which every app with
// Crashlytics has.
import 'package:firebase_crashlytics_platform_interface/test.dart';

import 'firebase_core_mocks.dart';

/// Records what reaches the platform side of Firebase Crashlytics.
final class MockCrashlytics implements TestFirebaseCrashlyticsHostApi {
  /// The errors reported, in their order.
  final List<RecordErrorRequest> errors = [];

  /// The messages added to the log, in their order.
  final List<String> logs = [];

  /// The ids of the user set, in their order.
  final List<String> users = [];

  /// Forgets what reached Crashlytics.
  void clear() {
    errors.clear();
    logs.clear();
    users.clear();
  }

  @override
  Future<void> recordError(RecordErrorRequest request) async =>
      errors.add(request);

  @override
  Future<void> log(String message) async => logs.add(message);

  @override
  Future<void> setUserIdentifier(String identifier) async =>
      users.add(identifier);

  @override
  Future<bool> checkForUnsentReports() async => false;

  @override
  Future<void> crash() async {}

  @override
  Future<void> deleteUnsentReports() async {}

  @override
  Future<bool> didCrashOnPreviousExecution() async => false;

  @override
  Future<void> sendUnsentReports() async {}

  @override
  Future<bool> setCrashlyticsCollectionEnabled(bool enabled) async => enabled;

  @override
  Future<void> setCustomKey(String key, String value) async {}

  // A method that a later version of the package adds fails only if the
  // app calls it.
  @override
  Object? noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Answers the platform side of Firebase Core, with the constants that
/// Crashlytics reads when it starts, and that of Firebase Crashlytics,
/// which records what reaches it in the [MockCrashlytics] returned.
///
/// The binding of the tests must be initialized first.
MockCrashlytics mockFirebaseCrashlytics() {
  mockFirebaseCore(
    pluginConstants: {
      'plugins.flutter.io/firebase_crashlytics': {
        'isCrashlyticsCollectionEnabled': true,
      },
    },
  );
  final crashlytics = MockCrashlytics();
  TestFirebaseCrashlyticsHostApi.setUp(crashlytics);
  return crashlytics;
}
