// A test that continuous integration runs in the apps of the fixture
// modules with a router and a layout, whichever modules provide them, and
// with both fixture features: the router puts their destinations into the
// AppShell of the layout role, each with a branch that keeps its stack,
// calls every listener of the screen (RouterRole.screenListeners), here
// those of the fixture analytics and of the fixture screen log, once for
// each switch to another destination too, and gives the navigator of each
// branch observers of its own (RouterRole.observers). It finds a
// destination by the Destination that its feature declares, and selects it
// as the layout does when the user selects it, with onSelect of AppShell,
// so it depends neither on the router nor on how the layout shows the
// destinations. It uses what the tests of router_screens share, which
// every app that it applies to has.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';
import 'package:{{app_name}}/core/fixture_screen_log/fixture_screen_log.dart';
import 'package:{{app_name}}/core/layout/app_shell.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_second_screen.dart';

import 'screens.dart';

/// The main navigation that the user sees.
AppShell _shell(WidgetTester tester) => tester.widget(find.byType(AppShell));

/// The index of the destination labelled [label] with [icon] among those
/// of the main navigation.
int _destination(WidgetTester tester, String label, IconData icon) {
  final index = _shell(tester).destinations.indexWhere(
        (destination) => destination.label == label && destination.icon == icon,
      );
  expect(index, isNonNegative, reason: 'The destination $label.');
  return index;
}

/// Selects the destination at [index] as the layout does when the user
/// selects it.
Future<void> _select(WidgetTester tester, int index) async {
  _shell(tester).onSelect(index);
  await tester.pumpAndSettle();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets('each switch to another destination is heard of once',
      (tester) async {
    // Each call of the listener of the fixture analytics comes with one of
    // the listener of the fixture screen log.
    otherListeners.add(fixtureScreenLog);

    // The app starts on the branch of its start screen.
    await startApp(tester);
    expect(heard(), [('fake_feature.home', '/fake_feature')]);
    final fixture = _destination(tester, 'Fixture', Icons.star);
    final second = _destination(tester, 'Second', Icons.looks_two);
    expect(_shell(tester).currentIndex, fixture);

    // go() to a child in the branch.
    tester
        .element(find.byType(FixtureHomeScreen))
        .nav
        .fakeFeature
        .details(id: 1)
        .go();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/1')]);
    expect(_shell(tester).currentIndex, fixture);

    // Another destination, then the destination of before again, whose
    // branch kept its stack.
    await _select(tester, second);
    expect(heard(), [('fake_second.second', '/fake_second')]);
    expect(_shell(tester).currentIndex, second);
    await _select(tester, fixture);
    expect(heard(), [('fake_feature.details', '/fake_feature/details/1')]);
    expect(_shell(tester).currentIndex, fixture);

    // push() of a location of another destination shows it on top of the
    // branch that is selected, which stays selected, and the page below
    // again when it closes.
    unawaited(details(tester, 1).nav.fakeSecond.second().push<void>());
    await tester.pumpAndSettle();
    expect(heard(), [('fake_second.second', '/fake_second')]);
    expect(_shell(tester).currentIndex, fixture);
    Navigator.of(tester.element(find.byType(FixtureSecondScreen))).pop();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_feature.details', '/fake_feature/details/1')]);

    // go() to a location of another destination selects its branch.
    details(tester, 1).nav.fakeSecond.second().go();
    await tester.pumpAndSettle();
    expect(heard(), [('fake_second.second', '/fake_second')]);
    expect(_shell(tester).currentIndex, second);

    // The destination that is selected: the router keeps the page on top,
    // or shows another.
    final shown = tester.element(find.byType(FixtureSecondScreen));
    await _select(tester, second);
    expectHeardAtMostOnce(
        tester, shown, ('fake_second.second', '/fake_second'));

    // The router called the factory of observers once for each navigator,
    // the navigators of both branches included, and the observers of the
    // root navigator see the main navigation, not the pages of its
    // branches.
    final navigators = tester.stateList<NavigatorState>(
      find.byType(Navigator, skipOffstage: false),
    );
    expectObserverOfEachNavigator(tester);
    expect(fixtureObservers, hasLength(navigators.length));
    final root = Navigator.of(
      tester.element(find.byType(FixtureSecondScreen)),
      rootNavigator: true,
    );
    const branchPages = [
      'fake_feature.home',
      'fake_feature.details',
      'fake_second.second',
    ];
    expect(observerOf(root).pushed, isNot(anyElement(isIn(branchPages))));
  }, timeout: const Timeout(Duration(minutes: 2)));
}
