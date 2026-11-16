/// The store of the platform for the reviews of the app: what the provider
/// of the review role implements. The code of the app uses `appReview` of
/// app_review.dart, which decides when a review is due.
abstract interface class ReviewService {
  /// Whether the store of this device can show its review dialog, such as
  /// `false` on Android without Google Play. Never throws: `false` when it
  /// cannot tell.
  Future<bool> isAvailable();

  /// Asks the store for its review dialog, and shows nothing of its own
  /// around it: no question, no text and no screen. Completes once the
  /// store took the request. Whether the dialog showed, and what the user
  /// did, the store tells nobody. Throws when the platform refused the
  /// request.
  Future<void> requestReview();

  /// Opens [page], a page of the app in its store, outside the app, and
  /// returns whether an app of the device opened it. Never throws.
  Future<bool> openStorePage(Uri page);

  /// The version of the app, such as `1.2.0`, without its build number, or
  /// `null` when the provider cannot tell. The app asks for a review at most
  /// once a version. Never throws.
  Future<String?> appVersion();
}
