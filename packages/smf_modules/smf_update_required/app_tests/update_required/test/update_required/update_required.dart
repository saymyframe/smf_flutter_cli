// What the tests of the update_required module share, in the apps with the
// module: the start of the app with main() of lib/main.dart, which the app
// entry role puts into every app, what runs a call in real time, a service of
// remote config and a service of the reviews of the tests, which script what
// the providers of the two roles answer, the lowest version that may run,
// which a test publishes through the first, and what the screen shows.
//
// They know the module, and of the rest of the app only its roles: the
// controllers of the remote config role and of the review role, whichever
// modules provide them, and the screen that the app starts on and the texts
// of the module in each language of the app, which the matrix writes into
// of_app.dart next to this file, from the data of the roles of the app. The
// matrix sets up the mocks of the platform side of every module of the app
// before the tests of each test file (flutter_test_config.dart).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/remote_config/app_remote_config.dart';
import 'package:{{app_name}}/core/remote_config/remote_config_service.dart';
import 'package:{{app_name}}/core/review/app_review.dart';
import 'package:{{app_name}}/core/review/review_service.dart';
import 'package:{{app_name}}/features/update_required/update_required_screen.dart';
import 'package:{{app_name}}/features/update_required/update_status.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'of_app.dart';

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of a provider, does not wait
/// for the fake time of the test. An error of [action] fails the test, which
/// tester.runAsync would only report to the handler of the errors of
/// Flutter.
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

/// Waits a moment in real time, for what a call set off to happen, such as
/// the activation of a value that the backend of remote config published.
Future<void> aMoment() =>
    Future<void>.delayed(const Duration(milliseconds: 20));

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time of
/// the test waiting forever. An error of main() fails the test, which
/// tester.runAsync would only report to the handler of the errors of
/// Flutter. An error of bootstrap() reaches FlutterError.onError through
/// main(), which fails the test too. The handlers of errors that the
/// start-up installs, such as those of crash reporting, and the builder of
/// the widget of an error go back to those of the test once main() returns,
/// so that flutter_test reports the errors of the frames that follow, such
/// as a widget that does not fit, and an expectation that fails, as in any
/// test.
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

/// A service of remote config of the tests, which a test gives
/// appRemoteConfig.start() to script what a provider answers: a backend that
/// has [values], which the device kept from the last fetch, and that tells
/// of what it publishes while the app runs.
final class ScriptedRemoteConfig implements RemoteConfigService {
  /// Creates the service of a backend with [values].
  ScriptedRemoteConfig([Map<String, String> values = const {}])
      : _fetched = {...values};

  Map<String, String> _fetched;
  Map<String, String> _active = {};

  final StreamController<void> _updates = StreamController<void>.broadcast();

  /// The backend publishes [values] while the app runs, and the service
  /// tells of them.
  void publish(Map<String, String> values) {
    _fetched = {...values};
    _updates.add(null);
  }

  @override
  bool get liveUpdates => true;

  @override
  Future<void> open(
    Map<String, Object> defaults, {
    required Duration fetchInterval,
    required Duration fetchTimeout,
  }) async {}

  @override
  Future<bool> activate() async {
    final changed = !mapEquals(_fetched, _active);
    _active = {..._fetched};
    return changed;
  }

  @override
  Map<String, String> get values => {..._active};

  @override
  Future<void> fetch() async {}

  @override
  Stream<void> get updates => _updates.stream;
}

/// A service of the reviews of the tests, which a test gives
/// appReview.start() to script whether an app of the device opens the page
/// of the app in its store, or whether the page answers at all. It notes
/// each page that it opened.
final class ScriptedReview implements ReviewService {
  /// Whether an app of the device opens a page.
  bool opens = true;

  /// What a page answers with, if set: a page whose future never completes
  /// does not answer.
  Future<bool>? answer;

  /// The pages that the service opened, in their order.
  final List<Uri> pages = [];

  @override
  Future<bool> isAvailable() async => true;

  @override
  Future<void> requestReview() async {}

  @override
  Future<bool> openStorePage(Uri page) {
    pages.add(page);
    return answer ?? Future.value(opens);
  }

  @override
  Future<String?> appVersion() async => '1.0.0';
}

/// The services of the tests that the app has once [useScriptedServices]
/// started remote config and the reviews with them.
late ScriptedRemoteConfig remoteConfig;
late ScriptedReview review;

/// Starts appRemoteConfig and appReview with services of the tests, in place
/// of those of the providers of the app, with the lowest version that may
/// run [minimum] in the backend, if any, and waits for what the start sets
/// off, such as the listener of the values that the backend publishes.
Future<void> useScriptedServices(
  WidgetTester tester, {
  String? minimum,
}) async {
  final values = <String, String>{};
  if (minimum != null) values[minimumParameter] = minimum;
  remoteConfig = ScriptedRemoteConfig(values);
  review = ScriptedReview();
  await inRealTime(tester, 'starting with services of the test', () async {
    await appRemoteConfig.start(remoteConfig);
    await appReview.start(review);
    await aMoment();
  });
  await tester.pumpAndSettle();
}

/// The backend of remote config publishes [minimum] as the lowest version
/// that may run, which the app makes active as it comes, and the test waits
/// for the screen that the app shows then.
Future<void> publishMinimum(WidgetTester tester, String minimum) async {
  await inRealTime(tester, 'publishing $minimum', () async {
    remoteConfig.publish({minimumParameter: minimum});
    await aMoment();
  });
  await tester.pumpAndSettle();
}

/// Runs updateStatus.start() again, as the next launch of the app does, in
/// real time, with [review], a controller of the reviews of the test, if
/// any, in place of appReview.
Future<void> startStatusAgain(
  WidgetTester tester, {
  AppReviewController? review,
}) async {
  await inRealTime(
    tester,
    'updateStatus.start()',
    () => updateStatus.start(review: review),
  );
  await tester.pumpAndSettle();
}

/// The texts of the module in the language that the device asks for, each
/// by its name in the module: English, the first language of every app.
Map<String, String> get texts => updateRequiredTexts['en']!;

/// The screen of the module.
final Finder gate = find.byType(UpdateRequiredScreen);

/// What the screen of the module shows of [matching].
Finder shown(Finder matching) => find.descendant(of: gate, matching: matching);

/// The button "Update" of the screen, by its label in [language].
Finder updateButton([String language = 'en']) => shown(
      find.widgetWithText(
        ElevatedButton,
        updateRequiredTexts[language]!['update']!,
      ),
    );

/// The button "Not now" of the screen, by its label in [language].
Finder laterButton([String language = 'en']) => shown(
      find.widgetWithText(
        TextButton,
        updateRequiredTexts[language]!['later']!,
      ),
    );

/// The text of the screen that the store did not open, in [language].
Finder storeFailed([String language = 'en']) =>
    shown(find.text(updateRequiredTexts[language]!['storeFailed']!));

/// What [action] prints with debugPrint, which the test hears in place of
/// the console while it runs, in real time.
Future<List<String>> printedBy(
  WidgetTester tester,
  String what,
  Future<void> Function() action,
) async {
  final printed = <String>[];
  final before = debugPrint;
  debugPrint = (message, {wrapWidth}) {
    if (message != null) printed.add(message);
  };
  try {
    await inRealTime(tester, what, action);
  } finally {
    debugPrint = before;
  }
  return printed;
}
