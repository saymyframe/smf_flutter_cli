// A test that continuous integration runs in the apps with Firebase
// Analytics, on the real Firebase packages, whose platform side answers
// without a Firebase project: what the analytics service of the module,
// which createFirebaseAnalyticsService() creates, records reaches Firebase
// Analytics.
//
// The app may have other analytics services, whose platform side only the
// tests of their own modules know, so the test uses the service of the
// module rather than createAnalyticsService(), which forwards to all of
// them. It initializes Firebase as the start-up of the app does, and runs
// none of the rest of the start-up. The options and the mocks of Firebase
// Core come with the tests of firebase_core, which every app with Firebase
// Analytics has.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/analytics/firebase_analytics_service.dart';
import 'package:{{app_name}}/firebase_options.dart';

import 'firebase_analytics_mocks.dart';
import 'firebase_core_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    mockFirebaseCore();
    mockFirebaseAnalytics();
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  });

  setUp(analyticsCalls.clear);

  test('the analytics service of the module reaches Firebase Analytics',
      () async {
    final analytics = createFirebaseAnalyticsService();

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
