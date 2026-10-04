// A test that continuous integration runs in the apps with the preferences
// role, whichever module provides it: through the preferences of the role,
// a value of each type is read back as it was saved, and as null by the
// reads of the other types, which do not throw; a key that was removed has
// no value; a write replaces what its key had, a value of another type
// too; the preferences keep a copy of a list that they are given, and a
// read returns a copy of it; and the next start of the app reads what was
// saved, and nothing that was removed.
//
// It knows only the role, and writes only keys of its own. The start-up of
// the app runs first, as on a device, since it opens the preferences, with
// the mocks of the platform side of every module of the app, which the
// matrix sets up before the tests of each test file
// (flutter_test_config.dart). The next start is initPreferences() of the
// role again, which opens the preferences anew. The probe of the role
// (integration_test/preferences_role/probe.dart), which the start check
// runs on a device, has the checks of one run, and the last test runs the
// probe itself, as the start check does. Each expectation gives its
// reason, which a provider of the role with a known bug fails the test
// with (brokenProviders of the fixture registry). Whether a number saved
// as an int is read as a double, or the other way round, is up to the
// provider, as the role says, so the test does not look.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/bootstrap.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

import '../integration_test/preferences_role/probe.dart';

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of the preferences, does
/// not wait for the fake time of the test. An error of [action] fails the
/// test, which tester.runAsync would only report to the handler of the
/// errors of Flutter.
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
      await _inRealTime(tester, 'bootstrap()', bootstrap);
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
    'a value of each type is read back as it was saved',
    (tester) async {
      await _startUp(tester);
      var problems = <String>[];

      await _inRealTime(tester, 'saving and reading values', () async {
        final preferences = createAppPreferences();
        await saveValues(preferences);
        problems = problemsOfSavedValues(preferences);
        await removeValues(preferences);
      });

      expect(
        problems,
        isEmpty,
        reason: 'A value that was saved is read back as it was saved.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a read of a key with a value of another type returns null, and does '
    'not throw',
    (tester) async {
      await _startUp(tester);
      var problems = <String>[];

      await _inRealTime(tester, 'saving and reading values', () async {
        final preferences = createAppPreferences();
        await saveValues(preferences);
        problems = problemsOfOtherTypes(preferences);
        await removeValues(preferences);
      });

      expect(
        problems,
        isEmpty,
        reason: 'A read returns null when the key has no value of the type '
            'it asks for, and never throws.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a key that was removed has no value',
    (tester) async {
      await _startUp(tester);
      var problems = <String>[];

      await _inRealTime(tester, 'saving and removing values', () async {
        problems = await problemsOfRemoval(createAppPreferences());
      });

      expect(
        problems,
        isEmpty,
        reason: 'The reads of a key that was removed return null, and '
            'removing a key without a value does not throw.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a write replaces what its key had, a value of another type too',
    (tester) async {
      await _startUp(tester);
      var problems = <String>[];

      await _inRealTime(tester, 'saving twice under a key', () async {
        problems = await problemsOfOverwriting(createAppPreferences());
      });

      expect(
        problems,
        isEmpty,
        reason: 'A key has one value: a write replaces what the key had, '
            'whatever its type.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the preferences keep a copy of a list that they are given',
    (tester) async {
      await _startUp(tester);
      var problems = <String>[];

      await _inRealTime(tester, 'saving a list and changing it', () async {
        problems = await problemsOfSavedLists(createAppPreferences());
      });

      expect(
        problems,
        isEmpty,
        reason: 'A change of a list that was saved changes nothing that the '
            'preferences have.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a read returns a copy of the list that the preferences have',
    (tester) async {
      await _startUp(tester);
      var problems = <String>[];

      await _inRealTime(tester, 'reading a list and changing it', () async {
        problems = await problemsOfReadLists(createAppPreferences());
      });

      expect(
        problems,
        isEmpty,
        reason: 'A change of a list that was read changes nothing that the '
            'preferences have.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the next start reads what was saved, and nothing that was removed',
    (tester) async {
      await _startUp(tester);
      var saved = <String>[];
      var removed = <String>[];

      await _inRealTime(tester, 'saving, removing and starting again',
          () async {
        await saveValues(createAppPreferences());
        // The next start: it opens the preferences anew.
        await initPreferences();
        saved = problemsOfSavedValues(createAppPreferences());
        await removeValues(createAppPreferences());
        await initPreferences();
        removed = problemsOfRemovedValues(createAppPreferences());
      });

      expect(
        saved,
        isEmpty,
        reason: 'The next start reads what was saved.',
      );
      expect(
        removed,
        isEmpty,
        reason: 'The next start reads nothing that was removed.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the probe of the role finds no problem',
    (tester) async {
      await _startUp(tester);
      var problems = <String>[];

      await _inRealTime(tester, 'the probe of the role', () async {
        // As the start check runs it on a device; it waits for no screen.
        problems = await probePreferences(() async {});
      });

      expect(
        problems,
        isEmpty,
        reason: 'The probe finds no problem with preferences that keep the '
            'contract of the role in one run of the app.',
      );
    },
    timeout: timeout,
  );
}
