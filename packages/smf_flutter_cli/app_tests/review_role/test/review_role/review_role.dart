// What the tests of the review role share, in the apps with the role,
// whichever module provides it: the keys under which the app keeps what
// the role remembers, the suffixes of the ids of the flavors of the app,
// the start-up of the app, which runs once for the tests of a file, what
// runs a call in real time, the state of a review that is due, controllers
// of the tests, a service of the tests, which scripts what a provider
// answers, and what the app shows.
//
// It knows only the role, and the preferences role that it requires. The
// matrix fills in the keys, which the role publishes, and the suffixes,
// which the app entry role publishes.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/core/review/app_review.dart';
import 'package:{{app_name}}/core/review/review_service.dart';
import 'package:{{app_name}}/main.dart' as app;

/// The key under which the app counts its launches.
const String launchesKey = '{{launches_key}}';

/// The key under which the app keeps the time of its first launch, in
/// milliseconds since the epoch.
const String firstLaunchKey = '{{first_launch_key}}';

/// The key under which the app keeps the time of its last request.
const String askedAtKey = '{{asked_at_key}}';

/// The key under which the app keeps the version of its last request.
const String askedVersionKey = '{{asked_version_key}}';

/// The keys of the role.
const List<String> reviewKeys = [
  launchesKey,
  firstLaunchKey,
  askedAtKey,
  askedVersionKey,
];

/// What the ids of the flavors of the app add to the id of the app, but
/// for the flavor for a release, which has the id of the app itself, such
/// as `.dev`.
final List<String> flavorSuffixes = '{{flavor_suffixes}}'.split(',');

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of the provider, does not
/// wait for the fake time of the test. An error of [action] fails the
/// test, which tester.runAsync would only report to the handler of the
/// errors of Flutter.
Future<void> inRealTime(
  WidgetTester tester,
  String what,
  Future<void> Function() action,
) async {
  Object? error;
  StackTrace? stackTrace;
  await tester.runAsync(() async {
    try {
      await action();
    } on Object catch (thrown, stack) {
      error = thrown;
      stackTrace = stack;
    }
  });
  if (error != null) fail('$what threw $error\n$stackTrace');
}

/// The problem of the start-up of the app, which runs once for the tests of
/// a file: `null` before it runs, and empty if it passed.
String? _startUpProblem;

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time, unless a test of the file ran it already, and
/// fails the test if it failed. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the widget
/// of an error go back to those of the test once it returns.
Future<void> startUp(WidgetTester tester) async {
  if (_startUpProblem == null) {
    final onError = FlutterError.onError;
    final onPlatformError = PlatformDispatcher.instance.onError;
    final errorWidgetBuilder = ErrorWidget.builder;
    try {
      _startUpProblem = '';
      await inRealTime(tester, 'bootstrap()', bootstrap);
    } on TestFailure catch (failure) {
      _startUpProblem = failure.message ?? 'bootstrap() failed';
    } finally {
      FlutterError.onError = onError;
      PlatformDispatcher.instance.onError = onPlatformError;
      ErrorWidget.builder = errorWidgetBuilder;
    }
  }
  if (_startUpProblem case final problem? when problem.isNotEmpty) {
    fail(problem);
  }
}

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen. A test file that calls it calls it once.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time of
/// the test waiting forever. An error of main() fails the test, which
/// tester.runAsync would only report to the handler of the errors of
/// Flutter. An error of bootstrap() reaches FlutterError.onError through
/// main(), which fails the test too. The handlers of errors that the
/// start-up installs, such as those of crash reporting, and the builder of
/// the widget of an error go back to those of the test once main() returns,
/// so that flutter_test reports an expectation that fails as in any test.
Future<void> startApp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await inRealTime(tester, 'main()', app.main);
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
  await tester.pumpAndSettle();
}

