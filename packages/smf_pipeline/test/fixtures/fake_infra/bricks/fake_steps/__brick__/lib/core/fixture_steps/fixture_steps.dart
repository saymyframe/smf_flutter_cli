import 'dart:async';

import 'package:flutter/material.dart';

/// The steps of the onboarding of the fixture whose action ran, in the
/// order of the calls: `ask` or `confirm` for each call of the action of
/// the step of that name.
final List<String> fixtureStepCalls = [];

/// Whether the onboarding shows the step `ask`, which a test sets: the
/// onboarding asks [showsFixtureAsk] once each time it opens.
bool fixtureAskShows = true;

/// What the action of the step `ask` waits for once its screen is closed,
/// as a test sets it to hold the action back, or `null` for nothing.
Completer<void>? fixtureAskHold;

/// Whether the action of the step `ask` fails once it noted its call, as a
/// test sets it.
bool fixtureAskFails = false;

/// The route of the screen that the action of the step `ask` shows while
/// the screen is open, or `null` while it shows none.
Route<void>? fixtureAskRoute;

/// The action of the step `ask`: notes its call in [fixtureStepCalls],
/// fails if [fixtureAskFails], shows [FixtureAskScreen] over the app until
/// that screen is closed, and then waits for [fixtureAskHold].
///
/// It shows the screen as a step shows a screen of its own over the
/// onboarding: with a route without a page on the navigator at the root of
/// the app, which it finds from [context], the context of the onboarding
/// screen.
Future<void> askFixture(BuildContext context) async {
  fixtureStepCalls.add('ask');
  if (fixtureAskFails) {
    throw StateError('The action of the fixture step ask fails.');
  }
  final route = fixtureAskRoute = MaterialPageRoute<void>(
    fullscreenDialog: true,
    builder: (context) => const FixtureAskScreen(),
  );
  try {
    await Navigator.of(context, rootNavigator: true).push(route);
  } finally {
    if (fixtureAskRoute == route) fixtureAskRoute = null;
  }
  await fixtureAskHold?.future;
}

/// Whether the onboarding shows the step `ask`: [fixtureAskShows].
bool showsFixtureAsk() => fixtureAskShows;

/// The action of the step `confirm`: notes its call in [fixtureStepCalls].
/// It needs nothing of the context of the onboarding screen.
Future<void> confirmFixture(BuildContext _) async {
  fixtureStepCalls.add('confirm');
}

/// The screen that the action of the step `ask` shows over the app, with a
/// button that closes it.
class FixtureAskScreen extends StatelessWidget {
  /// Creates the screen.
  const FixtureAskScreen({super.key});

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(leading: const CloseButton()),
      );
}
