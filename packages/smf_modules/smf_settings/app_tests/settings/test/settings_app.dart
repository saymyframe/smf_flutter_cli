// What the tests of the settings module share, in the apps with the module:
// the name of the app as the module writes it, the start of the app with
// main() of lib/main.dart, which the app entry role puts into every app,
// what runs in real time, the way to the settings screen through the
// navigation of the router role, and the last row of the screen.
//
// The matrix sets up the mocks of the platform side of every module of the
// app before the tests of each test file (flutter_test_config.dart), so
// the start-up runs whatever other modules the app has.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/settings/settings_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

/// The name of the app as the module writes it: the name of its package
/// in title case, such as `My App` for `my_app`.
final String appName = '{{app_name}}'
    .split('_')
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as a timer or the platform side of a module,
/// does not keep the fake time of the test waiting forever. An error of
/// [action] fails the test, which tester.runAsync would only report to the
/// handler of the errors of Flutter.
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

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, as the start-up of a module may wait for a
/// timer or for input and output. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the
/// widget of an error go back to those of the test once main() returns.
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

/// Goes to the settings screen from the navigator of the page that the
/// user sees.
Future<void> goToSettings(WidgetTester tester) async {
  appRouter
      .navigatorOf(tester.element(find.byType(Navigator).last))
      .go(const SettingsSettingsLocation());
  await tester.pumpAndSettle();
  expect(
    find.byType(SettingsScreen),
    findsOneWidget,
    reason: 'The route of the module shows the settings screen.',
  );
}

/// Scrolls the list of the settings screen to its last row, which tells
/// what the app is, and returns the row.
///
/// The list builds its rows as they come into view, and the entries of the
/// other modules of the app come before the row.
Future<Finder> showAboutRow(WidgetTester tester) async {
  final list = find.descendant(
    of: find.byType(SettingsScreen),
    matching: find.byType(Scrollable),
  );
  final about = find.descendant(
    of: find.byType(SettingsScreen),
    matching: find.byType(AboutListTile),
  );
  await tester.scrollUntilVisible(about, 200, scrollable: list.first);
  expect(about, findsOneWidget, reason: 'The screen has the row once.');
  expect(
    tester.widgetList(find.descendant(of: list.first, matching: about)).length,
    1,
    reason: 'The row is in the list of the screen.',
  );
  return about;
}
