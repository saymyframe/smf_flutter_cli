// A test that continuous integration runs in the apps of the fixture
// modules with a router, whichever module provides it, the fixture gates
// and no route that the app starts on: the guards of the routes of the
// router role keep the user from the fallback screen of the app entry too,
// the location `/`, which is no route of a module, as
// RouterRole.guardedNavigation says. With the first gate closed before the
// app starts, the router shows the target of its guard and does not build
// the fallback screen; once the gate opens, it shows the fallback screen;
// when the gate closes, the target takes its place, and the router comes
// back to it. And when the guard starts allowing while its flow is shown
// with nothing to come back to, the screen that the app starts on is the
// fallback screen. It starts the app with main() of lib/main.dart, which
// the app entry role puts into every app, so it applies to a new provider
// of the router role as it is.
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/app/fallback_start_screen.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gate_screens.dart';
import 'package:{{app_name}}/features/fake_gate/fixture_gates.dart';
import 'package:{{app_name}}/main.dart' as app;

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
/// reports the errors of the frames that follow, and an expectation that
/// fails, as in any test.
Future<void> _startApp(WidgetTester tester) async {
  final onError = FlutterError.onError;
  final onPlatformError = PlatformDispatcher.instance.onError;
  final errorWidgetBuilder = ErrorWidget.builder;
  Object? error;
  StackTrace? stackTrace;
  try {
    await tester.runAsync(() async {
      try {
        await app.main();
      } on Object catch (thrown, stack) {
        error = thrown;
        stackTrace = stack;
      }
    });
  } finally {
    FlutterError.onError = onError;
    PlatformDispatcher.instance.onError = onPlatformError;
    ErrorWidget.builder = errorWidgetBuilder;
  }
  if (error != null) fail('main() threw $error\n$stackTrace');
  await tester.pumpAndSettle();
}

/// The screens of the fallback screen and of the fixture gates that the
/// router built, one for each page of its stack, from the page at the
/// bottom to the page on top.
List<Type> _builtScreens(WidgetTester tester) => [
      for (final widget in tester.allWidgets)
        if (const {
          FallbackStartScreen,
          FixtureGateScreen,
          FixtureGateStepScreen,
          FixtureSecondGateScreen,
        }.contains(widget.runtimeType))
          widget.runtimeType,
    ];

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the guards keep the user from the fallback screen too, and the router '
    'comes back to it',
    (tester) async {
      // The app starts as on a device, with the first gate closed.
      fixtureGate.value = false;
      fixtureSecondGate.value = true;
      await _startApp(tester);
      expect(
        _builtScreens(tester),
        [FixtureGateScreen],
        reason: 'The target of a guard that does not allow takes the place '
            'of the fallback screen, which the router does not build.',
      );

      // The gate opens: the fallback screen, which the app starts on.
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        _builtScreens(tester),
        [FallbackStartScreen],
        reason: 'Once the guards allow, the router shows the fallback '
            'screen, which they kept the user from.',
      );

      // The gate closes and opens: the target takes the place of the
      // fallback screen, and the router comes back to it.
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        _builtScreens(tester),
        [FixtureGateScreen],
        reason: 'When a guard stops allowing, its target takes the place of '
            'the fallback screen.',
      );
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        _builtScreens(tester),
        [FallbackStartScreen],
        reason: 'Once a guard allows again, the router comes back to the '
            'fallback screen.',
      );

      // Into the flow while the guard allows, and then the gate closes and
      // opens: with nothing to come back to, the router shows the screen
      // that the app starts on, the fallback screen.
      tester.element(find.byType(FallbackStartScreen)).nav.fakeGate.step().go();
      await tester.pumpAndSettle();
      expect(
        _builtScreens(tester),
        [FixtureGateScreen, FixtureGateStepScreen],
        reason: 'With guards that allow, a route of a flow is a route like '
            'any other.',
      );
      fixtureGate.value = false;
      await tester.pumpAndSettle();
      expect(
        _builtScreens(tester),
        [FixtureGateScreen, FixtureGateStepScreen],
        reason: 'A guard that stops allowing leaves the pages of its flow as '
            'they are.',
      );
      fixtureGate.value = true;
      await tester.pumpAndSettle();
      expect(
        _builtScreens(tester),
        [FallbackStartScreen],
        reason: 'When a guard starts allowing while a page of its flow is on '
            'top and there is no location to come back to, the router shows '
            'the screen that the app starts on: the fallback screen.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
