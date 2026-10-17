// A test that continuous integration runs in the apps with the
// notifications role and the onboarding screen role, whichever modules
// provide them: the step of the onboarding that asks for the permission to
// show notifications, which the template of the notifications role gives
// the onboarding. On a first launch its condition holds, so the onboarding
// shows it, and its action asks for the permission through the provider.
// The condition holds only while the app may not show notifications and
// has not asked, and once the app asked, whatever the user answered, it
// holds no more, also at the next start. The action asks once, and nothing
// while the app may show notifications. And the onboarding of the app has
// the step with these functions.
//
// It knows only the two roles. How a provider of the onboarding shows a
// step, and what its buttons do, is for the test of the onboarding screen
// role. The matrix writes step.dart next to this file, from the data of the
// onboarding screen role of the app: the condition of the step and its
// action. The start-up of the app runs first, as on a device, with the
// mocks of the platform side of every module of the app, which the matrix
// sets up before the tests of each test file (flutter_test_config.dart).
// The test takes what runs a call in real time, what has the app forget
// that it asked and the service of the tests, which scripts what a
// provider answers, from the files of the test of the notifications role,
// which every app with the role has. The tests of the file run in their
// order, and the first looks at the app as the start-up left it, before
// any request. Each expectation gives its reason.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';
import 'package:{{app_name}}/core/onboarding/onboarding_steps.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

import '../notifications_role/notifications_role.dart';
import 'step.dart';

/// Starts appNotifications with [service], as the start-up of the app does
/// with the service of the provider, once the app forgot that it asked.
Future<void> _startWith(WidgetTester tester, ScriptedNotifications service) =>
    inRealTime(tester, 'starting with a service of the test', () async {
      await forgetAsking();
      await appNotifications.start(service);
    });

/// Runs the action of the step in real time, as the button of the step
/// does, and completes once its future completed.
Future<void> _runAction(WidgetTester tester) =>
    inRealTime(tester, 'the action of the step', stepAction);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'on a first launch the onboarding shows the step, whose action asks for '
    'the permission through the provider, and then shows it no more',
    (tester) async {
      await startUp(tester);
      final atStart = stepShows();

      await _runAction(tester);

      expect(
        atStart,
        isTrue,
        reason: 'The mocks of the platform side of a provider start as on a '
            'first launch, as the notifications role says, so the onboarding '
            'shows the step that asks for the permission.',
      );
      expect(
        (appNotifications.permission.value, askedSaved),
        (NotificationPermission.granted, true),
        reason: 'The action of the step asks for the permission, which the '
            'mocks of a provider grant when the app asks, as the role says, '
            'and the app remembers that it asked.',
      );
      expect(
        stepShows(),
        isFalse,
        reason: 'The onboarding does not show the step once the app may show '
            'notifications.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the onboarding shows the step only while the app may not show '
    'notifications and has not asked, and shows it no more once the app '
    'asked, whatever the user answered, also at the next start',
    (tester) async {
      await startUp(tester);
      final refuses = ScriptedNotifications(answer: SystemAnswer.refuses);
      await _startWith(tester, refuses);
      late bool beforeAsking;
      late List<String> callsOfCondition;
      await inRealTime(tester, 'the condition of the step', () async {
        final before = refuses.calls.length;
        beforeAsking = stepShows();
        // A moment for a call that the condition would start.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        callsOfCondition = refuses.calls.sublist(before);
      });
      await _runAction(tester);
      final afterNo = (
        stepShows(),
        appNotifications.permission.value,
        refuses.requests,
        askedSaved,
      );

      // The next start, with what the preferences saved: the app asked.
      late bool atNextStart;
      await inRealTime(tester, 'the next start', () async {
        await initPreferences();
        await appNotifications.start(
          ScriptedNotifications(answer: SystemAnswer.refuses),
        );
        atNextStart = stepShows();
      });

      // A system without a question, whose request opens its settings.
      final withoutQuestion = ScriptedNotifications(
        answer: SystemAnswer.opensSettings,
      );
      await _startWith(tester, withoutQuestion);
      final beforeSettings = stepShows();
      await _runAction(tester);
      final afterSettings = (
        stepShows(),
        appNotifications.permission.value,
        withoutQuestion.requests,
      );

      expect(
        beforeAsking,
        isTrue,
        reason: 'While the app may not show notifications and has not asked, '
            'the onboarding shows the step.',
      );
      expect(
        callsOfCondition,
        isEmpty,
        reason: 'The condition of the step reads the permission that the app '
            'knows, at once: it calls no service.',
      );
      expect(
        afterNo,
        (false, NotificationPermission.denied, 1, true),
        reason: 'The action of the step asks the user once, and once the '
            'user did not allow it, the onboarding shows the step no more: '
            'the app asked, which the preferences remember.',
      );
      expect(
        atNextStart,
        isFalse,
        reason: 'At the next start, the onboarding does not show the step of '
            'an app that asked, though it may still not show notifications.',
      );
      expect(
        (beforeSettings, afterSettings),
        (true, (false, NotificationPermission.denied, 1)),
        reason: 'On a system without a question, the action of the step '
            'opens its settings, and the onboarding shows the step no more, '
            'though the user did not turn the notifications on there yet: '
            'the app asked.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the onboarding does not show the step while the app may show '
    'notifications, and its action asks nothing then',
    (tester) async {
      await startUp(tester);
      final enabled = ScriptedNotifications(enabled: true);
      await _startWith(tester, enabled);
      final shows = stepShows();

      await _runAction(tester);

      expect(
        shows,
        isFalse,
        reason: 'The onboarding does not show the step of an app that may '
            'show notifications, though it never asked.',
      );
      expect(
        (enabled.requests, appNotifications.permission.value),
        (0, NotificationPermission.granted),
        reason: 'The action of the step asks the user nothing while the app '
            'may show notifications.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the onboarding of the app has the step once, with its condition and '
    'its action',
    (tester) async {
      expect(
        [
          for (final step in appOnboardingSteps)
            if (step.showIf == stepShows || step.run == stepAction)
              (step.showIf == stepShows, step.run == stepAction),
        ],
        [(true, true)],
        reason: 'The list of the steps of the onboarding has the step that '
            'asks for the permission once, so the onboarding asks its '
            'condition and calls its action.',
      );
    },
    timeout: timeout,
  );
}
