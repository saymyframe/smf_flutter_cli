/// Whether the start-up of the fixture fails; a test sets it before the app
/// starts.
bool failFixtureStart = false;

/// What the start-up of the fixture throws when [failFixtureStart] is set.
final StateError fixtureStartError = StateError(
  'The start-up of the fixture failed, as the test asked.',
);

/// The start-up of the fixture, the last of the start-up of the app: it
/// does nothing, unless [failFixtureStart] is set. Then it throws
/// [fixtureStartError] after an asynchronous gap, as a plugin that fails
/// to start does.
Future<void> startFixtureOrFail() async {
  if (!failFixtureStart) return;
  await Future<void>.delayed(Duration.zero);
  throw fixtureStartError;
}
