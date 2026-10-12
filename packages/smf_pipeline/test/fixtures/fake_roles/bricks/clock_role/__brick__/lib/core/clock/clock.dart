/// The clock of the app, a role of a third-party package (fixture).
abstract interface class Clock {
  /// The time zones the modules of the app asked for.
  List<String> get zones;

  /// The hour of [time] on the clock: from 0 to 23, or from 1 to 12 on a
  /// clock of 12 hours (see [clockHours]).
  int hourOf(DateTime time);
}

/// The time zones the modules of the app asked for.
const clockZones = <String>[{{{zones}}}];

/// How many hours the clock of the app shows, 24 or 12: the value of
/// `--clock-hours` that the app was generated with.
const clockHours = {{clock_hours}};

/// Runs the ticks of the modules of the app.
void tick() {
{{{smf_clock__ticks}}}
}
