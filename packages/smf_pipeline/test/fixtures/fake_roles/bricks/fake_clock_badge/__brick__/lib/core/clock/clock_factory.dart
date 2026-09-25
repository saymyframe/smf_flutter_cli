import 'clock.dart';

/// Creates the clock of the app.
Clock createClock() => const _FixedClock();

final class _FixedClock implements Clock {
  const _FixedClock();

  @override
  List<String> get zones => clockZones;
}
