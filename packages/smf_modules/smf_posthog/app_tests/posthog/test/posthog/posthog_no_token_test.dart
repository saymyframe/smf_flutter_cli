// A test that continuous integration runs in the apps with the posthog
// module whose .env has no project token, as an app has right after it is
// generated: the start of PostHog throws an error that names the key and
// reaches nothing of PostHog, and the start-up of the app goes on without
// PostHog and, in a debug build, prints why.
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/analytics/posthog_analytics_service.dart';

import '../posthog_mocks.dart';
import 'posthog.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Without a project token', () {
    setUp(mockPostHog);

    test(
        'the start of PostHog throws an error that names the key, and reaches '
        'nothing of PostHog', () async {
      await expectLater(
        initPostHogAnalytics(),
        throwsA(
          isA<StateError>().having(
            (error) => error.message,
            'message',
            allOf(
              startsWith('POSTHOG_PROJECT_TOKEN has no value in this build'),
              contains('In .env, give it the project token of your PostHog '
                  'project'),
            ),
          ),
        ),
      );
      expect(postHogStarted, isFalse);
      expect(postHogDevice.calls, isEmpty);
    });

    test(
        'the start-up of the app goes on without PostHog, and a debug build '
        'prints why', () async {
      expect(kDebugMode, isTrue);

      final lines = await printed(bootstrap);

      expect(postHogStarted, isFalse);
      expect(postHogDevice.calls, isEmpty);
      expect(
        lines,
        contains(
          startsWith(
            'initPostHogAnalytics() failed, so the app works without it: '
            'Bad state: POSTHOG_PROJECT_TOKEN has no value in this build',
          ),
        ),
      );
    });
  }, skip: hasToken ? withToken : false);
}
