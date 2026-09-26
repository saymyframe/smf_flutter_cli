/// The clock of the app, a role of a third-party package (fixture).
abstract interface class Clock {
  /// The time zones the modules of the app asked for.
  List<String> get zones;
}

/// The time zones the modules of the app asked for.
const clockZones = <String>[{{{zones}}}];

/// Runs the ticks of the modules of the app.
void tick() {
{{{smf_clock__ticks}}}
}
