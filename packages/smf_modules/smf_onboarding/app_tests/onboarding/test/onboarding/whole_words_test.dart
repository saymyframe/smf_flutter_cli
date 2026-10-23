// A test that continuous integration runs in the apps with the onboarding
// module: on a small phone with the text at three times its size, a page of
// the onboarding keeps whole the words of texts that a step of another
// module may give it, with a hyphen, two spaces in a row, a line break, a
// tab or a no-break space. The check of whole words of the tests of the
// module (whole_words.dart) takes such texts, though a line may start after
// a hyphen or a line break, and it still sees a line that starts inside a
// word or at a no-break space. The test shows the page alone, in the theme
// of Flutter, without starting the app, and each expectation gives its
// reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/onboarding/onboarding_pages.dart';

import 'whole_words.dart';

/// Texts that a step may have, each as the title and as the text of a page.
/// The third has a word after its line break that the line does not fit at
/// the size of the page, the fourth a no-break space, which keeps its words
/// together, and the last a line break, a tab, two spaces and a no-break
/// space.
const _texts = [
  'Turn on Wi-Fi a cd-efg, будь-коли',
  'Ok  now',
  'Line one\nUnbreakablewordhere',
  'Walk 10\u00A0kilometres',
  'Every\nday\tor  \$29.99\u00A0/\u00A0year',
];

void main() {
  testWidgets(
    'a page keeps whole the words of a text with a hyphen, two spaces, a '
    'line break, a tab or a no-break space on a small phone with a large '
    'text size, and the check of whole words takes such a text and sees a '
    'word broken inside',
    (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      tester.view
        ..physicalSize = const Size(320, 480)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = largeTextScale;
      for (final text in _texts) {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: OnboardingPage(icon: Icons.wifi, title: text, text: text),
            ),
          ),
        );
        await tester.pumpAndSettle();
        final shown = find.text(text);
        expect(
          shown,
          findsNWidgets(2),
          reason: 'The page shows its title and its text: "$text".',
        );
        final style = Theme.of(tester.element(shown.first)).textTheme;
        expectWholeWords(
          tester,
          shown.first,
          text,
          what: 'the title',
          language: 'a text of a step',
          largest: style.displaySmall!.fontSize! * 1.5,
        );
        expectWholeWords(
          tester,
          shown.last,
          text,
          what: 'the text',
          language: 'a text of a step',
          largest: pageTextSize * largeTextScale,
        );
      }

      // A text of Flutter that keeps none of its words whole.
      const word = 'Unbreakablewordhere';
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 264,
              child: Text(word, style: TextStyle(fontSize: 18)),
            ),
          ),
        ),
      );
      expect(
        () => expectWholeWords(
          tester,
          find.text(word),
          word,
          what: 'the text',
          language: 'a text of a step',
          largest: pageTextSize * largeTextScale,
        ),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            contains('not inside "$word"'),
          ),
        ),
        reason: 'The check of whole words sees a word that a line breaks '
            'inside.',
      );

      // A text of Flutter whose line breaks at a no-break space, which keeps
      // the words around it together.
      const joined = 'aaaa\u00A0bbbb';
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 50,
              child: Text(
                joined,
                style: TextStyle(fontSize: 10),
                textScaler: TextScaler.noScaling,
              ),
            ),
          ),
        ),
      );
      expect(
        () => expectWholeWords(
          tester,
          find.text(joined),
          joined,
          what: 'the text',
          language: 'a text of a step',
          largest: 10,
        ),
        throwsA(
          isA<TestFailure>().having(
            (failure) => failure.message,
            'message',
            contains('not inside "$joined"'),
          ),
        ),
        reason: 'The check of whole words sees a line that starts at a '
            'no-break space, which keeps the words around it together.',
      );
    },
    timeout: const Timeout(Duration(minutes: 1)),
  );
}
