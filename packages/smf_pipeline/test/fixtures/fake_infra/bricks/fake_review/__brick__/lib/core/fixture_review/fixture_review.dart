import '../review/review_service.dart';

/// Waits for the answer of the store, which takes a moment, as with a
/// provider that asks it: a turn of the event loop. So a test makes the
/// calls of the reviews in real time, as it runs the start-up of the app.
Future<void> _answer() => Future<void>.delayed(Duration.zero);

/// Creates the reviews of the fixture, with the app. It asks the user
/// nothing.
ReviewService createFixtureReview() => const FixtureReview._();

/// The reviews of a device whose store can always show its dialog, which
/// shows nothing in the tests, and on which a page of the store always
/// opens, as the mocks of the platform side of every provider of the role
/// have it. The version of the app is `1.0.0`, as they have it too.
final class FixtureReview implements ReviewService {
  const FixtureReview._();

  @override
  Future<bool> isAvailable() async {
    await _answer();
    return true;
  }

  /// Asks the store of the device for its dialog, which shows nothing in
  /// the tests, and shows nothing of its own around it.
  @override
  Future<void> requestReview() async {
    await _answer();
  }

  @override
  Future<bool> openStorePage(Uri page) async {
    await _answer();
    return true;
  }

  @override
  Future<String?> appVersion() async => '1.0.0';
}
