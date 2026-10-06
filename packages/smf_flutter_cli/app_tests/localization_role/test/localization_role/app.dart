// What the tests of the localization role share, in the apps with the
// role, whichever module provides it: the app starts with main() of
// lib/main.dart, which the app entry role puts into every app, with no
// language chosen and none saved, on a device whose languages the test
// sets.
//
// The start-up of an app runs once in a test file, so each file of the
// tests has one test. The matrix sets up the mocks of the platform side of
// every module of the app before the tests of each test file
// (flutter_test_config.dart).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/l10n/app_locale.dart';
import 'package:{{app_name}}/main.dart' as app;

import '../../integration_test/localization_role/probe.dart';

/// A widget test fails after ten minutes by default; a test that hangs
/// fails sooner.
const timeout = Timeout(Duration(minutes: 2));

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

/// Starts the app as on a device that prefers the languages [device],
/// English by default, with what its main() puts around it, and waits for
/// its first screen. No language is chosen and none is saved.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time
/// of the test waiting forever. An error of main() fails the test. The
/// handlers of errors that the start-up installs, such as those of crash
/// reporting, and the builder of the widget of an error go back to those
/// of the test once main() returns, so that flutter_test reports the errors
/// of the frames that follow, and an expectation that fails, as in any
/// test.
Future<void> startApp(
  WidgetTester tester, {
  List<Locale> device = const [Locale('en', 'US')],
}) async {
  tester.platformDispatcher.localesTestValue = device;
  addTearDown(tester.platformDispatcher.clearLocalesTestValue);
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
  expect(
    appLocale.value,
    isNull,
    reason: 'An app that starts with nothing saved has no language chosen.',
  );
}

/// Fails the test unless the root of the app can be in each language of
/// the app. A test that puts the app into another language checks it
/// first, since Flutter reports an app in a language that a delegate of
/// its root does not support, and the code that reads its texts throws.
void expectEachLanguageSupported() => expect(
      problemsOfDelegates(),
      isEmpty,
      reason: 'For each language of the app, the root has a delegate of each '
          'kind of localizations that supports it.',
    );