/// Shows frames for two seconds of the fake time of the test, and lets half
/// a second of real time pass, enough for a dialog to come in, whatever it
/// waits for, without waiting for the screen to settle, which a spinner
/// that never stops would keep from happening.
Future<void> showFrames(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 500)),
  );
  for (var frame = 0; frame < 20; frame++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

/// Removes what the preferences keep for the role, so that a new controller
/// of the tests starts as on a first launch. A controller that ran keeps
/// what it has in memory, as the restorer of the role does for a key that
/// has nothing saved.
Future<void> forgetReviews() async {
  final preferences = createAppPreferences();
  for (final key in reviewKeys) {
    await preferences.remove(key);
  }
}

/// Saves under the keys of the role the state of an app on which a review
/// is due at [now]: [launches] launches, the first [since] before [now],
/// and no request. A controller that ran keeps what it has in memory of a
/// request, so a test that gives the global one this state saw no request
/// of it.
Future<void> saveDueState({
  required DateTime now,
  int launches = 9,
  Duration since = const Duration(days: 30),
}) async {
  await forgetReviews();
  final preferences = createAppPreferences();
  await preferences.setInt(launchesKey, launches);
  await preferences.setInt(
    firstLaunchKey,
    now.subtract(since).millisecondsSinceEpoch,
  );
}

/// What the preferences saved under the keys of the role, each time as a
/// time in UTC.
({int? launches, DateTime? firstLaunch, DateTime? askedAt, String? version})
    get savedReviews {
  final preferences = createAppPreferences();
  DateTime? timeOf(String key) => switch (preferences.getInt(key)) {
        final int milliseconds => DateTime.fromMillisecondsSinceEpoch(
            milliseconds,
            isUtc: true,
          ),
        _ => null,
      };
  return (
    launches: preferences.getInt(launchesKey),
    firstLaunch: timeOf(firstLaunchKey),
    askedAt: timeOf(askedAtKey),
    version: preferences.getString(askedVersionKey),
  );
}

/// A launch of the app, as the next launch finds what the device kept: a
/// controller of the tests over the preferences of the app, which reads the
/// time from [now] and the App Store ID from [appStoreId], started with
/// [service]. It counts the launch, in real time.
Future<AppReviewController> launchWith(
  WidgetTester tester,
  ReviewService service, {
  required DateTime Function() now,
  String? Function()? appStoreId,
}) async {
  final controller = appStoreId == null
      ? AppReviewController(now: now)
      : AppReviewController(now: now, appStoreId: appStoreId);
  await inRealTime(tester, 'a launch', () async {
    controller.restore(createAppPreferences());
    await controller.start(service);
  });
  return controller;
}

/// Asks [controller] for a review if one is due, in real time.
Future<void> requestIfDue(
  WidgetTester tester,
  AppReviewController controller,
) =>
    inRealTime(tester, 'requestIfDue()', controller.requestIfDue);

/// A service of the tests, which a test gives a controller to script what a
/// provider answers: whether the store of the device can show its dialog,
/// the version of the app, whether the platform refuses a request and
/// whether an app of the device opens a page. It notes each call that
/// reaches it, and shows nothing.
final class ScriptedReview implements ReviewService {
  /// Creates the service of a device whose store can show its dialog if
  /// [available], of the app in [version].
  ScriptedReview({this.available = true, this.version = '1.0.0'});

  /// Whether the store of the device can show its dialog.
  bool available;

  /// The version of the app, or `null` when it is unknown.
  String? version;

  /// Whether the platform refuses the next requests.
  bool refuses = false;

  /// Whether an app of the device opens a page.
  bool opens = true;

  /// The calls that reached the service, in their order, such as
  /// `appVersion`, `isAvailable` and `requestReview`.
  final List<String> calls = [];

  /// The pages that the service opened, in their order.
  final List<Uri> pages = [];

  /// How many times the service asked the store for its dialog.
  int get requests => calls.where((call) => call == 'requestReview').length;

  /// Holds a request back until it completes, if set. A test sets it in
  /// real time, since a future of the fake time of the test completes only
  /// when that time goes on.
  Completer<void>? held;

  @override
  Future<bool> isAvailable() async {
    calls.add('isAvailable');
    return available;
  }

  @override
  Future<void> requestReview() async {
    calls.add('requestReview');
    await held?.future;
    if (refuses) throw StateError('The platform refused the request.');
  }

  @override
  Future<bool> openStorePage(Uri page) async {
    calls.add('openStorePage');
    pages.add(page);
    return opens;
  }

  @override
  Future<String?> appVersion() async {
    calls.add('appVersion');
    return version;
  }
}

/// What the app shows: the texts of the widgets on the screen, and how
/// many modal barriers it has, one for each route of a navigator, a dialog
/// among them.
({Set<String> texts, int barriers}) shownBy(WidgetTester tester) => (
      texts: {
        for (final text in tester.widgetList<RichText>(find.byType(RichText)))
          text.text.toPlainText(),
      },
      barriers: tester.widgetList(find.byType(ModalBarrier)).length,
    );
