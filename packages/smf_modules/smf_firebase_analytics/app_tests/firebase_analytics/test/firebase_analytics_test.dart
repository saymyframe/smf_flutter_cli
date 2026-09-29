// A test that continuous integration runs in the apps with Firebase
// Analytics, on the real Firebase packages, whose platform side answers
// without a Firebase project: what the analytics service of the module,
// which createFirebaseAnalyticsService() creates, records reaches Firebase
// Analytics.
//
// The app may have other analytics services, which only the tests of their
// own modules know, so the test uses the service of the module rather than
// createAnalyticsService(), which forwards to all of them. It initializes
// Firebase as the start-up of the app does, and runs none of the rest of
// the start-up. The options of Firebase come with the tests of
// firebase_core, which every app with Firebase Analytics has, and the
// matrix sets up the mocks of the platform side of every module of the app
// before the tests, those of Firebase Analytics among them, which record
// what reaches it (firebase_analytics_mocks.dart).
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/analytics/firebase_analytics_service.dart';
import 'package:{{app_name}}/firebase_options.dart';

import 'firebase_analytics_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
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
