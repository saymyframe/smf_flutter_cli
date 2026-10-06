// A test that continuous integration runs in the apps with the home module:
// the parts of the screen of the module come in one after another when the
// screen is first shown, once, and then nothing on it moves. In an app that
// asks for less motion, the screen is complete in its first frame.
//
// The test starts the app once, since the start-up of an app may not run
// twice, and shows a new screen of the module over it for each of the two:
// a screen comes in when it is first shown.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'app.dart';
import 'texts.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the parts of the screen of the module come in once, and at once in an '
    'app that asks for less motion',
    (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      // A phone that is tall enough for the whole screen, whose list
      // builds only what is near the part that the user sees.
      tester.view
        ..physicalSize = const Size(400, 2400)
        ..devicePixelRatio = 1;
      await useLanguage(tester, homeTexts.keys.first);
      await startAtHome(tester);
      expect(
        entrance(tester),
        everyElement(1),
        reason: 'Once the screen that the app shows has settled, each of '
            'its parts is there.',
      );

      // A new screen: the first frame has none of its parts yet.
      showNewHome(tester);
      await tester.pump();
      final first = entrance(tester);
      expect(
        first,
        hasLength(7),
        reason: 'The screen has seven parts that come in: the name of the '
            'app with its greeting, the card, the title of the steps, the '
            'three steps and the last line.',
      );
      expect(
        first,
        everyElement(0),
        reason: 'In its first frame, a screen that comes in shows none of '
            'its parts yet.',
      );
      // Half a second later, the first parts are there and the last ones
      // are on their way.
      await tester.pump(const Duration(milliseconds: 500));
      final halfway = entrance(tester);
      expect(
        halfway.first,
        greaterThan(halfway.last),
        reason: 'The parts of the screen come in one after another, from '
            'the top.',
      );
      // pumpAndSettle fails on a screen that never stops moving.
      final frames = await tester.pumpAndSettle();
      expect(
        entrance(tester),
        everyElement(1),
        reason: 'Once the screen has settled, each of its parts is there.',
      );
      expect(
        frames,
        lessThan(20),
        reason: 'The entrance of the screen is over within two seconds.',
      );
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'Once the screen has settled, nothing on it moves.',
      );
      await closeNewHome(tester);

      // An app that asks for less motion.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      showNewHome(tester);
      await tester.pump();
      expect(
        MediaQuery.disableAnimationsOf(tester.element(home)),
        isTrue,
        reason: 'The app asks for less motion.',
      );
      expect(
        entrance(tester),
        List.filled(7, 1.0),
        reason: 'In an app that asks for less motion, the screen is '
            'complete in its first frame.',
      );
      final parts = [
        shown(find.text(appName)),
        text('readyTitle'),
        text('nextTitle'),
        for (final step in steps) shown(find.text(step.code)),
        text('footer'),
      ];
      final atOnce = [for (final part in parts) tester.getRect(part)];
      await tester.pump(const Duration(seconds: 2));
      expect(
        [for (final part in parts) tester.getRect(part)],
        atOnce,
        reason: 'In an app that asks for less motion, each part of the '
            'screen is in its place in the first frame, and stays there.',
      );
      expect(
        tester.binding.transientCallbackCount,
        0,
        reason: 'In an app that asks for less motion, nothing on the screen '
            'moves.',
      );
      expect(
        tester.takeException(),
        isNull,
        reason: 'The screen comes in without an error.',
      );
      await closeNewHome(tester);
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
