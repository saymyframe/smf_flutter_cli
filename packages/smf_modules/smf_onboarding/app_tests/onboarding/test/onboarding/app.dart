// What the tests of the onboarding module share, in the apps with the
// module: the app starts with main() of lib/main.dart, which the app entry
// role puts into every app, as its first launch finds it or with what an
// earlier launch saved. The mocks of the module, which finish the
// onboarding for the tests of the other modules of the app, leave it alone
// in the test files of the onboarding (../onboarding_mocks.dart).
//
// They know the module, and of the rest of the app only its roles: the
// preferences of the preferences role, whichever module provides them, and
// the screen that the app starts on, which the matrix writes into
// start_screen.dart next to this file, from the data of the router role of
// the app. The matrix sets up the mocks of the platform side of every
// module of the app before the tests of each test file
// (flutter_test_config.dart).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/features/onboarding/onboarding_screen.dart';
import 'package:{{app_name}}/features/onboarding/onboarding_status.dart';
import 'package:{{app_name}}/main.dart' as app;

import '../../integration_test/onboarding/probe.dart';
import 'start_screen.dart';

/// The name of the app as the module writes it on the first page of the
/// onboarding: the name of its package in title case, such as `My App` for
/// `my_app`.
final String appName = '{{app_name}}'
    .split('_')
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time
/// of the test waiting forever. An error of main() fails the test, which
/// tester.runAsync would only report to the handler of the errors of
/// Flutter. The handlers of errors that the start-up installs, such as
/// those of crash reporting, and the builder of the widget of an error go
/// back to those of the test once main() returns, so that flutter_test
/// reports the errors of the frames that follow, such as a widget that
/// does not fit, and an expectation that fails, as in any test.
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

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of the preferences, does
/// not wait for the fake time of the test. An error of [action] fails the
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

/// Starts the onboarding of the running app again, as the app does for a
/// user who asks to see it again, with restart() of its status, and waits
/// for the screen that the router shows then. A test goes through the
/// onboarding again this way without another start of the app.
Future<void> restartOnboarding(WidgetTester tester) async {
  await inRealTime(
    tester,
    'restart() of the status of the onboarding',
    onboardingStatus.restart,
  );
  await tester.pumpAndSettle();
}

/// What the preferences have saved under the key of the module, once the
/// write that saves [expected] had a moment: a tap that finishes the
/// onboarding does not wait for its write, which the platform side of the
/// preferences may complete in real time.
Future<bool?> savedCompleted(
  WidgetTester tester, {
  required bool expected,
}) async {
  for (var attempt = 0; attempt < 50; attempt++) {
    if (createAppPreferences().getBool(completedKey) == expected) break;
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 20)),
    );
    await tester.pump();
  }
  return createAppPreferences().getBool(completedKey);
}

/// Checks that the app has left the onboarding for the screen that it
/// starts on, and saved that the onboarding is finished, once [what]
/// finished it.
Future<void> expectFinished(WidgetTester tester, String what) async {
  expect(
    onboardingStatus.completed.value,
    isTrue,
    reason: '$what finishes the onboarding.',
  );
  expect(
    await savedCompleted(tester, expected: true),
    isTrue,
    reason: '$what saves in the preferences that the onboarding is '
        'finished.',
  );
  expect(
    find.byType(OnboardingScreen, skipOffstage: false),
    findsNothing,
    reason: 'Once the onboarding is finished, the router leaves its screen.',
  );
  expect(
    find.byType(startScreen),
    findsOneWidget,
    reason: 'Once the onboarding is finished, the app shows the screen that '
        'it starts on.',
  );
}
