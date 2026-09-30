// A test that continuous integration runs in the apps of the fixture
// modules with the fixture services (fake_registrations), whichever module
// provides the DI role: resetDependencies() disposes of the services that
// the container created, with the functions that dispose of them, in the
// reverse order of their registration, and creates no lazy singleton only
// to dispose of it. The fixture services note what those functions do in
// fixtureServiceEvents.
//
// The start-up runs as on a device, with the mocks of the platform side of
// every module of the app, which the matrix sets up before the tests of
// each test file (flutter_test_config.dart).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/di/dependencies.dart';
import 'package:{{app_name}}/core/di/service_locator.dart';
import 'package:{{app_name}}/core/fixture_services/fixture_services.dart';

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as a timer or input and output, does not keep
/// the fake time of the test waiting forever. An error of [action] fails
/// the test, which tester.runAsync would only report to the handler of the
/// errors of Flutter.
Future<void> _inRealTime(
  WidgetTester tester,
  String what,
  Future<void> Function() action,
) async {
  Object? error;
  StackTrace? stackTrace;
  await tester.runAsync(() async {
    try {
      await action();
    } on Object catch (thrown, stack) {
      error = thrown;
      stackTrace = stack;
    }
  });
  if (error != null) fail('$what threw $error\n$stackTrace');
}

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the
/// widget of an error go back to those of the test once it returns, so
/// that flutter_test reports the errors that follow as in any test.
Future<void> _startUp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await _inRealTime(tester, 'bootstrap()', bootstrap);
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'resetting the container disposes of what it created, in the reverse '
    'order of the registrations',
    (tester) async {
      await _startUp(tester);
      // Singletons, created while they were registered.
      final cache = resolve<FixtureCache>();
      final log = resolve<FixtureLog>(instanceName: 'audit');
      fixtureServiceEvents.clear();

      await _inRealTime(tester, 'resetDependencies()', resetDependencies);

      // The backup session, the audit log and the cache, the other way
      // round from their registration. The counter, a lazy singleton that
      // nothing resolved, is neither created nor disposed of.
      expect(fixtureServiceEvents, [
        'close FixtureSession',
        'close FixtureLog',
        'close FixtureCache',
      ]);
      expect(cache.closed, isTrue);
      expect(log.closed, isTrue);

      // Registered again, with the counter resolved: registered last, it is
      // disposed of first.
      fixtureServiceEvents.clear();
      await _inRealTime(tester, 'registering, resolving and resetting',
          () async {
        await registerDependencies();
        resolve<FixtureCounter>();
        await resetDependencies();
      });

      expect(fixtureServiceEvents, [
        'create FixtureCounter',
        'close FixtureCounter',
        'close FixtureSession',
        'close FixtureLog',
        'close FixtureCache',
      ]);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
