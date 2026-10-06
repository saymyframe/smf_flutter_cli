// A test that continuous integration runs in the apps with the onboarding
// module: on its first launch, with nothing saved in its preferences, the
// app shows the onboarding in place of the screen that it starts on, which
// it does not build. Next shows the last page, where Done finishes the
// onboarding: the app saves that in its preferences and shows the screen
// that it starts on, or the fallback screen of the app entry in an app
// that no route can start. Skip does the same from the first page. A swipe
// shows the page before or after, and the dots and the buttons follow the
// page. Both pages have their texts in each language of the app, as the
// device asks for it, with their titles as headers for a screen reader,
// and fit a small phone with a large text size and insets in each.
//
// The screen only finishes the onboarding: the router of the app, whichever
// module provides it, leaves the screen, as the router role says of the
// guards of the routes. The matrix writes texts.dart next to this file, the
// texts of the module in each language of the app: the languages of the
// localization role of the app, whichever module provides it, or English
// alone in an app without the role. The test starts the app once, since
// the start-up of an app may not run twice, and each expectation gives its
// reason.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/features/onboarding/onboarding_pages.dart';
import 'package:{{app_name}}/features/onboarding/onboarding_screen.dart';
import 'package:{{app_name}}/features/onboarding/onboarding_status.dart';

import '../../integration_test/onboarding/probe.dart';
import '../onboarding_mocks.dart';
import 'app.dart';
import 'start_screen.dart';
import 'texts.dart';

