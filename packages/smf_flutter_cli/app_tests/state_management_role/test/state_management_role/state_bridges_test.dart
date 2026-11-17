// A test that continuous integration runs in the apps whose modules and
// roles give the state management role values that their controllers keep,
// such as the theme mode or the session of sign-in, whichever modules
// provide the roles: the state manager of the app follows each value
// through a bridge of its own, which has the value of the controller at the
// start of the app and once the controller changed it.
//
// It knows only the roles. The matrix writes the entries of the app into
// of_app.dart, from the data of the state management role: the name of each
// value, the function that returns its listenable, and a watcher, a widget
// that reads its bridge as the code of the app does, which the provider of
// the role gives. And the changes that the test makes through the
// controllers of the roles of the app. The app starts once, with main() of
// lib/main.dart, with the mocks of the platform side of every module of the
// app, which the matrix sets up before the tests of each test file
// (flutter_test_config.dart). Each expectation gives its reason, which a
// provider of the role with a known bug fails the test with
// (brokenProviders of the fixture registry).
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'of_app.dart';

/// Why the watcher of an entry has the value of its listenable.
const String _follows = 'The bridge of an entry gives the value that the '
    'controller of the entry has, also once that value changed.';

/// How long the test shows frames at most for the watchers to follow a
/// change, rather than waiting for the screens to settle: a screen of a
/// module may animate without end, and a bridge that does not follow fails
/// with the reason of the expectation rather than a timeout.
const Duration _followWait = Duration(seconds: 2);

/// The time between two frames that the test shows while it waits.
const Duration _frame = Duration(milliseconds: 100);

/// Runs [action], which [what] names, in real time, as on a device, so that
/// what it waits for, such as the platform side of a module, does not wait
/// for the fake time of the test. An error of [action] fails the test,
/// which tester.runAsync would only report to the handler of the errors of
/// Flutter.
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

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time of
/// the test waiting forever. An error of main() fails the test. An error of
/// bootstrap() reaches FlutterError.onError through main(), which fails the
/// test too. The handlers of errors that the start-up installs, such as
/// those of crash reporting, and the builder of the widget of an error go
/// back to those of the test once main() returns, so that flutter_test
/// reports an expectation that fails as in any test.
Future<void> _startApp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  try {
    await _inRealTime(tester, 'main()', app.main);
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
  await tester.pumpAndSettle();
}

/// Shows frames for at most [_followWait] until [done] holds.
Future<void> _showFramesUntil(
  WidgetTester tester,
  bool Function() done,
) async {
  for (var shown = Duration.zero;
      shown < _followWait && !done();
      shown += _frame) {
    await tester.pump(_frame);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the state manager follows each value that a controller of the app '
    'keeps through its bridge, at the start and once the controller changed '
    'the value',
    (tester) async {
      await _startApp(tester);

      // The value that the watcher of each entry built with last, by the
      // name of the entry.
      final seen = <String, Object?>{};
      final watchers = [
        for (final entry in bridgeEntries)
          OverlayEntry(
            builder: (_) => entry.watch((value) => seen[entry.name] = value),
          ),
      ];
      // The overlay of the navigator at the root of the app is below what
      // main() puts around the root, where a provider of the role puts what
      // its bridges need. A guard of the routes that shows its target in
      // place of the pages leaves the entries of the test there.
      tester
          .state<NavigatorState>(find.byType(Navigator).first)
          .overlay!
          .insertAll(watchers);

      bool followed() => bridgeEntries.every(
            (entry) =>
                seen.containsKey(entry.name) &&
                seen[entry.name] == entry.listenable().value,
          );
      await _showFramesUntil(tester, followed);
      for (final entry in bridgeEntries) {
        expect(
          identical(entry.listenable(), entry.listenable()),
          isTrue,
          reason: 'The function of the entry ${entry.name} returns the same '
              'listenable at each call, which its bridge follows.',
        );
        expect(
          seen.keys,
          contains(entry.name),
          reason: 'The watcher of the entry ${entry.name} reads its bridge '
              'below the root of the app.',
        );
        expect(
          seen[entry.name],
          entry.listenable().value,
          reason: 'At the start, ${entry.name}: $_follows',
        );
      }

      for (final change in bridgeChanges) {
        final changed = bridgeEntries.singleWhere(
          (entry) => entry.name == change.entry,
        );
        final before = changed.listenable().value;
        await _inRealTime(tester, change.what, change.change);
        final after = changed.listenable().value;
        expect(
          after,
          isNot(before),
          reason: '${change.what} changes the value of ${change.entry}.',
        );

        await _showFramesUntil(
          tester,
          () => seen[change.entry] == after && followed(),
        );
        for (final entry in bridgeEntries) {
          expect(
            seen[entry.name],
            entry.listenable().value,
            reason: 'After ${change.what}, ${entry.name}: $_follows',
          );
        }
      }

      for (final watcher in watchers) {
        watcher
          ..remove()
          ..dispose();
      }
      await tester.pump();
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
