// A test that continuous integration runs in the apps with the posthog
// module and a router: the listener of the screen that the module gives the
// router records nothing until PostHog started, nor in a build without a
// project token, where PostHog never starts. The router calls its listeners
// whether or not a provider of the analytics started. Once PostHog started,
// the listener records each screen under the full name of its route, the
// fallback start screen as `/`, and not the error screen of the router.
//
// It runs over the mocks of the platform side of PostHog (posthog_mocks.dart
// of the test of the module), which record what reaches PostHog.
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/analytics/posthog_analytics_service.dart';
import 'package:{{app_name}}/core/env/app_env.dart';

import 'posthog_mocks.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test(
      'the listener records nothing until PostHog started, nor without a '
      'project token, and then each screen under the name of its route',
      () async {
    mockPostHog();

    logPostHogScreen('home.home', '/home');
    await Future<void>.delayed(Duration.zero);
    expect(
      postHogDevice.calls,
      isEmpty,
      reason: 'The router calls the listener before PostHog started.',
    );

    if (AppEnv.posthogProjectToken == null) {
      await expectLater(initPostHogAnalytics(), throwsStateError);
      logPostHogScreen('home.home', '/home');
      await Future<void>.delayed(Duration.zero);
      expect(
        postHogDevice.calls,
        isEmpty,
        reason: 'PostHog never starts in a build without a project token.',
      );
      return;
    }
    await initPostHogAnalytics();
    postHogDevice.calls.clear();

    logPostHogScreen('home.home', '/home');
    logPostHogScreen(null, '/');
    logPostHogScreen(null, '/no/such/page?token=secret');
    await Future<void>.delayed(Duration.zero);

    expect(postHogDevice.callsOf('screen'), [
      ['home.home'],
      ['/'],
    ]);
  });
}
