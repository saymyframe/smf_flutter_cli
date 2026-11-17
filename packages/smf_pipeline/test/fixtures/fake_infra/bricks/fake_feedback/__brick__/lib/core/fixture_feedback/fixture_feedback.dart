import 'package:flutter/widgets.dart';

import '../feedback/feedback_service.dart';

/// The device of the tests, with an app that takes what the user writes to
/// the developer, as the mocks of every provider of the feedback role have
/// one. Asked whether it has such an app, it says no, as Android 11 and
/// later say to an app whose manifest names no other app.
abstract final class FixtureFeedbackDevice {
  /// What the app of the device took, in order.
  static final List<String> opened = [];

  /// Opens the app with [message], and answers a turn of the event loop
  /// later, as the system does, that it opened.
  static Future<bool> open(String message) async {
    await Future<void>.delayed(Duration.zero);
    opened.add(message);
    return true;
  }

  /// Whether the device has such an app, which it answers a turn of the
  /// event loop later: no, though it has one.
  static Future<bool> canOpen() async {
    await Future<void>.delayed(Duration.zero);
    return false;
  }
}

/// Creates the feedback of the fixture, as a start of the app does.
FeedbackService createFixtureFeedback() => FixtureFeedback._();

/// Feedback on the device of the tests: it has what it needs, and opens the
/// app of the device with a message in the language of the app.
final class FixtureFeedback implements FeedbackService {
  FixtureFeedback._();

  @override
  bool get available => true;

  @override
  Future<bool> open(BuildContext context) async {
    // Read before the first await, while the context is surely mounted.
    final language = Localizations.localeOf(context).languageCode;
    final message = 'Feedback in $language';
    return FixtureFeedbackDevice.open(message);
  }
}
