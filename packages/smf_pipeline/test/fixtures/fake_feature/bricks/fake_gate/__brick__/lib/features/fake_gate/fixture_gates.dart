import 'package:flutter/foundation.dart';

/// A gate of the fixture: whether it is open, which a test sets. A guard of
/// the fixture allows while its gate is open.
final class FixtureGate extends ValueNotifier<bool> {
  /// Creates the gate, which is open unless the gates of the app start
  /// closed.
  FixtureGate() : super({{{open}}});

  /// Notifies the listeners of the gate though it did not change, as a
  /// guard may that notifies for more than what it allows.
  void poke() => notifyListeners();
}

/// The first gate of the fixture: while it is closed, the first guard of
/// the fixture shows the gate screen in place of the other screens of the
/// app.
final FixtureGate fixtureGate = FixtureGate();

/// The second gate of the fixture, whose guard comes after the first and
/// shows the second gate screen.
final FixtureGate fixtureSecondGate = FixtureGate();

/// Whether the first guard of the fixture allows: while its gate is open.
ValueListenable<bool> fixtureGateOpen() => fixtureGate;

/// Whether the second guard of the fixture allows: while its gate is open.
ValueListenable<bool> fixtureSecondGateOpen() => fixtureSecondGate;
