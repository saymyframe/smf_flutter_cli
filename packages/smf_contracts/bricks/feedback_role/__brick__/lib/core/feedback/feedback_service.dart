import 'package:flutter/widgets.dart';

/// The way the users of the app write to its developer: what the provider
/// of the feedback role implements. The code of the app uses appFeedback of
/// app_feedback.dart.
///
/// A provider keeps to what the members say. Only a running app shows
/// whether it does: the tests of the feedback role check what the app sees,
/// and the tests of the module of the provider what reaches the developer.
abstract interface class FeedbackService {
  /// Whether a user can write now: the provider has what it needs, such as
  /// an address. Reads at once, never throws, and does not change while the
  /// app runs.
  bool get available;

  /// Opens the way of the provider for the user to write to the developer,
  /// such as the mail app with a new mail, a form or a survey, over the
  /// screen of [context], a context below the root of the app.
  ///
  /// Completes with true once that way opened, without waiting for the user
  /// to send anything. Completes with false when it could not open, after
  /// the provider showed a way of its own to reach the developer when it has
  /// one, such as the address to copy, and at once while [available] is
  /// false.
  ///
  /// It asks the platform nothing before it opens and learns from the answer
  /// of the open itself: a platform may answer no while the way is there, as
  /// Android 11 and later answer an app whose manifest names no other app.
  /// What reaches the developer has the name, the version, the build number
  /// and the flavor of the app, and its platform: that is the duty of each
  /// provider, which the test of its module checks. Never throws.
  Future<bool> open(BuildContext context);
}
