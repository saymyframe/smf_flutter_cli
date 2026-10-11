// A test that continuous integration runs in the apps with the onboarding
// module: an app that finds in its preferences that the onboarding is
// finished, as each launch after the user finished it does, goes straight
// to the screen that it starts on, or to the fallback screen of the app
// entry in an app that no route can start, and never builds the onboarding.
//
// Once the onboarding is finished, its route shows the screen that the app
// starts on, whether go(), push() or replace() asks for it, as a link to
// the route does. The router does not build the onboarding then, such a
// push() completes with null, and the onboarding stays finished: nothing
// but its status starts it again.
//
// The onboarding starts again in two cases:
// - the app asks for it, with restart() of its status, which shows the
//   onboarding without a navigation;
// - the preferences that the app opens have it saved as not finished.
//
// It also runs the probe of the module, which the start check runs on a
// device (integration_test/onboarding/probe.dart): without a navigator on
// the screen, the probe says so; with the onboarding finished, it finds no
// problem and leaves the screen as it is; it reports what is saved when
// the app did not restore it; and with the onboarding not finished, it
// goes through the onboarding and finishes it.
//
// The test starts the app once, since the start-up of an app may not run
// twice, and each expectation gives its reason.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/onboarding/onboarding_screen.dart';
import 'package:{{app_name}}/features/onboarding/onboarding_status.dart';

import '../../integration_test/onboarding/probe.dart';
import '../onboarding_mocks.dart';
import 'app.dart';
import 'start_screen.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The app starts with what an earlier launch saved, and nothing else: the
  // mocks of the module do not finish the onboarding for the tests of this
  // file.
  onboardingIsUnderTest = true;

  final onboarding = find.byType(OnboardingScreen);

  /// Skip, the one text button of the first page of the onboarding,
  /// whichever language the app is in.
  final skip = find.descendant(
    of: onboarding,
    matching: find.byType(TextButton),
  );

  /// What the probe of the module finds in the running app, as the start
  /// check runs it: in real time, with a function that waits until the
  /// screen settles.
  Future<List<String>> probe(WidgetTester tester) async {
    var problems = <String>[];
    await inRealTime(
      tester,
      'the probe of the onboarding',
      () async => problems = await probeOnboarding(tester.pumpAndSettle),
    );
    await tester.pumpAndSettle();
    return problems;
  }

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'an app that finds the onboarding finished goes straight to the screen '
    'that it starts on and shows it in place of the route of the '
    'onboarding, the onboarding starts again only when the app asks for '
    'it, and the probe of the module holds whether the onboarding is '
    'finished or not',
    (tester) async {
      // The preferences as a launch opens them, before the app shows
      // anything.
      await inRealTime(tester, 'opening the preferences', initPreferences);
      expect(
        await probe(tester),
        ['No navigator is on the screen to go to the onboarding from.'],
        reason: 'Without a navigator on the screen, the probe of the module '
            'has none to go to the onboarding from, and says so.',
      );

      // What the launch in which the user finished the onboarding saved.
      await inRealTime(
        tester,
        'saving that the onboarding is finished',
        () => createAppPreferences().setBool(completedKey, true),
      );
      expect(
        onboardingStatus.completed.value,
        isFalse,
        reason: 'Before the app starts, nothing has restored that the '
            'onboarding is finished.',
      );
      await startApp(tester);

      expect(
        onboardingStatus.completed.value,
        isTrue,
        reason: 'The start-up of the app restores from the preferences that '
            'the onboarding is finished.',
      );
      expect(
        find.byType(OnboardingScreen, skipOffstage: false),
        findsNothing,
        reason: 'An app that finds the onboarding finished does not build '
            'it.',
      );
      expect(
        find.byType(startScreen),
        findsOneWidget,
        reason: 'An app that finds the onboarding finished goes straight to '
            'the screen that it starts on.',
      );

      expect(
        await probe(tester),
        isEmpty,
        reason: 'With the onboarding finished and saved, the probe of the '
            'module finds no problem.',
      );
      expect(
        find.byType(startScreen),
        findsOneWidget,
        reason: 'With the onboarding finished, the probe of the module '
            'leaves the screen as it is.',
      );

      // A navigation to the route of the onboarding once the onboarding is
      // finished, as a link to it does: the flow of its guard is over, so
      // the router shows the screen that the app starts on, whichever of
      // go(), push() and replace() asks for the route.
      AppNavigator navigator() =>
          appRouter.navigatorOf(tester.element(find.byType(startScreen)));
      Object? pushed = 'not completed';
      final asks = <String, void Function()>{
        'go()': () => navigator().go(const OnboardingOnboardingLocation()),
        'push()': () => unawaited(
              navigator()
                  .push<Object?>(const OnboardingOnboardingLocation())
                  .then((value) => pushed = value),
            ),
        'replace()': () =>
            navigator().replace(const OnboardingOnboardingLocation()),
      };
      for (final MapEntry(key: how, value: ask) in asks.entries) {
        ask();
        await tester.pumpAndSettle();
        expect(
          find.byType(OnboardingScreen, skipOffstage: false),
          findsNothing,
          reason: 'Once the onboarding is finished, $how to its route does '
              'not show the onboarding.',
        );
        expect(
          find.byType(startScreen),
          findsOneWidget,
          reason: 'Once the onboarding is finished, $how to its route shows '
              'the screen that the app starts on.',
        );
        expect(
          onboardingStatus.completed.value,
          isTrue,
          reason: 'A navigation to the route of the onboarding does not '
              'start the onboarding again: after $how, it is still '
              'finished.',
        );
      }
      expect(
        pushed,
        isNull,
        reason: 'push() of the route of the onboarding once it is finished '
            'completes with null, since the router shows no page for it.',
      );
      expect(
        createAppPreferences().getBool(completedKey),
        isTrue,
        reason: 'A navigation to the route of the onboarding saves nothing: '
            'the preferences still have the onboarding as finished.',
      );

      // The app starts the onboarding again, as for a user who asks to see
      // it again.
      await restartOnboarding(tester);
      expect(
        onboarding,
        findsOneWidget,
        reason: 'restart() of the status of the onboarding shows the '
            'onboarding at once, without a navigation.',
      );
      expect(
        find.byType(startScreen, skipOffstage: false),
        findsNothing,
        reason: 'While the onboarding is not finished again, the app shows '
            'no other screen.',
      );
      expect(
        await savedCompleted(tester, expected: false),
        isFalse,
        reason: 'restart() of the status of the onboarding saves that the '
            'onboarding is not finished.',
      );
      expect(
        await probe(tester),
        isEmpty,
        reason: 'With the onboarding not finished, the probe of the module '
            'goes through it and finds no problem.',
      );
      await expectFinished(tester, 'The probe of the module');

      // What is saved changes behind the app, which restores nothing.
      await inRealTime(
        tester,
        'saving that the onboarding is not finished',
        () => createAppPreferences().setBool(completedKey, false),
      );
      expect(
        await probe(tester),
        [contains('the app did not restore what is saved')],
        reason: 'The probe of the module reports that the app has the '
            'onboarding finished while the preferences have it saved as '
            'not finished.',
      );

      // The preferences are opened anew, as the next launch of the app
      // opens them, and the app restores what is saved.
      await inRealTime(tester, 'opening the preferences anew', initPreferences);
      await tester.pumpAndSettle();
      expect(
        onboarding,
        findsOneWidget,
        reason: 'An app that finds the onboarding saved as not finished '
            'shows it.',
      );
      await tester.tap(skip);
      await tester.pumpAndSettle();
      await expectFinished(tester, 'Skip');
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