/// The inset at the top and at the bottom of the small phone of the test,
/// such as a notch and the bar of the home gesture.
const double _inset = 40;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  // The app starts as its first launch finds it: the mocks of the module
  // do not finish the onboarding for the tests of this file.
  onboardingIsUnderTest = true;

  final onboarding = find.byType(OnboardingScreen);

  /// The texts of the onboarding in the language that the device asks for
  /// (see [useLanguage]), each by its name in the module.
  var texts = onboardingTexts.values.first;

  /// What the screen of the onboarding shows of [matching].
  Finder shown(Finder matching) =>
      find.descendant(of: onboarding, matching: matching);

  /// The text of the onboarding with the name [name], on its screen.
  Finder text(String name) => shown(find.text(texts[name]!));

  // The buttons of the onboarding, each by its label in that language.
  Finder skip() => shown(find.widgetWithText(TextButton, texts['skip']!));
  Finder next() => shown(find.widgetWithText(FilledButton, texts['next']!));
  Finder done() => shown(find.widgetWithText(FilledButton, texts['done']!));

  /// Has the device ask for [language], a language of the app, which the
  /// app follows while its user chose none.
  Future<void> useLanguage(WidgetTester tester, String language) async {
    tester.platformDispatcher.localesTestValue = [Locale(language)];
    texts = onboardingTexts[language]!;
    await tester.pumpAndSettle();
  }

  /// The code of the language that the screen of the onboarding is in.
  String languageOf(WidgetTester tester) =>
      Localizations.localeOf(tester.element(onboarding)).languageCode;

  /// The titles of the pages of the onboarding that are built: that of the
  /// page that the user sees.
  List<String> titles(WidgetTester tester) => [
        for (final page in tester.widgetList<OnboardingPage>(
          shown(find.byType(OnboardingPage)),
        ))
          page.title,
      ];

  /// Checks that a screen reader announces [title], the title of the page
  /// that the user sees, as a header.
  void expectHeader(WidgetTester tester, String title) => expect(
        tester.getSemantics(shown(find.text(title))),
        isSemantics(label: title, isHeader: true),
        reason: 'A screen reader announces the title of a page of the '
            'onboarding as a header: $title.',
      );

  /// Checks the dots below the pages while the user sees the page at the
  /// index [page]: one for each of the two pages, with the one of that
  /// page in the primary colour of the theme.
  void expectDots(WidgetTester tester, {required int page}) {
    final colors = Theme.of(tester.element(onboarding)).colorScheme;
    expect(
      [
        for (final container in tester.widgetList<Container>(
          shown(find.byType(Container)),
        ))
          if (container.decoration
              case BoxDecoration(shape: BoxShape.circle, :final color))
            color,
      ],
      [
        for (var index = 0; index < 2; index++)
          index == page ? colors.primary : colors.outlineVariant,
      ],
      reason: 'The onboarding has a dot for each of its pages, with the dot '
          'of the page that the user sees in the primary colour: here the '
          'page ${page + 1} of 2.',
    );
  }

  /// Checks that the pages and [buttons] keep out of the insets of the
  /// small phone of the test.
  void expectOutOfInsets(WidgetTester tester, List<Finder> buttons) {
    final height =
        tester.view.physicalSize.height / tester.view.devicePixelRatio;
    expect(
      tester.getRect(shown(find.byType(PageView))).top,
      greaterThanOrEqualTo(_inset),
      reason: 'The pages of the onboarding are below the inset at the top '
          'of the screen, such as a notch.',
    );
    for (final button in buttons) {
      expect(
        tester.getRect(button).bottom,
        lessThanOrEqualTo(height - _inset),
        reason: 'The buttons of the onboarding are above the inset at the '
            'bottom of the screen, such as the bar of the home gesture.',
      );
    }
  }

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'on its first launch the app shows the onboarding in place of the '
    'screen that it starts on, in the language of the device, until Done '
    'or Skip finishes it',
    (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      final languages = onboardingTexts.keys.toList();
      await useLanguage(tester, languages.first);
      await startApp(tester);

      expect(
        createAppPreferences().getBool(completedKey),
        isNull,
        reason: 'On its first launch, the app has nothing saved of the '
            'onboarding.',
      );
      expect(
        onboarding,
        findsOneWidget,
        reason: 'On its first launch, the app shows the onboarding when it '
            'starts.',
      );
      expect(
        find.byType(startScreen, skipOffstage: false),
        findsNothing,
        reason: 'While the onboarding is not finished, the app does not '
            'build the screen that it starts on.',
      );
      final pages = shown(find.byType(PageView));
      final controller = tester.widget<PageView>(pages).controller!;

      // The first page, as the device asks for each language of the app.
      for (final language in languages) {
        await useLanguage(tester, language);
        expect(
          languageOf(tester),
          language,
          reason: 'The onboarding follows the device into $language, a '
              'language of the app.',
        );
        expect(
          titles(tester),
          [appName],
          reason: 'The first page of the onboarding has the name of the '
              'app, in $language too.',
        );
        expectHeader(tester, appName);
        expect(
          text('welcome'),
          findsOneWidget,
          reason: 'The first page welcomes the user in $language.',
        );
        expect(
          skip(),
          findsOneWidget,
          reason: 'The first page has Skip, in $language.',
        );
        expect(
          next(),
          findsOneWidget,
          reason: 'The first page has Next, in $language.',
        );
        expect(done(), findsNothing, reason: 'Only the last page has Done.');
      }
      await useLanguage(tester, languages.first);
      expectDots(tester, page: 0);

      await tester.tap(next());
      await tester.pumpAndSettle();
      // The last page, in each language of the app too.
      for (final language in languages) {
        await useLanguage(tester, language);
        expect(
          titles(tester),
          [texts['readyTitle']],
          reason: 'Next shows the page after the first, one page at a time, '
              'with its title in $language.',
        );
        expectHeader(tester, texts['readyTitle']!);
        expect(
          text('ready'),
          findsOneWidget,
          reason: 'The last page has its text in $language.',
        );
        expect(
          done(),
          findsOneWidget,
          reason: 'The last page has Done, in $language.',
        );
        expect(next(), findsNothing, reason: 'The last page has no Next.');
        expect(skip(), findsNothing, reason: 'The last page has no Skip.');
      }
      await useLanguage(tester, languages.first);
      expectDots(tester, page: 1);

      // A swipe to the page before, and one to the page after.
      await tester.fling(pages, const Offset(400, 0), 1000);
      await tester.pumpAndSettle();
      expect(
        titles(tester),
        [appName],
        reason: 'A swipe shows the page before the one that the user sees.',
      );
      expectDots(tester, page: 0);
      for (final button in [skip(), next()]) {
        expect(
          button,
          findsOneWidget,
          reason: 'After a swipe to the first page, the onboarding has Skip '
              'and Next again.',
        );
      }
      await tester.fling(pages, const Offset(-400, 0), 1000);
      await tester.pumpAndSettle();
      expect(
        titles(tester),
        [texts['readyTitle']],
        reason: 'A swipe shows the page after the one that the user sees.',
      );
      expectDots(tester, page: 1);
      expect(
        done(),
        findsOneWidget,
        reason: 'After a swipe to the last page, the onboarding has Done.',
      );
      expect(
        onboardingStatus.completed.value,
        isFalse,
        reason: 'Next and a swipe finish nothing.',
      );
      expect(
        createAppPreferences().getBool(completedKey),
        isNull,
        reason: 'Next and a swipe save nothing: an app that is closed in '
            'the middle of the onboarding shows it again.',
      );

      await tester.tap(done());
      await tester.pumpAndSettle();
      await expectFinished(tester, 'Done');
      expect(
        () => controller.addListener(() {}),
        throwsFlutterError,
        reason: 'Once the router has left the onboarding, its screen has '
            'disposed of the controller of its pages.',
      );

      // Skip, from the first page of an onboarding that the app starts
      // again.
      await restartOnboarding(tester);
      expect(
        titles(tester),
        [appName],
        reason: 'An onboarding that starts again shows its first page.',
      );
      await tester.tap(skip());
      await tester.pumpAndSettle();
      await expectFinished(tester, 'Skip');

      // A small phone with insets and the text at three times its size,
      // about the largest that the settings of a device have, in each
      // language of the app, whose texts differ in length.
      for (final language in languages) {
        // The onboarding first, and its language and the small phone then:
        // whether the screen that the app starts on fits such a phone, or
        // another language, is for the tests of its own module.
        await restartOnboarding(tester);
        await useLanguage(tester, language);
        const insets = FakeViewPadding(top: _inset, bottom: _inset);
        tester.view
          ..physicalSize = const Size(320, 480)
          ..devicePixelRatio = 1
          ..padding = insets
          ..viewPadding = insets;
        tester.platformDispatcher.textScaleFactorTestValue = 3;
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'The first page of the onboarding fits a small phone with '
              'a large text size, in $language.',
        );
        for (final button in [skip(), next()]) {
          expect(
            button.hitTestable(),
            findsOneWidget,
            reason: 'Skip and Next are on the screen of a small phone with '
                'a large text size, where a tap reaches them, in $language.',
          );
        }
        expectOutOfInsets(tester, [skip(), next()]);
        await tester.tap(next());
        await tester.pumpAndSettle();
        expect(
          tester.takeException(),
          isNull,
          reason: 'The last page of the onboarding fits a small phone with '
              'a large text size, in $language.',
        );
        expect(
          done().hitTestable(),
          findsOneWidget,
          reason: 'Done is on the screen of a small phone with a large text '
              'size, where a tap reaches it, in $language.',
        );
        expectOutOfInsets(tester, [done()]);
        // The screen and the language of the test again, before the app
        // shows the screen that it starts on.
        tester.view.reset();
        tester.platformDispatcher.clearTextScaleFactorTestValue();
        await useLanguage(tester, languages.first);
        await tester.tap(done());
        await tester.pumpAndSettle();
        await expectFinished(tester, 'Done after a small phone, in $language,');
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
