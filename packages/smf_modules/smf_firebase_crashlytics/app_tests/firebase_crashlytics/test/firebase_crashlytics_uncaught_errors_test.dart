// A test that continuous integration runs in the apps with Firebase
// Crashlytics, on the real Firebase packages, whose platform side answers
// as their packages for tests let it: the start-up of the app installs the
// handlers of the crash reporting role for the errors that nothing
// catches, and they report those errors to Crashlytics as fatal.
//
// The handlers report to every crash reporter of the app, and what another
// reporter does is known only to the tests of its own module. So the test
// leaves out the errors of the reports that nothing awaits, and checks
// only what reaches Crashlytics: what else the app presents or prints is
// not up to Crashlytics. firebase_crashlytics_test.dart checks that the
// reporter of Crashlytics neither presents nor prints an error. The matrix
// sets up the mocks of the platform side of every module of the app before
// the tests, so the start-up runs whatever other modules the app has; the
// test takes its own mocks of Crashlytics, which record what reaches it.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';

import 'firebase_crashlytics_mocks.dart';

/// Calls [handler], a handler of the errors that nothing catches, and
/// waits for the reports it starts, leaving out the errors of those that
/// fail.
Future<void> _report(void Function() handler) async {
  runZonedGuarded(handler, (error, stackTrace) {});
  await pumpEventQueue();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final onErrorBefore = FlutterError.onError;
  late MockCrashlytics crashlytics;

  setUpAll(() async {
    crashlytics = mockFirebaseCrashlytics();
    // The handler of the errors of Flutter that the start-up finds and
    // that the handler of the role calls first, which by default presents
    // them: here it leaves them out of the output of the test.
    FlutterError.onError = (details) {};
    await bootstrap();
  });

  tearDownAll(() => FlutterError.onError = onErrorBefore);

  setUp(() => crashlytics.clear());

  test('an error that Flutter catches reaches Crashlytics as fatal', () async {
    final details = FlutterErrorDetails(
      exception: StateError('broken in a build'),
      stack: StackTrace.current,
      library: 'the test',
      context: ErrorDescription('while building the test'),
    );

    await _report(() => FlutterError.onError!(details));

    final request = crashlytics.errors.single;
    expect(request.exception, 'Bad state: broken in a build');
    expect(request.reason, 'while building the test');
    expect(request.fatal, isTrue);
  });

  test('an error that nothing catches reaches Crashlytics as fatal', () async {
    await _report(
      () => PlatformDispatcher.instance.onError!(
        StateError('broken later'),
        StackTrace.current,
      ),
    );

    final request = crashlytics.errors.single;
    expect(request.exception, 'Bad state: broken later');
    expect(request.fatal, isTrue);
  });
}
