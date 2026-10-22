import 'dart:async';

import 'package:flutter/widgets.dart';

/// The steps of the onboarding of the fixture whose action ran, in the
/// order of the calls: `ask` or `confirm` for each call of the action of
/// the step of that name.
final List<String> fixtureStepCalls = [];

/// Whether the onboarding shows the step `ask`, which a test sets: the
/// onboarding asks [showsFixtureAsk] once each time it opens.
bool fixtureAskShows = true;

/// What the action of the step `ask` waits for once it noted its call, as
/// a test sets it to hold the action back, or `null` for nothing.
Completer<void>? fixtureAskHold;

/// Whether the action of the step `ask` fails once it noted its call, as a
/// test sets it.
bool fixtureAskFails = false;

/// The action of the step `ask`: notes its call in [fixtureStepCalls],
/// fails if [fixtureAskFails], and then waits for [fixtureAskHold].
Future<void> askFixture(BuildContext _) async {
  fixtureStepCalls.add('ask');
  if (fixtureAskFails) {
    throw StateError('The action of the fixture step ask fails.');
  }
  await fixtureAskHold?.future;
}

/// Whether the onboarding shows the step `ask`: [fixtureAskShows].
bool showsFixtureAsk() => fixtureAskShows;

/// The action of the step `confirm`: notes its call in [fixtureStepCalls].
Future<void> confirmFixture(BuildContext _) async {
  fixtureStepCalls.add('confirm');
}
