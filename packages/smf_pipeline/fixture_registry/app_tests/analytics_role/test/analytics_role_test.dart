// A test of the analytics role that continuous integration runs in the app
// with every module of the registry of several providers, whichever
// modules provide the role there: the analytics service of the app,
// createAnalyticsService(), forwards each call to every analytics service
// once. An analytics service that throws as it is called, or whose call
// fails, keeps no other from the call, and its failure does not reach the
// code that called: an app that does not await its analytics would get it
// as an error that nothing catches. One that changes the map of parameters
// that it gets changes nothing that the caller or another service has.
//
// It looks only at what reaches the fixture providers of the role: the
// service log of the fixtures, which notes each call and misbehaves when
// the test says so, and the fixture analytics, through its platform side.
// The service log is created with the app, and the fixture analytics
// starts asynchronously, so it comes after the log among the analytics
// services of the app. What another analytics service, such as Firebase
// Analytics, does with a call, only the tests of its own module know. The
// matrix sets up the mocks of the platform side of every module of the app
// before the tests, so the start-up runs whatever other modules the app
// has.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/analytics/analytics_service.dart';
import 'package:{{app_name}}/core/fixture_service_log/fixture_service_log.dart';

import 'analytics_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // What reached the platform side of the fixture analytics: each call as
  // its method and its arguments.
  final fixtureCalls = <List<Object?>>[];

  setUpAll(() async {
    recordFixtureAnalytics(fixtureCalls);
    final (failure, _) = await runStartUp();
    expect(failure, isNull, reason: 'The app starts.');
  });

  setUp(() {
    fixtureCalls.clear();
    loggedAnalyticsCalls.clear();
  });

  tearDown(() {
    serviceLogFailure = ServiceLogFailure.none;
    serviceLogChangesParameters = false;
  });

  test(
      'the analytics service of the app forwards each call to every '
      'analytics service once', () async {
    final analytics = createAnalyticsService();

    await analytics.logEvent('smf_test', parameters: {'count': 1});
    await analytics.logSignIn(method: 'email');
    await analytics.logSignUp(method: 'email', parameters: {'plan': 'free'});
    await analytics.setAnalyticsCollectionEnabled(false);
    await analytics.setUserId('user-1');
    await analytics.setUserProperty(name: 'plan', value: null);

    const once = 'Each call reaches every analytics service once, in the '
        'order of the calls.';
    expect(
      loggedAnalyticsCalls,
      [
        [
          'logEvent',
          'smf_test',
          {'count': 1},
        ],
        ['logSignIn', 'email', null],
        [
          'logSignUp',
          'email',
          {'plan': 'free'},
        ],
        ['setAnalyticsCollectionEnabled', false],
        ['setUserId', 'user-1'],
        ['setUserProperty', 'plan', null],
      ],
      reason: once,
    );
    expect(
      fixtureCalls,
      [
        [
          'logEvent',
          {
            'name': 'smf_test',
            'parameters': {'count': 1},
          },
        ],
        [
          'logSignIn',
          {'method': 'email', 'parameters': null},
        ],
        [
          'logSignUp',
          {
            'method': 'email',
            'parameters': {'plan': 'free'},
          },
        ],
        [
          'setAnalyticsCollectionEnabled',
          {'enabled': false},
        ],
        [
          'setUserId',
          {'userId': 'user-1'},
        ],
        [
          'setUserProperty',
          {'name': 'plan', 'value': null},
        ],
      ],
      reason: once,
    );
  });

  for (final (failure, how) in [
    (ServiceLogFailure.throwing, 'throws as it is called'),
    (ServiceLogFailure.failing, 'returns a future that fails'),
  ]) {
    test(
        'an analytics service that $how keeps no other from the call, and '
        'its failure does not reach the code that called', () async {
      serviceLogFailure = failure;
      Object? failed;

      final printed = await printedBy(() async {
        failed = await failureOf(
          () => createAnalyticsService().logEvent('smf_test'),
        );
      });

      expect(
        fixtureCalls,
        [
          [
            'logEvent',
            {'name': 'smf_test', 'parameters': null},
          ],
        ],
        reason: 'Every other analytics service gets the call once.',
      );
      expect(
        loggedAnalyticsCalls,
        [
          ['logEvent', 'smf_test', null],
        ],
        reason: 'The service log gets the call once.',
      );
      expect(
        failed,
        isNull,
        reason: 'The failure of one analytics service does not reach the '
            'code that called the analytics service of the app.',
      );
      expect(
        printed.where((line) => line.contains('The service log failed on')),
        hasLength(1),
        reason: 'In debug mode, the analytics service of the app prints each '
            'failure of an analytics service, once.',
      );
    });
  }

  test(
      'an analytics service that changes the map of parameters that it gets '
      'changes nothing that the caller or another analytics service has',
      () async {
    serviceLogChangesParameters = true;
    final analytics = createAnalyticsService();
    final event = <String, Object>{'count': 1};
    final signIn = <String, Object>{'via': 'link'};
    final signUp = <String, Object>{'plan': 'free'};

    await analytics.logEvent('smf_test', parameters: event);
    await analytics.logSignIn(method: 'email', parameters: signIn);
    await analytics.logSignUp(method: 'email', parameters: signUp);

    expect(
      fixtureCalls,
      [
        [
          'logEvent',
          {
            'name': 'smf_test',
            'parameters': {'count': 1},
          },
        ],
        [
          'logSignIn',
          {
            'method': 'email',
            'parameters': {'via': 'link'},
          },
        ],
        [
          'logSignUp',
          {
            'method': 'email',
            'parameters': {'plan': 'free'},
          },
        ],
      ],
      reason: 'Every other analytics service gets the parameters of the '
          'caller, whatever the service log does with the map it got.',
    );
    expect(
      [event, signIn, signUp],
      [
        {'count': 1},
        {'via': 'link'},
        {'plan': 'free'},
      ],
      reason: 'The maps of the caller stay as they were.',
    );
  });
}
