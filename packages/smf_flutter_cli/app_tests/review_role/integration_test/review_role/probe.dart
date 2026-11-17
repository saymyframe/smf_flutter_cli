// The probe of the review role, whichever module provides it, which the
// start check runs on a device once the first screen of the app settled,
// the only place where the platform side of the provider and of the
// preferences is the real one, and which the test of the role runs too
// (probe_test.dart): the service of the provider tells within five seconds
// whether the store of the device can show its review dialog, and the
// launch counted itself in the preferences of the app and asked for no
// review on its own.
//
// It uses no test framework. It only reads: it asks the store for no
// dialog, which would stay over the app on a device, and opens no page. A
// store that cannot show the dialog is no problem, as on an emulator
// without Google Play.
import 'dart:async';

import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/core/review/app_review.dart';
import 'package:{{app_name}}/core/review/review_service.dart';

/// How long the service of the provider has to tell whether the store of
/// the device can show its review dialog.
const Duration availabilityWait = Duration(seconds: 5);

/// The probe of the start check: what is wrong with the reviews of the app
/// as the start-up left them. It waits for no screen, so it leaves [settle]
/// out.
Future<List<String>> probeReview(Future<void> Function() settle) =>
    problemsOfReviews(
      createReviewService(),
      createAppPreferences(),
      now: DateTime.now(),
    );

/// What is wrong with the reviews of the app at [now]: [service], the
/// service of the provider, does not tell within [wait] whether the store
/// can show its dialog, or fails to; or [preferences] do not have this
/// launch counted, with the time of the first launch, which is not to
/// come, and a first launch that asked for a review.
Future<List<String>> problemsOfReviews(
  ReviewService service,
  AppPreferences preferences, {
  required DateTime now,
  Duration wait = availabilityWait,
}) async {
  final problems = <String>[];
  try {
    await service.isAvailable().timeout(wait);
  } on TimeoutException {
    problems.add(
      'The service of the provider did not tell within '
      '${wait.inMilliseconds} ms whether the store of the device can show '
      'its review dialog.',
    );
  } on Object catch (error) {
    problems.add(
      'The service of the provider failed to tell whether the store of the '
      'device can show its review dialog: $error',
    );
  }
  final launches = preferences.getInt('{{launches_key}}');
  final firstLaunch = preferences.getInt('{{first_launch_key}}');
  if (launches == null || launches < 1) {
    problems.add(
      'The preferences have $launches launches of the app under '
      '{{launches_key}}, though the start-up counts this one.',
    );
  }
  if (firstLaunch == null) {
    problems.add(
      'The preferences have no time of the first launch of the app under '
      '{{first_launch_key}}.',
    );
  } else if (firstLaunch > now.millisecondsSinceEpoch) {
    problems.add(
      'The time of the first launch of the app under {{first_launch_key}} '
      'is to come.',
    );
  }
  if (launches == 1 && preferences.getInt('{{asked_at_key}}') != null) {
    problems.add(
      'The app asked for a review on its first launch, which the role never '
      'does.',
    );
  }
  return problems;
}
