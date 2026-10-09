import 'clock.dart';

/// Creates the clock of the app.
Clock createClock() => const _FixedClock();

final class _FixedClock implements Clock {
  const _FixedClock();

  // Each zone is a constant of a file of its own.
  @override
  List<String> get zones => const [{{{zone_constants}}}];

  // The code for the hours of the clock of this app.
  @override
  int hourOf(DateTime time) => {{{hour_of}}};
}
