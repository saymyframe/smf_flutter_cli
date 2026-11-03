// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it.
//
// goToStart() of the navigation of the router role shows the screen that
// the app starts on in place of the pages that the user was on, and the
// listeners of the screen hear of it once.
//
// NotFoundScreen, the screen of the role for a location that the router
// cannot show (RouterRole.notFoundScreen), shows the cell of the app with
// its symbol and its number, which keep their size with a larger text,
// and its title as a header and one button, in each language of the app.
// It comes in when it is first shown, at once in an app that asks for less
// motion, and fits a small phone with the text at three times its size. The
// test shows a new screen over the app for that, since only a router that
// takes locations from the platform shows it itself.
//
// Such a router shows the screen for a location from the platform that no
// route matches, and for one without a value that its route requires, as
// the page of its error screen, and its button shows the screen that the
// app starts on in place of it. A router that takes no locations from the
// platform has no such location.
//
// It starts the app with main() of lib/main.dart, which the app entry role
// puts into every app, so it applies to a new provider of the role as it
// is. Each expectation gives its reason, which a provider of the role with
// a known bug fails the test with (brokenProviders of the fixture
// registry).
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/core/router/not_found_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';

import 'not_found_of_app.dart';
import 'screens.dart';

/// The screen that the app starts on, as the listeners of the screen hear
/// of it.
const _startScreen = ('fake_feature.home', '/fake_feature');

