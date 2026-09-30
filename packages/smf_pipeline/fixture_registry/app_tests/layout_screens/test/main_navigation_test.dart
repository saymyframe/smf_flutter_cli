// A test that continuous integration runs in the apps of the fixture
// modules with a router and a layout, whichever modules provide them, and
// with both fixture features: the router refuses to push a location in the
// main navigation from a page shown over the main navigation, and to
// replace such a page with one, with a StateError that leaves the stack and
// the listeners of the screen as they are (RouterRole). The page over the
// main navigation is the screen of the second fixture feature outside the
// main navigation. It navigates only through the navigation facade of the
// router role and the navigators of Flutter, and uses what the tests of
// router_screens share, which every app that it applies to has. Each
// expectation gives its reason, which a provider of the role with a known
// bug fails the test with (brokenProviders of the fixture registry).
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_outside_screen.dart';

import 'screens.dart';

/// What [navigate] throws, or `null` if it throws nothing.
Object? _thrownBy(void Function() navigate) {
  try {
    navigate();
  } on Object catch (error) {
    return error;
  }
  return null;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
      'push() and replace() refuse a location in the main navigation over it',
      (tester) async {
    await startApp(tester);
    expect(
      heard(),
      [('fake_feature.home', '/fake_feature')],
      reason: 'The first screen is heard of once.',
    );
    tester
        .element(find.byType(FixtureHomeScreen))
        .nav
        .fakeFeature
        .details(id: 1)
        .go();
    await tester.pumpAndSettle();
    expect(
      heard(),
      [('fake_feature.details', '/fake_feature/details/1')],
      reason: 'go() to a child in the branch is heard of once.',
    );

    // push() of a location outside the main navigation shows its page over
    // the main navigation. The test does not wait for push(), which could
    // keep it waiting forever.
    Object? result = 'not completed';
    unawaited(
      details(tester, 1)
          .nav
          .fakeSecond
          .outside()
          .push<Object?>()
          .then((value) => result = value),
    );
    await tester.pumpAndSettle();
    expect(
      heard(),
      [('fake_second.outside', '/fake_second/outside')],
      reason: 'The page over the main navigation is heard of once.',
    );
    final over = tester.element(find.byType(FixtureOutsideScreen));

    // Neither push() nor replace() takes a location in the main navigation
    // there: a child of a destination, and a destination.
    expect(
      _thrownBy(
        () => unawaited(over.nav.fakeFeature.details(id: 2).push<void>()),
      ),
      isStateError,
      reason: 'push() of a location in the main navigation from a page over '
          'it throws a StateError.',
    );
    await tester.pumpAndSettle();
    expect(
      _thrownBy(() => over.nav.fakeSecond.second().replace()),
      isStateError,
      reason: 'replace() of a page over the main navigation with a location '
          'in it throws a StateError.',
    );
    await tester.pumpAndSettle();
    expect(
      heard(),
      isEmpty,
      reason: 'A navigation that the router refuses is heard of by no '
          'listener.',
    );
    expect(
      tester.elementList(find.byType(FixtureOutsideScreen)),
      [over],
      reason: 'The page over the main navigation stays on top.',
    );

    // The stack is as it was: the page over the main navigation closes to
    // the page below it, with the value of its push.
    Navigator.of(over).pop('closed');
    await tester.pumpAndSettle();
    expect(
      result,
      'closed',
      reason: 'push() completes with the value that its page closes with.',
    );
    expect(
      heard(),
      [('fake_feature.details', '/fake_feature/details/1')],
      reason: 'The page below is heard of once when the page over the main '
          'navigation closes.',
    );
  }, timeout: const Timeout(Duration(minutes: 2)));
}
