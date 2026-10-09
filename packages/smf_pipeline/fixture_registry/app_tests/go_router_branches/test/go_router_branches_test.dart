// A test of what only go_router does, which continuous integration runs in
// the apps of the fixture modules with go_router, a layout and both fixture
// features: go_router keeps the pages of the branches of the main
// navigation, and the navigators that show them, under keys of the route
// of the main navigation, for as long as a page of that route is in the
// widget tree. So a go() out of the main navigation and back in one turn
// would bring the pages of the branches back, and one that comes back while
// the transition is on its way would have those keys in the tree twice,
// which Flutter throws for (https://github.com/flutter/flutter/issues/148768).
// The router of the module gives go_router a new route for the main
// navigation each time the main navigation leaves its pages, so the main
// navigation that comes back is a new one, with each branch on its
// destination, and the page that took its place stays as it is. What the
// target of a guard does to the branches under any router is tested in
// layout_guards. It uses what the tests of router_screens share, which
// every app that it applies to has.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:{{app_name}}/core/layout/app_shell.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_outside_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_second_screen.dart';

import 'screens.dart';

/// The start screen of the app, as the listeners of the screen hear of it.
const _startScreen = ('fake_feature.home', '/fake_feature');

/// The destination of the second fixture feature, as the listeners of the
/// screen hear of it.
const _secondScreen = ('fake_second.second', '/fake_second');

/// The page outside the main navigation of the second fixture feature, as
/// the listeners of the screen hear of it.
const _outsideScreen = ('fake_second.outside', '/fake_second/outside');

/// The main navigations in the tree, the one that a page covers too.
Finder _shells() => find.byType(AppShell, skipOffstage: false);

/// The state in which go_router keeps the pages of the branches of the
/// main navigation that the user sees.
State _branchesOf(WidgetTester tester) =>
    tester.state(find.byType(StatefulNavigationShell));

/// The index of the destination of the second fixture feature, by its
/// label in the language of the app, which is English on the device of a
/// test.
int _secondOf(WidgetTester tester) {
  final context = tester.element(_shells());
  final second = tester.widget<AppShell>(_shells()).destinations.indexWhere(
        (destination) => destination.label(context) == 'Second',
      );
  expect(second, isNonNegative, reason: 'The AppShell has Second.');
  return second;
}

/// Shows a page in the branch of each destination, as a push shows it, and
/// leaves the second destination selected. It starts in the main
/// navigation on the screen that the app starts on, with each branch on
/// its destination. The test does not wait for a push(), which could keep
/// it waiting forever.
Future<void> _pushInEachBranch(WidgetTester tester) async {
  final home = tester.element(find.byType(FixtureHomeScreen));
  unawaited(home.nav.fakeFeature.details(id: 3).push<Object?>());
  await tester.pumpAndSettle();
  tester.widget<AppShell>(_shells()).onSelect(_secondOf(tester));
  await tester.pumpAndSettle();
  final second = tester.element(find.byType(FixtureSecondScreen));
  unawaited(second.nav.fakeFeature.details(id: 7).push<Object?>());
  await tester.pumpAndSettle();
  expect(
    heard(),
    [
      ('fake_feature.details', '/fake_feature/details/3'),
      _secondScreen,
      ('fake_feature.details', '/fake_feature/details/7'),
    ],
    reason: 'The pages that push() shows in the branches, and a switch to '
        'another destination, are heard of once each.',
  );
}

/// Checks that the user is on the screen that the app starts on, in a main
/// navigation other than the one of [before], whose branches are on their
/// destinations; [when] says what happened before, for the reasons of the
/// expectations.
Future<void> _expectNewMainNavigation(
  WidgetTester tester, {
  required State before,
  required String when,
}) async {
  expect(
    _shells(),
    findsOneWidget,
    reason: '$when The user is in the main navigation again.',
  );
  expect(
    find.byType(FixtureHomeScreen),
    findsOneWidget,
    reason: '$when The user is on the screen that go() was asked for.',
  );
  expect(
    _branchesOf(tester),
    isNot(same(before)),
    reason: '$when go_router keeps the pages of the branches of the main '
        'navigation that comes back in a state of its own, as for a new '
        'route.',
  );
  expect(before.mounted, isFalse, reason: '$when The one that left is gone.');
  expect(
    find.byType(FixtureDetailsScreen, skipOffstage: false),
    findsNothing,
    reason: '$when The main navigation comes back with each branch on its '
        'destination.',
  );
  tester.widget<AppShell>(_shells()).onSelect(_secondOf(tester));
  await tester.pumpAndSettle();
  expect(
    heard(),
    [_secondScreen],
    reason: '$when The main navigation comes back with each branch on its '
        'destination, the one that was selected when it left too.',
  );
  // Back on the screen that the app starts on, for the next step.
  tester.element(_shells()).nav.fakeFeature.home().go();
  await tester.pumpAndSettle();
  expect(heard(), [_startScreen], reason: 'go() to a destination shows it.');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the main navigation that comes back is a new one, with each branch on '
    'its destination, at whatever time it comes back',
    (tester) async {
      await startApp(tester);
      expect(heard(), [_startScreen]);

      // Out of the main navigation, to the page outside it, and the page
      // stays as it is when the router gives go_router its new routes.
      await _pushInEachBranch(tester);
      var before = _branchesOf(tester);
      tester.element(_shells()).nav.fakeSecond.outside().go();
      await tester.pumpAndSettle();
      expect(
        heard(),
        [_outsideScreen],
        reason: 'The page that takes the place of the main navigation is '
            'heard of once: new routes leave the pages as they are.',
      );
      expect(_shells(), findsNothing);
      final outside = tester.element(find.byType(FixtureOutsideScreen));
      // And back once the transition is over, which go_router has always
      // shown as a new main navigation.
      outside.nav.fakeFeature.home().go();
      await tester.pumpAndSettle();
      expect(heard(), [_startScreen]);
      await _expectNewMainNavigation(
        tester,
        before: before,
        when: 'The main navigation left, and came back after the transition.',
      );

      // Out and back in one turn: go_router shows the page outside the main
      // navigation for no frame.
      await _pushInEachBranch(tester);
      before = _branchesOf(tester);
      final context = tester.element(_shells());
      final out = context.nav.fakeSecond.outside();
      final back = context.nav.fakeFeature.home();
      out.go();
      back.go();
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'A main navigation that comes back in the turn in which it '
            'left is the only one in the tree.',
      );
      expect(
        heard().last,
        _startScreen,
        reason: 'The user is on the screen that the last go() was asked for.',
      );
      await _expectNewMainNavigation(
        tester,
        before: before,
        when: 'The main navigation left and came back in one turn.',
      );

      // Out, and back while the transition to the page outside the main
      // navigation is on its way: the page of the main navigation that left
      // is still in the tree.
      await _pushInEachBranch(tester);
      before = _branchesOf(tester);
      tester.element(_shells()).nav.fakeSecond.outside().go();
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(heard(), [_outsideScreen]);
      expect(
        before.mounted,
        isTrue,
        reason: 'The page of the main navigation that left is in the tree '
            'while the transition to the page that took its place is on its '
            'way. Otherwise the steps below test nothing.',
      );
      tester
          .element(find.byType(FixtureOutsideScreen))
          .nav
          .fakeFeature
          .home()
          .go();
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'A main navigation that comes back while the one that left '
            'is still in the tree has keys of its own: Flutter finds none '
            'of them twice.',
      );
      expect(heard(), [_startScreen]);
      await _expectNewMainNavigation(
        tester,
        before: before,
        when: 'The main navigation left, and came back while the transition '
            'was on its way.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
