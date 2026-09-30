// A test of the analytics role that continuous integration runs in the app
// with every module of the registry of several providers, whichever
// modules provide the role there: the factory of an analytics service
// throws, as the factory of a service may whose SDK is not set up. The
// start-up leaves that service out, prints its error in debug mode, and the
// other analytics services work.
//
// The factory of the service log of the fixtures, which the app creates
// with the start-up, throws in this test, and the fixture analytics, which
// starts asynchronously, is the other service that it looks at. The
// analytics services are created once for the tests of this file.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/analytics/analytics_service.dart';
import 'package:{{app_name}}/core/fixture_service_log/fixture_service_log.dart';

import 'analytics_role.dart';

const _bug = 'Bug: an analytics service whose factory throws keeps the app '
    'from starting, and every call of the analytics service of the app '
    'throws.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // What reached the platform side of the fixture analytics: each call as
  // its method and its arguments.
  final fixtureCalls = <List<Object?>>[];
  Object? failure;
  var printed = <String>[];

  setUpAll(() async {
    serviceLogFactoriesThrow = true;
    recordFixtureAnalytics(fixtureCalls);
    (failure, printed) = await runStartUp();
  });

  test(
      'the start-up leaves out an analytics service whose factory throws, '
      'and prints its error once in debug mode', () {
    expect(
      failure,
      isNull,
      reason: 'The app starts without the analytics service.',
    );
    expect(
      printed.where(
        (line) =>
            line.contains('createServiceLogAnalytics()') &&
            line.contains('The service log could not be created.'),
      ),
      hasLength(1),
      reason: 'In debug mode, the start-up prints the error of the factory '
          'once, with the name of the factory.',
    );
  }, skip: _bug);

  test('the other analytics services get each call', () async {
    final failed = await failureOf(
      () => createAnalyticsService().logEvent('smf_test'),
    );

    expect(failed, isNull, reason: 'The call does not fail.');
    expect(
      fixtureCalls,
      [
        [
          'logEvent',
          {'name': 'smf_test', 'parameters': null},
        ],
      ],
      reason: 'The fixture analytics gets the call.',
    );
    expect(
      loggedAnalyticsCalls,
      isEmpty,
      reason: 'The service log, which the start-up left out, gets nothing.',
    );
  }, skip: _bug);
}
