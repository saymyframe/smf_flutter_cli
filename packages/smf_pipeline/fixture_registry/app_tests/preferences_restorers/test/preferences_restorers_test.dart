// A test that continuous integration runs in the apps of the fixture
// modules with the preferences role, whichever module provides it, and
// with the fixture setting (fake_preferences_user), which gives the role
// two restorers (PreferencesRole.restorers): the start-up of the app gives
// each restorer the preferences of the app once; a setting that nothing
// saved keeps the value it had before the start; a restorer reads at the
// next start what its module saved; and the role calls each restorer on
// its own, so that one that throws keeps no other from restoring and does
// not stop the start. Both restorers throw once they did their work, so the
// test fails whichever of them the role calls first when one that throws
// stops the others.
//
// The start-up runs as on a device, with the mocks of the platform side of
// every module of the app, which the matrix sets up before the tests of
// each test file (flutter_test_config.dart). The next start is
// initPreferences() of the role again, which opens the preferences anew and
// calls the restorers again. Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/fixture_setting/fixture_setting.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as a timer or the platform side of the
/// preferences, does not keep the fake time of the test waiting forever. An
/// error of [action] fails the test, which tester.runAsync would only
/// report to the handler of the errors of Flutter.
Future<void> _inRealTime(
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

/// The value that the fixture setting gets before the start-up of the app,
/// when the preferences are not open yet.
const _beforeStart = 3;

/// The problem of the start-up of the app, which runs once for the tests of
/// the file: `null` before it runs, and empty if it passed.
String? _startUpProblem;

/// What the restorers of the fixture read at the start-up of the app.
List<(String, int?)> _restoredAtStart = const [];

/// The value of the fixture setting once the start-up of the app returned.
int? _settingAfterStart;

/// Sets the fixture setting, which changes only memory before the
/// preferences are open, and runs the start-up of the app, bootstrap(), as
/// main() runs it before the first frame, in real time, unless a test of
/// the file ran it already, and fails the test if it failed. The handlers
/// of errors that the start-up installs, such as those of crash reporting,
/// and the builder of the widget of an error go back to those of the test
/// once it returns.
Future<void> _startUp(WidgetTester tester) async {
  if (_startUpProblem == null) {
    final onError = FlutterError.onError;
    final onPlatformError = PlatformDispatcher.instance.onError;
    final errorWidgetBuilder = ErrorWidget.builder;
    try {
      _startUpProblem = '';
      await _inRealTime(tester, 'bootstrap()', () async {
        await fixtureSetting.set(_beforeStart);
        await bootstrap();
      });
      _restoredAtStart = [...fixtureRestored];
      _settingAfterStart = fixtureSetting.value;
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

/// The names of the restorers of the fixture that ran, in order.
List<String> _ran() => [for (final (name, _) in fixtureRestored) name];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the start-up gives each restorer the preferences once, and a setting '
    'that nothing saved keeps the value it had before',
    (tester) async {
      await _startUp(tester);

      expect(
        _restoredAtStart,
        [('note', null), ('setting', null)],
        reason: 'The start-up calls each restorer once, in the order of the '
            'restorers, with preferences in which nothing is saved yet.',
      );
      expect(
        _settingAfterStart,
        _beforeStart,
        reason: 'A setting that nothing saved keeps the value that it got '
            'before the preferences were open.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a restorer reads at the next start what its module saved',
    (tester) async {
      await _startUp(tester);

      await _inRealTime(tester, 'saving and starting again', () async {
        // The setting saves 7, and the preferences of the app then 9 under
        // its key, which only the next start reads.
        await fixtureSetting.set(7);
        await createAppPreferences().setInt(fixtureSettingKey, 9);
        fixtureRestored.clear();
        await initPreferences();
      });

      expect(
        fixtureRestored,
        [('note', 9), ('setting', 9)],
        reason: 'Each restorer reads at the next start what was saved.',
      );
      expect(
        fixtureSetting.value,
        9,
        reason: 'The restorer of the setting takes at the next start the '
            'value that was saved.',
      );

      // The setting writes to the preferences that its restorer got last.
      await _inRealTime(tester, 'saving after the next start', () async {
        await fixtureSetting.set(11);
      });
      expect(
        createAppPreferences().getInt(fixtureSettingKey),
        11,
        reason: 'The setting saves to the preferences that the next start '
            'opened.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a restorer that throws keeps no other from restoring, and does not '
    'stop the start',
    (tester) async {
      await _startUp(tester);
      fixtureRestored.clear();
      fixtureRestorersThrow = true;
      try {
        // What a restorer throws would fail the start, and the test with
        // it.
        await _inRealTime(tester, 'initPreferences()', initPreferences);
      } finally {
        fixtureRestorersThrow = false;
      }

      expect(
        _ran(),
        ['note', 'setting'],
        reason: 'A restorer that throws keeps no other from restoring.',
      );

      // The restorers run at the next start as before.
      fixtureRestored.clear();
      await _inRealTime(tester, 'initPreferences()', initPreferences);
      expect(
        _ran(),
        ['note', 'setting'],
        reason: 'Each restorer runs again at the next start.',
      );
    },
    timeout: timeout,
  );
}
