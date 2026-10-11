// What the tests of the conditions of the routes share, in the apps of the
// fixture modules with a router, the fixture gates and the second fixture
// feature: three routes of that feature ask for the condition of the
// fixture badge role, and the third guard of the fixture gates stands for
// it, with the flow of the first, a gate. The tests use what the tests of
// router_screens and of router_guards share too, which every app that they
// apply to has.
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/features/fake_late_gate/fixture_late_gate_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_members_screens.dart';
import 'package:{{app_name}}/features/fake_second/fixture_outside_screen.dart';
import 'package:{{app_name}}/features/fake_second/fixture_second_screen.dart';

import 'guards.dart';
import 'screens.dart';

/// The route of the second fixture feature that asks for the condition, as
/// the listeners of the screen hear of it.
const membersScreen = ('fake_second.members', '/fake_second/members');

/// The route below it, which asks for the condition by being there, as the
/// listeners of the screen hear of it.
const memberCardScreen = (
  'fake_second.memberCard',
  '/fake_second/members/card',
);

/// The route that lists the condition itself, below a route of the
/// feature that asks for nothing, as the listeners of the screen hear of
/// it.
const vaultScreen = ('fake_second.vault', '/fake_second/outside/vault');

/// The route of the second fixture feature outside the main navigation,
/// which asks for nothing and is in no flow, as the listeners of the screen
/// hear of it.
const outsideScreen = ('fake_second.outside', '/fake_second/outside');

/// The details of the item [id] of the fixture feature, a route that asks
/// for nothing, as the listeners of the screen hear of it.
(String, String) detailsScreen(int id) =>
    ('fake_feature.details', '/fake_feature/details/$id');

/// The two pages that the tests open a flow over: the screen that the app
/// starts on and the details of an item on top of it.
const pagesBelow = [FixtureHomeScreen, FixtureDetailsScreen];

/// The screens of the three routes that ask for the condition that the
/// router built, one for each page of its stack, from the page at the
/// bottom to the page on top.
List<Type> builtForHolders(WidgetTester tester) => [
      for (final widget in tester.allWidgets)
        if (widget is FixtureMembersScreen ||
            widget is FixtureMemberCardScreen ||
            widget is FixtureVaultScreen)
          widget.runtimeType,
    ];

/// The screens of the fixture features and of the fixture gates, which the
/// tests go between.
const _pages = {
  FixtureHomeScreen,
  FixtureDetailsScreen,
  FixtureSecondScreen,
  FixtureOutsideScreen,
  FixtureMembersScreen,
  FixtureMemberCardScreen,
  FixtureVaultScreen,
  FixtureLoungeScreen,
  FixtureLoungeSeatScreen,
  FixtureGateScreen,
  FixtureGateStepScreen,
  FixtureSecondGateScreen,
  FixtureLateGateScreen,
};

/// The screens that the router built, one for each of its pages, from the
/// page at the bottom to the page on top: those of the two fixture
/// features, of the fixture gates and of the fixture late gate. A branch of
/// the main navigation that was shown keeps its pages, so a test that
/// selected another destination finds those too.
List<Type> pagesBuilt(WidgetTester tester) => [
      for (final widget in tester.allWidgets)
        if (_pages.contains(widget.runtimeType)) widget.runtimeType,
    ];

/// How many pages of the routes that ask for the condition came on the
/// navigators of the router so far.
int pagesForHolders() => pagesShown()
    .where({membersScreen.$1, memberCardScreen.$1, vaultScreen.$1}.contains)
    .length;

/// The element, a context, of the screen of the type [screen] on the page
/// that is built last, the one on top among the pages with that screen,
/// also while another page covers it.
Element builtLast(WidgetTester tester, Type screen) =>
    tester.elementList(find.byType(screen, skipOffstage: false)).last;

/// Goes to the screen that the app starts on, and then to the details of
/// the item [id], a page on top of that screen, which asks for no
/// condition: the pages of [pagesBelow]. Every guard of the fixture gates
/// allows then, and the user holds both badges again. Returns the context
/// of the details.
Future<BuildContext> toDetails(WidgetTester tester, int id) async {
  fixtureSession.value = (app: true, holder: true);
  fixtureGate.value = true;
  fixtureSecondGate.value = true;
  fixtureHolder.value = true;
  fixtureSenior.value = true;
  await tester.pumpAndSettle();
  tester.element(find.byType(Navigator).first).nav.fakeFeature.home().go();
  await tester.pumpAndSettle();
  heard();
  shown(tester, FixtureHomeScreen).nav.fakeFeature.details(id: id).go();
  await tester.pumpAndSettle();
  expect(
    heard(),
    [detailsScreen(id)],
    reason: 'A route that asks for no condition shows as it is, while a '
        'condition holds and while it does not.',
  );
  expect(
    pagesBuilt(tester),
    pagesBelow,
    reason: 'go() to a route below the screen that the app starts on shows '
        'the chain of the route.',
  );
  return details(tester, id);
}

/// Takes the badge of the fixture away while no page asks for it, which
/// changes nothing on the screen.
Future<void> takeBadge(WidgetTester tester) async {
  fixtureHolder.value = false;
  await tester.pumpAndSettle();
  expect(
    heard(),
    isEmpty,
    reason: 'A condition that stops holding leaves a page that does not ask '
        'for it as it is.',
  );
}

/// Gives the badge of the fixture back.
Future<void> giveBadge(WidgetTester tester) async {
  fixtureHolder.value = true;
  await tester.pumpAndSettle();
}

/// The back button of the system.
Future<void> back(WidgetTester tester) async {
  await tester.binding.handlePopRoute();
  await tester.pumpAndSettle();
}
