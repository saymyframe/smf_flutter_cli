// What the tests of the conditions of the routes share, in the apps of the
// fixture modules with a router, the fixture gates and the second fixture
// feature: three routes of that feature ask for the condition of the
// fixture badge role, and the third guard of the fixture gates stands for
// it. The tests use what the tests of router_screens and of router_guards
// share too, which every app that they apply to has.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/features/fake_second/fixture_members_screens.dart';

/// The route of the second fixture feature that asks for the condition, as
/// the listeners of the screen hear of it.
const membersScreen = ('fake_second.members', '/fake_second/members');

/// The route below it, which asks for the condition by being there, as the
/// listeners of the screen hear of it.
const memberCardScreen = (
  'fake_second.memberCard',
  '/fake_second/members/card',
);

/// The route that asks for the condition by itself, below a route of the
/// feature that asks for nothing, as the listeners of the screen hear of
/// it.
const vaultScreen = ('fake_second.vault', '/fake_second/outside/vault');

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
