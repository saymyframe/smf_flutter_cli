// A test that continuous integration runs in the apps with the theme role,
// whichever module provides it: the app remembers the theme mode. A choice
// of a mode is saved in the preferences of the app under the key of the
// role, as the name of the mode, and the next start of the app has the
// mode that is saved there.
//
// It knows only the role, and the preferences role that it requires,
// whichever modules provide them. The start-up of the app runs once, as on
// a device, since it opens the preferences, with the mocks of the platform
// side of every module of the app, which the matrix sets up before the
// tests of each test file (flutter_test_config.dart). The next start is
// initPreferences() of the preferences role again, which opens the
// preferences anew and calls the restorer of the mode. A test shows that a
// mode is restored by writing the key itself: after a choice, the app has
// the mode in memory already. Each expectation gives its reason.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/core/theme/theme_mode.dart';

import 'theme_role.dart';

/// The problem of the start-up of the app, which runs once for the tests of
/// the file: `null` before it runs, and empty if it passed.
String? _startUpProblem;

/// Runs the start-up of the app, bootstrap(), as main() runs it before the
/// first frame, in real time, unless a test of the file ran it already, and
/// fails the test if it failed. The handlers of errors that the start-up
/// installs, such as those of crash reporting, and the builder of the widget
/// of an error go back to those of the test once it returns.
Future<void> _startUp(WidgetTester tester) async {
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'a choice of a mode is saved under the key of the role, as the name of '
    'the mode',
    (tester) async {
      await _startUp(tester);
      addTearDown(forgetMode);

      // The mode of the device last: the app is in another mode by then, so
      // the choice changes the mode.
      for (final mode in const [
        ThemeMode.dark,
        ThemeMode.light,
        ThemeMode.system,
      ]) {
        await chooseMode(tester, mode);

        expect(
          createAppPreferences().getString(modeKey),
          mode.name,
          reason: 'Once the future of a choice completed, the preferences '
              'have the name of the mode under the key of the role.',
        );
      }
    },
    timeout: timeout,
  );

  testWidgets(
    'the next start of the app has the mode that is saved under the key of '
    'the role',
    (tester) async {
      await _startUp(tester);
      addTearDown(forgetMode);

      // Each differs from the mode that the app is in, so memory does not
      // have it.
      for (final mode in const [ThemeMode.dark, ThemeMode.light]) {
        await inRealTime(tester, 'saving a mode and starting again', () async {
          await createAppPreferences().setString(modeKey, mode.name);
          // The next start: it opens the preferences anew.
          await initPreferences();
        });

        expect(
          appThemeMode.value,
          mode,
          reason: 'The next start restores the mode whose name is saved '
              'under the key of the role.',
        );
      }
    },
    timeout: timeout,
  );
}
