// A test that continuous integration runs in the apps with the sign-in
// module: on a small phone with the text at three times its size, the
// title of a page of the sign-in and the labels of its buttons keep whole
// the words of texts with a hyphen, two spaces in a row, a line break, a tab
// or a no-break space, as a translation or the label of a way to sign in
// from another module may have them. The check of whole words of the tests
// of the module (whole_words.dart) takes such texts, though a line may start
// after a hyphen or a line break, and it still sees a line that starts
// inside a word or at a no-break space. The test shows a page alone, with a
// button that submits and an action that leads to the other screen, in the
// theme of Flutter, without starting the app, and each expectation gives its
// reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/sign_in/sign_in_page.dart';
import 'package:{{app_name}}/features/sign_in/sign_in_widgets.dart';

import 'whole_words.dart';

/// The text size of the device on the small phone of the test: three times
/// the usual one.
const double _textScale = 3;

/// Texts that a title or a label may have, each as the title of the page
/// and as the labels of its buttons. At the size of the page, a line of the
/// first starts after the hyphen of "e-mail", and the third has a word
/// after its line break that the line does not fit. The fourth has a
/// no-break space, which keeps its words together, the fifth a tab before
/// its longest word, and the last a line break, a tab, two spaces and
/// no-break spaces.
const _texts = [
  'Turn on Wi-Fi, e-mail будь-коли',
  'Ok  now',
  'Line one\nUnbreakablewordhere',
  'Walk 10\u00A0kilometres',
  'Name:\tUnbreakablewordhere',
  'Every\nday\tor  \$29.99\u00A0/\u00A0year',
];

void main() {
  testWidgets(
    'the title of a page and the labels of its buttons keep whole the '
    'words of a text with a hyphen, two spaces, a line break, a tab or a '
    'no-break space on a small phone with a large text size, and the check '
    'of whole words takes such a text and sees a word broken inside',
    (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      tester.view
        ..physicalSize = const Size(320, 480)
        ..devicePixelRatio = 1;
      tester.platformDispatcher.textScaleFactorTestValue = _textScale;
      for (final text in _texts) {
        await tester.pumpWidget(
          MaterialApp(
            home: AuthPage(
              title: text,
              intro: 'What the page says below its title.',
              children: [
                SubmitButton(label: text, busy: false, onPressed: () {}),
                OtherScreenAction(label: text, onPressed: () {}),
              ],
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text(text),
          findsNWidgets(3),
          reason: 'The page shows its title and the labels of its two '
              'buttons: "$text".',
        );
        final title = find.text(text).first;
        expectWholeWords(
          tester,
          title,
          text,
          what: 'the title',
          language: 'a text of the test',
          // The title is large already, so it grows at most by half.
          largest: Theme.of(tester.element(title))
                  .textTheme
                  .headlineLarge!
                  .fontSize! *
              1.5,
        );
        for (final button in [SubmitButton, OtherScreenAction]) {
          final label = find.descendant(
            of: find.byType(button),
            matching: find.text(text),
          );
          expectWholeWords(
            tester,
            label,
            text,
            what: 'the label of the $button',
            language: 'a text of the test',
            // In the style that the theme gives the button.
            largest: _textScale *
                DefaultTextStyle.of(tester.element(label)).style.fontSize!,
          );
        }
      }

      // A text of Flutter that keeps none of its words whole.
      const word = 'Unbreakablewordhere';
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Center(
            child: SizedBox(
              width: 272,
              child: Text(word, style: TextStyle(fontSize: 14)),
            ),
          ),
        ),
      );
      expect(
        () => expectWholeWords(
          tester,
          find.text(word),
          word,
          what: 'the label',
          language: 'a text of the test',
          largest: _textScale * 14,
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
          what: 'the label',
          language: 'a text of the test',
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
