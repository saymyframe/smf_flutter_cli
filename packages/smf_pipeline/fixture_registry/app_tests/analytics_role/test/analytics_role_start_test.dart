// A test of the analytics role that continuous integration runs in the app
// with every module of the registry of several providers, whichever
// modules provide the role there: an analytics service that starts
// asynchronously fails to start, as a service does whose platform side is
// broken. The start-up leaves that service out, prints its error in debug
// mode, and the app starts, and the other analytics services work.
//
// The platform side of the fixture analytics fails its start in this test,
// and the service log of the fixtures, which the app creates with the
// start-up, is the other service that it looks at. The analytics services
// are created once for the tests of this file.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/analytics/analytics_service.dart';
import 'package:{{app_name}}/core/fixture_service_log/fixture_service_log.dart';

import 'analytics_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // What reached the platform side of the fixture analytics after its
  // start: each call as its method and its arguments.
  final fixtureCalls = <List<Object?>>[];
  Object? failure;
  var printed = <String>[];

  setUpAll(() async {
    recordFixtureAnalytics(fixtureCalls, failStart: true);
    (failure, printed) = await runStartUp();
  });

  test(
      'the start-up leaves out an analytics service that fails to start, and '
      'prints its error once in debug mode', () {
    expect(
      failure,
      isNull,
      reason: 'The app starts without the analytics service.',
    );
    expect(
      printed.where(
        (line) =>
            line.contains('initFixtureAnalytics()') &&
            line.contains('The fixture analytics does not start.'),
      ),
      hasLength(1),
      reason: 'In debug mode, the start-up prints the error of the start '
          'once, with the name of the function that starts the service.',
    );
  });

  test('the other analytics services get each call', () async {
    final failed = await failureOf(
      () => createAnalyticsService().logEvent('smf_test'),
    );

    expect(failed, isNull, reason: 'The call does not fail.');
    expect(
      loggedAnalyticsCalls,
      [
        ['logEvent', 'smf_test', null],
      ],
      reason: 'The service log gets the call.',
    );
    expect(
      fixtureCalls,
      isEmpty,
      reason: 'The fixture analytics, which the start-up left out, gets '
          'nothing.',
    );
  });
}
