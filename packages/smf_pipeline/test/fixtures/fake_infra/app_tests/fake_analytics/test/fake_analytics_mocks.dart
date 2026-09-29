// The platform side of the analytics of the fixture, for the tests that
// continuous integration runs in the apps with it: the matrix sets it up
// before the tests of every module of such an app (MatrixAppTest.mocks),
// so that any of them may run the start-up of the app, which starts the
// analytics of the fixture, and record what users do with it.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';

/// Answers the platform side of the analytics of the fixture: it starts,
/// and takes everything that the service records.
///
/// The binding of the tests must be initialized first.
void mockFixtureAnalytics() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMethodCallHandler(fixtureAnalyticsChannel, (call) async => null);
}
