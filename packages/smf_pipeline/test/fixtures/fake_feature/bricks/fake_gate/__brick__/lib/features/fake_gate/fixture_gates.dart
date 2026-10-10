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

/// Whether the user holds the badge of the fixture: while this gate is
/// open, which it is until a test closes it, also in an app whose gates
/// start closed. The third guard of the fixture reads it. That guard keeps
/// the user only from the routes of the app that ask for a holder of a
/// badge, and opens the gate screen of the first guard over the page that
/// the user is on.
final FixtureGate fixtureHolder = FixtureGate()..value = true;

/// One notifier for what the first guard and the third guard of the
/// fixture read besides their gates, as the session of a sign-in has
/// whether it lets the user into the app and whether the user has an
/// account: the two guards have one flow, and a test changes both values
/// with one assignment, in one turn. Both are `true` until a test says
/// otherwise.
final ValueNotifier<({bool app, bool holder})> fixtureSession = ValueNotifier(
  (app: true, holder: true),
);

/// A value that is computed from [_sources] when it is read, and whose
/// listeners are theirs: two such values over one notifier never show one
/// changed and the other not.
final class _Computed implements ValueListenable<bool> {
  _Computed(this._sources, this._compute);

  final List<Listenable> _sources;

  final bool Function() _compute;

  @override
  bool get value => _compute();

  @override
  void addListener(VoidCallback listener) {
    for (final source in _sources) {
      source.addListener(listener);
    }
  }

  @override
  void removeListener(VoidCallback listener) {
    for (final source in _sources) {
      source.removeListener(listener);
    }
  }
}

final ValueListenable<bool> _gateOpen = _Computed(
  [fixtureGate, fixtureSession],
  () => fixtureGate.value && fixtureSession.value.app,
);

final ValueListenable<bool> _holds = _Computed(
  [fixtureHolder, fixtureSession],
  () => fixtureHolder.value && fixtureSession.value.holder,
);

/// Whether the first guard of the fixture allows: while its gate is open
/// and the session of the fixture lets the user into the app.
ValueListenable<bool> fixtureGateOpen() => _gateOpen;

/// Whether the second guard of the fixture allows: while its gate is open.
ValueListenable<bool> fixtureSecondGateOpen() => fixtureSecondGate;

/// Whether the third guard of the fixture allows: while the user holds the
/// badge of the fixture, by its gate and by the session of the fixture.
ValueListenable<bool> fixtureHolds() => _holds;
