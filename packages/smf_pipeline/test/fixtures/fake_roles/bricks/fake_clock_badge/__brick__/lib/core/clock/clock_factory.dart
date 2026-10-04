import 'clock.dart';

/// Creates the clock of the app.
Clock createClock() => const _FixedClock();

final class _FixedClock implements Clock {
  const _FixedClock();

  // Each zone is a constant of a file of its own.
  @override
  List<String> get zones => const [{{{zone_constants}}}];
}
