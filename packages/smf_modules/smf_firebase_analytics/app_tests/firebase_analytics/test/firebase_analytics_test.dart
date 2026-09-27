// A test that continuous integration runs in the apps with Firebase
// Analytics, on the real Firebase packages, whose platform side answers
// without a Firebase project: after the start-up of the app, what the
// analytics service of the app records reaches Firebase Analytics.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/analytics/analytics_service.dart';

import 'firebase_analytics_mocks.dart';
import 'firebase_core_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockFirebaseCore();
    mockFirebaseAnalytics();
    await bootstrap();
  });

  setUp(analyticsCalls.clear);

  test('the analytics service of the app reaches Firebase Analytics', () async {
    final analytics = createAnalyticsService();

    await analytics.logEvent('smf_test', parameters: {'count': 1});
    await analytics.logSignIn(method: 'email');
    await analytics.logSignUp(method: 'email');
    await analytics.setUserId('user-1');
    await analytics.setUserProperty(name: 'plan', value: 'free');
    await analytics.setAnalyticsCollectionEnabled(false);

    expect(analyticsCalls, [
      [
        'logEvent',
        {
          'eventName': 'smf_test',
          'parameters': {'count': 1},
        },
      ],
      [
        'logEvent',
        {
          'eventName': 'login',
          'parameters': {'method': 'email'},
        },
      ],
      [
        'logEvent',
        {
          'eventName': 'sign_up',
          'parameters': {'method': 'email'},
        },
      ],
      ['setUserId', 'user-1'],
      ['setUserProperty', 'plan', 'free'],
      ['setAnalyticsCollectionEnabled', false],
    ]);
  });
}
