// A test that continuous integration runs in the apps of the fixture
// modules with the fixture theme, a provider of the theme role whose look
// depends on state of its own: its themes derive their colours from a
// colour that the fixture keeps, which they read from the context of the
// root of the app, through a widget that the fixture puts around the root.
// When the colour changes, the screens of the app get the themes of the
// new colour, the light one and the dark one.
//
// It is a test of the app entry role: the two functions of the theme role
// take the context of the root so that a provider can read such a widget
// there, and the root must rebuild when the widget notifies, whichever
// module provides the app entry. The app starts with main() of
// lib/main.dart, which the app entry role puts into every app. The mode of
// the app stays that of the device, so the test saves nothing. Each
// expectation gives its reason, which a provider of the app entry with a
// known bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/theme/app_theme.dart';
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the screens get the themes of the colour that the fixture theme keeps, '
    'and those of another colour once it changes',
    (tester) async {
      const other = Color(0xFFE65100);
      final first = fixtureSeed.value;
      final device = tester.platformDispatcher
        ..platformBrightnessTestValue = Brightness.light;
      addTearDown(device.clearPlatformBrightnessTestValue);
      addTearDown(() => fixtureSeed.value = first);
      await _startApp(tester);

      // The theme that a screen gets: that of the navigator of the app,
      // which the root shows its screens in.
      ColorScheme shown() => Theme.of(
            tester.element(
              find
                  .descendant(
                    of: find.byType(MaterialApp).first,
                    matching: find.byType(Navigator),
                  )
                  .first,
            ),
          ).colorScheme;

      expect(first, isNot(other));
      expect(
        shown(),
        ColorScheme.fromSeed(seedColor: first),
        reason: 'On a light device, the screens are in the light theme of '
            'the colour that the fixture theme keeps.',
      );

      fixtureSeed.value = other;
      await tester.pumpAndSettle();
      expect(
        shown(),
        ColorScheme.fromSeed(seedColor: other),
        reason: 'The root of the app rebuilds in the new colours when the '
            'widget that its themes read the colour from notifies.',
      );

      // The device goes dark: the dark theme has the new colour too.
      device.platformBrightnessTestValue = Brightness.dark;
      await tester.pumpAndSettle();
      expect(
        shown(),
        ColorScheme.fromSeed(seedColor: other, brightness: Brightness.dark),
        reason: 'On a dark device, the screens are in the dark theme of the '
            'colour that the fixture theme keeps.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
