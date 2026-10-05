// What the tests of the theme role share, in the apps with the role,
// whichever module provides it: the key of the theme mode in the
// preferences, a choice of a mode that waits until the mode is saved, and
// what puts the app back as a test found it.
//
// It knows only the role, and the preferences role that it requires. The
// matrix fills in the key, which the role publishes.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/core/theme/theme_mode.dart';

/// The key of the theme mode in the preferences of the app, under which
/// the role saves the name of the mode.
const String modeKey = '{{mode_key}}';

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

/// Chooses [mode] as the mode of the app, as code of the app does, waits
/// until the choice is saved, and then until the app shows it.
Future<void> chooseMode(WidgetTester tester, ThemeMode mode) async {
  await inRealTime(
    tester,
    'choosing ${mode.name}',
    () => appThemeMode.choose(mode),
  );
  await tester.pumpAndSettle();
}

/// Puts the app back into the mode of the device, with no mode saved, as a
/// test found it: the mode of the app and the preferences of its last
/// start outlive a test. A tear-down of a test, which runs in real time.
Future<void> forgetMode() async {
  await appThemeMode.choose(ThemeMode.system);
  await createAppPreferences().remove(modeKey);
}
