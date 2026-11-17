import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'feedback_service.dart';

/// How the users of the app write to its developer: a button calls
/// [AppFeedbackController.open] with its context, and hides while
/// [AppFeedbackController.available] is false.
final AppFeedbackController appFeedback = AppFeedbackController._(
  createFeedbackService(),
);

/// The way the users of the app write to its developer, the same with every
/// provider of the feedback role: the service of the provider does the
/// writing, and the controller keeps to what the role guarantees.
///
/// The app has one controller, [appFeedback].
final class AppFeedbackController {
  AppFeedbackController._(this._service);

  FeedbackService _service;

  /// Whether a call of [open] is on its way.
  bool _opening = false;

  /// Whether the app printed that the service failed to tell whether a user
  /// can write.
  bool _printedAvailable = false;

  /// Whether a user can write now: the provider has what it needs, such as
  /// an address. It does not change while the app runs.
  ///
  /// A service whose answer throws counts as one without what it needs, and
  /// a debug build prints its error once.
  bool get available {
    try {
      return _service.available;
    } on Object catch (error) {
      if (kDebugMode && !_printedAvailable) {
        _printedAvailable = true;
        debugPrint(
          'The provider of feedback failed to tell whether a user can '
          'write, so the app takes it as no: $error',
        );
      }
      return false;
    }
  }

  /// Opens the way of the provider for the user to write to the developer
  /// of the app, such as the mail app with a new mail, a form or a survey,
  /// over the screen of [context], a context below the root of the app.
  ///
  /// Completes with true once that way opened, without waiting for the user
  /// to send anything, and with false when it could not open, after the
  /// provider showed a way of its own to reach the developer if it has one.
  /// It completes with false at once, without asking the provider, while
  /// [available] is false, while [context] is no longer mounted, and while
  /// another call is on its way.
  ///
  /// It never throws: an error of the provider goes to
  /// `FlutterError.reportError` once and counts as false.
  Future<bool> open(BuildContext context) async {
    if (_opening || !context.mounted || !available) return false;
    _opening = true;
    try {
      return await _service.open(context);
    } on Object catch (error, stackTrace) {
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: error,
          stack: stackTrace,
          library: 'feedback',
          context: ErrorDescription(
            'while opening the way to write to the developer of the app',
          ),
        ),
      );
      return false;
    } finally {
      _opening = false;
    }
  }

  /// For a test: the service that [available] and [open] use from now on.
  /// The code of the app never calls it.
  void use(FeedbackService service) => _service = service;
}

/// The service of the provider of the feedback role. Only [appFeedback] and
/// a test of the provider call this.
FeedbackService createFeedbackService() => _feedbackService;

{{{smf_feedback__implementations}}}
