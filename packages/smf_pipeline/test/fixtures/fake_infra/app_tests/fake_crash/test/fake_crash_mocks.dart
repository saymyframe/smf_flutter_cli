// The platform side of the crash reporting of the fixture, for the tests
// that continuous integration runs in the apps with it: the matrix sets it
// up before the tests of every module of such an app (MatrixAppTest.mocks),
// so that any of them may run the start-up of the app, which starts the
// crash reporting of the fixture, and report errors to it.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_crash/fixture_crash.dart';

/// Answers the platform side of the crash reporting of the fixture: it
/// starts, and takes every report.
///
/// The binding of the tests must be initialized first.
void mockFixtureCrash() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(fixtureCrashChannel, (call) async => null);
}
