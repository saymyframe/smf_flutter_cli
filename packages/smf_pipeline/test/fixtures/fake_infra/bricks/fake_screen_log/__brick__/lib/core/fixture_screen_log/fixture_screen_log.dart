/// The screens the user saw, as the screen listener of the fixture screen
/// log heard of them: the full name of the route of each, or `null`, and
/// its location.
final List<(String?, String)> fixtureScreenLog = [];

/// Whether the screen listener of the fixture screen log throws once it
/// noted a screen, as a test that a listener of the screen that throws
/// keeps no other from hearing it sets it.
bool fixtureScreenLogThrows = false;

/// The screen listener of the fixture screen log: notes the screen of
/// [route] at [location] in [fixtureScreenLog], and then throws if
/// [fixtureScreenLogThrows].
void noteFixtureScreenLog(String? route, String location) {
  fixtureScreenLog.add((route, location));
  if (fixtureScreenLogThrows) {
    throw StateError('The screen listener of the fixture screen log throws.');
  }
}
