// What the tests of the guards of the routes share, in the apps of the
// fixture modules with a router, the fixture gates and the fixture late
// gate: the screens of the fixtures that the router built, one for each
// page, and a push whose result a test reads without waiting for it. The
// tests use what the tests of router_screens share too, which every app
// that they apply to has.
import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/fixture_analytics/fixture_analytics.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_details_screen.dart';
import 'package:{{app_name}}/features/fake_feature/fixture_home_screen.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_late_gate/fixture_late_gate_screen.dart';

/// The start screen of the app, as the listeners of the screen hear of it:
/// the route of the fixture feature that the app starts on, and its
/// location.
const startScreen = ('fake_feature.home', '/fake_feature');

/// The target of the first guard of the fixture gates, as the listeners of
/// the screen hear of it.
const gateScreen = ('fake_gate.gate', '/fake_gate');

/// The route below the target of the first guard of the fixture gates, a
/// route of its flow, as the listeners of the screen hear of it.
const stepScreen = ('fake_gate.step', '/fake_gate/step');

/// The target of the second guard of the fixture gates, as the listeners of
/// the screen hear of it.
const secondGateScreen = ('fake_gate.second', '/fake_gate/second');

/// The target of the guard of the fixture late gate, as the listeners of
/// the screen hear of it. The guard is of a later stage than the guards of
/// the fixture gates, and does not bring the user back.
const lateGateScreen = ('fake_late_gate.gate', '/fake_late_gate');

/// The screens of the fixture feature, of the fixture gates and of the
/// fixture late gate, which the tests go between.
const _screens = {
  FixtureHomeScreen,
  FixtureDetailsScreen,
  FixtureGateScreen,
  FixtureGateStepScreen,
  FixtureSecondGateScreen,
  FixtureLateGateScreen,
};

/// The screens of the fixture feature, of the fixture gates and of the
/// fixture late gate that the router built, one for each page of its
/// stack, from the page at the bottom to the page on top: a screen that
/// two pages show is there twice.
List<Type> builtScreens(WidgetTester tester) => [
      for (final widget in tester.allWidgets)
        if (_screens.contains(widget.runtimeType)) widget.runtimeType,
    ];

/// The names of the routes of the pages that came on the navigators of the
/// router, as the navigator observers of the fixture analytics saw them.
List<String?> pagesShown() => [
      for (final observer in fixtureObservers) ...observer.pushed,
    ];

/// The element, a context, of the screen of the type [screen] that the user
/// sees.
Element shown(WidgetTester tester, Type screen) =>
    tester.element(find.byType(screen));

/// Pushes [link] and returns what the push has completed with so far:
/// `'not completed'` until it completes. The test does not wait for push(),
/// which could keep it waiting forever.
Object? Function() pushed(NavLink link) {
  Object? result = 'not completed';
  unawaited(link.push<Object?>().then((value) => result = value));
  return () => result;
}
