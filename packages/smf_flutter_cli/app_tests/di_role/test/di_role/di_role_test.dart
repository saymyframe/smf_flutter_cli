// A test that continuous integration runs in the apps with the DI role
// whose modules register services, whichever module provides the role:
// once the start-up of the app ran, every service resolves, a singleton
// and a lazy singleton to one instance; resetDependencies() removes them
// all, and registerDependencies() registers them again.
//
// It knows only the role. The matrix writes registered_services.dart into
// integration_test/di_role/ of the app, with the services of the app from
// the data of its DI role, each resolved with resolve() of the service
// locator of the role, and the probe of the role there, which the start
// check runs on a device, checks the services as this test does. The start-up
// runs as on a device, with the mocks of the platform side of every module
// of the app, which the matrix sets up before the tests of each test file
// (flutter_test_config.dart): some services need the platform services
// that the start-up sets up first.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/di/dependencies.dart';

import '../../integration_test/di_role/probe.dart';
import '../../integration_test/di_role/registered_services.dart';

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

/// The names of the services of the app that resolve.
List<String> _resolving() => [
      for (final service in registeredServices)
        if (_resolves(service)) service.name,
    ];

bool _resolves(RegisteredService service) {
  try {
    service.resolve();
    return true;
  } on Object {
    return false;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the services resolve once the app started, none once the container is '
    'reset, and all once they are registered again',
    (tester) async {
      await _startUp(tester);
      expect(registeredServices, isNotEmpty);

      // The services are created as the app creates them, in real time.
      var problems = <String>[];
      await _inRealTime(tester, 'resolving the services', () async {
        problems = problemsOfResolving();
      });
      expect(problems, isEmpty);

      var resolving = <String>[];
      await _inRealTime(tester, 'resetDependencies()', () async {
        await resetDependencies();
        resolving = _resolving();
      });
      expect(
        resolving,
        isEmpty,
        reason: 'resetDependencies() removes every service.',
      );

      await _inRealTime(tester, 'registerDependencies() again', () async {
        await registerDependencies();
        problems = problemsOfResolving();
      });
      expect(problems, isEmpty);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