/// The size of the small phone of the test, and the inset at its top and at
/// its bottom, such as a notch and the bar of the home gesture.
const Size _phone = Size(320, 480);
const double _inset = 40;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// The not-found screen that the user sees, and what it shows of
  /// [matching].
  final screen = find.byType(NotFoundScreen);
  Finder shown(Finder matching) =>
      find.descendant(of: screen, matching: matching);

  /// How much of the not-found screen is shown while it comes in, from 0
  /// to 1: the opacity of what is around the cell of the app on it.
  double entrance(WidgetTester tester) => tester
      .widget<Opacity>(
        find
            .ancestor(
              of: shown(find.text(notFoundCell.symbol)),
              matching: find.byType(Opacity),
            )
            .first,
      )
      .opacity;

  /// Whether a navigator of the app that the user sees can close a route.
  bool canClose(WidgetTester tester) => tester
      .stateList<NavigatorState>(find.byType(Navigator))
      .any((navigator) => navigator.canPop());

  /// Shows a new not-found screen over the app, on the navigator at its
  /// root, without a transition of the route, so that its first frame is
  /// the first frame of the screen as it comes in; [close] takes it away
  /// again. With [textScale], the screen gets the text at that size,
  /// whatever the root of the app does with the size that the device asks
  /// for.
  void showNew(WidgetTester tester, {double? textScale}) => unawaited(
    tester
        .state<NavigatorState>(find.byType(Navigator).first)
        .push(
          PageRouteBuilder<void>(
            pageBuilder: (context, animation, secondaryAnimation) =>
                textScale == null
                ? const NotFoundScreen()
                : MediaQuery(
                    data: MediaQuery.of(
                      context,
                    ).copyWith(textScaler: TextScaler.linear(textScale)),
                    child: const NotFoundScreen(),
                  ),
            transitionDuration: Duration.zero,
            reverseTransitionDuration: Duration.zero,
          ),
        ),
  );
  Future<void> close(WidgetTester tester) async {
    Navigator.of(tester.element(screen)).pop();
    await tester.pumpAndSettle();
  }

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'goToStart() shows the screen that the app starts on, and the not-found '
    'screen of the router role shows for a location that the router cannot '
    'show, in the language of the app, and leads there',
    (tester) async {
      addTearDown(tester.view.reset);
      addTearDown(tester.platformDispatcher.clearAllTestValues);
      await startApp(tester);
      expect(
        heard(),
        [_startScreen],
        reason: 'The first screen is heard of once.',
      );

      // goToStart() from a page pushed over a child of the screen that the
      // app starts on.
      tester
          .element(find.byType(FixtureHomeScreen))
          .nav
          .fakeFeature
          .details(id: 1)
          .go();
      await tester.pumpAndSettle();
      unawaited(details(tester, 1).nav.fakeFeature.details(id: 2).push());
      await tester.pumpAndSettle();
      expect(
        heard(),
        [
          ('fake_feature.details', '/fake_feature/details/1'),
          ('fake_feature.details', '/fake_feature/details/2'),
        ],
        reason: 'go() and push() each show their location.',
      );
      appRouter.navigatorOf(details(tester, 2)).goToStart();
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'goToStart() throws nothing.',
      );
      expect(
        heard(),
        [_startScreen],
        reason: 'goToStart() shows the screen that the app starts on, which '
            'the listeners hear of once.',
      );
      expect(
        find.byType(FixtureDetailsScreen, skipOffstage: false),
        findsNothing,
        reason: 'goToStart() shows the screen that the app starts on in '
            'place of the pages that the user was on.',
      );
      expect(
        canClose(tester),
        isFalse,
        reason: 'goToStart() shows the screen that the app starts on in '
            'place of the pages that the user was on, so no page is below '
            'it.',
      );

      // A new not-found screen over the app: it comes in, in its first
      // frames.
      showNew(tester);
      await tester.pump();
      expect(
        entrance(tester),
        0,
        reason: 'In its first frame, a not-found screen that comes in is not '
            'shown yet.',
      );
      final frames = await tester.pumpAndSettle();
      expect(
        entrance(tester),
        1,
        reason: 'Once the not-found screen has settled, it is there.',
      );
      expect(
        frames,
        lessThan(20),
        reason: 'The not-found screen comes in within two seconds.',
      );
      expect(
        heard(),
        isEmpty,
        reason: 'A screen that code pushes past the router is no page of the '
            'router, which the listeners hear of.',
      );

      // The cell of the app, which is a picture.
      for (final (part, text) in [
        ('symbol', notFoundCell.symbol),
        ('number', notFoundCell.number),
      ]) {
        expect(
          shown(find.text(text)),
          findsOneWidget,
          reason: 'The not-found screen shows the cell of the app with its '
              '$part, $text.',
        );
      }
      expect(
        find.bySemanticsLabel(notFoundCell.symbol),
        findsNothing,
        reason: 'The cell of the app is a picture, which a screen reader '
            'passes over.',
      );

      // Its texts, in each language of the app.
      for (final language in notFoundLanguages) {
        await chooseLanguage(language);
        await tester.pumpAndSettle();
        final texts = notFoundTexts[language]!;
        final title = shown(find.text(texts.title));
        expect(
          title,
          findsOneWidget,
          reason: 'The not-found screen shows its title in the language of '
              'the app, $language.',
        );
        expect(
          tester.getSemantics(title),
          isSemantics(label: texts.title, isHeader: true, namesRoute: true),
          reason: 'The title of the not-found screen is a header that names '
              'the screen for a screen reader, in $language.',
        );
        final action = shown(find.text(texts.action));
        expect(
          action,
          findsOneWidget,
          reason: 'The not-found screen shows the label of its button in the '
              'language of the app, $language.',
        );
        expect(
          tester.getSemantics(action),
          isSemantics(
            label: texts.action,
            isButton: true,
            hasTapAction: true,
          ),
          reason: 'The button of the not-found screen is one button with its '
              'label for a screen reader, in $language.',
        );
      }

      await close(tester);

      // A small phone with insets, and the text at three times its size.
      const insets = FakeViewPadding(top: _inset, bottom: _inset);
      tester.view
        ..physicalSize = _phone
        ..devicePixelRatio = 1
        ..padding = insets
        ..viewPadding = insets;
      showNew(tester, textScale: 3);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The not-found screen fits a small phone with a large text '
            'size.',
      );
      expect(
        MediaQuery.textScalerOf(tester.element(screen)).scale(10),
        30,
        reason: 'The not-found screen gets the text at three times its size.',
      );
      for (final text in [notFoundCell.symbol, notFoundCell.number]) {
        expect(
          MediaQuery.textScalerOf(tester.element(shown(find.text(text)))),
          TextScaler.noScaling,
          reason: 'The cell of the app is a picture, so "$text" in it keeps '
              'its size when the text of the device is larger.',
        );
      }
      final texts = notFoundTexts[notFoundLanguages.last]!;
      expect(
        MediaQuery.textScalerOf(
          tester.element(shown(find.text(texts.title))),
        ).scale(10),
        15,
        reason: 'The title of the not-found screen grows at most by half.',
      );
      final button = shown(find.text(texts.action));
      await tester.ensureVisible(button);
      await tester.pumpAndSettle();
      expect(
        button.hitTestable(),
        findsOneWidget,
        reason: 'The button of the not-found screen comes into view on a '
            'small phone, where a tap reaches it.',
      );
      expect(
        tester.getRect(button).bottom,
        lessThanOrEqualTo(_phone.height - _inset),
        reason: 'The button of the not-found screen is above the inset at the '
            'bottom of the phone.',
      );
      await close(tester);
      tester.view.reset();
      await tester.pumpAndSettle();

      // In an app that asks for less motion, a new not-found screen is there
      // in its first frame.
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          const FakeAccessibilityFeatures(disableAnimations: true);
      await tester.pumpAndSettle();
      showNew(tester);
      await tester.pump();
      expect(
        entrance(tester),
        1,
        reason: 'In an app that asks for less motion, the not-found screen is '
            'there in its first frame.',
      );
      await close(tester);
      tester.platformDispatcher.clearAccessibilityFeaturesTestValue();
      await tester.pumpAndSettle();
      expect(
        heard(),
        isEmpty,
        reason: 'The screen below the not-found screens that code pushed and '
            'closed is no other page of the router.',
      );

      // A location from the platform that no route matches: the router shows
      // the not-found screen at that location, or takes no locations from
      // the platform and stays where it is.
      const unmatched = '/no/such/screen';
      await tester.binding.handlePushRoute(unmatched);
      await tester.pumpAndSettle();
      final onUnmatched = heard();
      if (onUnmatched.isEmpty) {
        expect(
          find.byType(FixtureHomeScreen),
          findsOneWidget,
          reason: 'A router that takes no locations from the platform stays '
              'where it is.',
        );
        expect(
          screen,
          findsNothing,
          reason: 'A router that takes no locations from the platform has no '
              'location that it cannot show.',
        );
        return;
      }
      expect(
        onUnmatched,
        [(null, unmatched)],
        reason: 'The not-found screen is heard of once, with no route, at the '
            'location that no route matches.',
      );
      expect(
        screen,
        findsOneWidget,
        reason: 'For a location from the platform that no route matches, the '
            'router shows the not-found screen of the router role.',
      );

      // A location from the platform without a value that its route
      // requires, the id of the child, which is no number.
      const withoutValue = '/fake_feature/details/abc';
      await tester.binding.handlePushRoute(withoutValue);
      await tester.pumpAndSettle();
      expect(
        heard(),
        [(null, withoutValue)],
        reason: 'The not-found screen is heard of once, with no route, at the '
            'location without a value that its route requires.',
      );
      expect(
        screen,
        findsOneWidget,
        reason: 'For a location from the platform without a value that its '
            'route requires, the router shows the not-found screen of the '
            'router role.',
      );

      // Its button.
      await tester.tap(shown(find.byType(InkWell)));
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The button of the not-found screen throws nothing.',
      );
      expect(
        heard(),
        [_startScreen],
        reason: 'The button of the not-found screen shows the screen that the '
            'app starts on, which the listeners hear of once.',
      );
      expect(
        screen,
        findsNothing,
        reason: 'The button of the not-found screen shows the screen that the '
            'app starts on in place of it.',
      );
      expect(
        canClose(tester),
        isFalse,
        reason: 'The button of the not-found screen shows the screen that the '
            'app starts on in place of it, so no page is below that screen.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
