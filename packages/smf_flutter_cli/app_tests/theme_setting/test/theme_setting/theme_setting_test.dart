// A test that continuous integration runs in the apps with the theme role
// and the settings screen role, whichever modules provide them: the
// settings screen shows the entry of the theme mode, which the template of
// the theme role gives it, once. The entry offers the mode of the device,
// the light mode and the dark mode, shows the mode of the app as the
// selected one, and a tap on a mode chooses it: the app is in that mode,
// its root takes it, and the entry shows it as selected. The entry keeps no
// mode of its own: it also shows a mode that other code chose.
//
// It knows only the roles. The entry is the role's own, the same with every
// provider: a RadioGroup of the modes with a RadioListTile for each. The
// matrix writes theme_setting.dart next to this file, from the data of the
// settings screen role of the app: the location of the settings screen and
// the type of the widget of the entry. It also fills in the key of the
// theme mode in the preferences. The app starts once, with main() of
// lib/main.dart, since the start-up of an app may not run twice, with the
// mocks of the platform side of every module of the app
// (flutter_test_config.dart), and goes to the settings screen with go() of
// the navigator of the router role. Each expectation gives its reason.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/theme/theme_mode.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'theme_setting.dart';

/// The key of the theme mode in the preferences of the app, under which
/// the theme role saves the name of the mode.
const String _modeKey = '{{mode_key}}';

/// The height of the surface of the test: a screen may build the rows of
/// its list only as they come into view, and this one is tall enough for
/// the entries of an app to be all in view, some seventy rows.
const double _height = 4000;

/// Starts the app on a tall surface, as on a device, with what its main()
/// puts around it, and goes to the settings screen, the location of the
/// route that the provider of the settings screen role names, from the
/// navigator of the page that the user sees.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time
/// of the test waiting forever. An error of main() fails the test, which
/// tester.runAsync would only report to the handler of the errors of
/// Flutter. The handlers of errors that the start-up installs, such as
/// those of crash reporting, and the builder of the widget of an error go
/// back to those of the test once main() returns, so that flutter_test
/// reports an expectation that fails as in any test.
Future<void> _openSettings(WidgetTester tester) async {
  tester.view
    ..physicalSize = const Size(800, _height)
    ..devicePixelRatio = 1;
  addTearDown(tester.view.reset);
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
  appRouter
      .navigatorOf(tester.element(find.byType(Navigator).last))
      .go(settingsLocation);
  await tester.pumpAndSettle();
}

/// Puts the app back into the mode of the device, with no mode saved, as
/// the test found it: the mode of the app and the preferences of its last
/// start outlive a test. A tear-down of the test, which runs in real time,
/// so it also waits for what the taps of the test saved.
Future<void> _forgetMode() async {
  await appThemeMode.choose(ThemeMode.system);
  await createAppPreferences().remove(_modeKey);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the settings screen shows the entry of the theme mode, which shows '
    'the mode of the app and chooses the mode that the user taps',
    (tester) async {
      addTearDown(_forgetMode);
      await _openSettings(tester);

      final entry = find.byType(themeModeEntry);
      expect(
        entry,
        findsOneWidget,
        reason: 'The settings screen shows the entry of the theme mode once.',
      );
      Finder option(ThemeMode mode) => find.descendant(
            of: entry,
            matching: find.byWidgetPredicate(
              (widget) =>
                  widget is RadioListTile<ThemeMode> && widget.value == mode,
            ),
          );
      for (final mode in ThemeMode.values) {
        expect(
          option(mode),
          findsOneWidget,
          reason: 'The entry offers each mode once: that of the device, the '
              'light one and the dark one.',
        );
      }
      ThemeMode? selected() => tester
          .widget<RadioGroup<ThemeMode>>(
            find.descendant(
              of: entry,
              matching: find.byType(RadioGroup<ThemeMode>),
            ),
          )
          .groupValue;
      expect(
        appThemeMode.value,
        ThemeMode.system,
        reason: 'An app in which no mode was chosen follows the device.',
      );
      expect(
        selected(),
        ThemeMode.system,
        reason: 'The entry shows the mode of the app as the selected one.',
      );

      // The mode of the device last: the app is in another mode by then, so
      // the tap changes the mode.
      for (final mode in const [
        ThemeMode.dark,
        ThemeMode.light,
        ThemeMode.system,
      ]) {
        await tester.tap(option(mode));
        await tester.pumpAndSettle();

        expect(
          appThemeMode.value,
          mode,
          reason: 'A tap on a mode of the entry chooses it as the mode of '
              'the app.',
        );
        expect(
          tester.widget<MaterialApp>(find.byType(MaterialApp).first).themeMode,
          mode,
          reason: 'The root of the app takes the mode that the user chose in '
              'the entry.',
        );
        expect(
          selected(),
          mode,
          reason: 'The entry shows the mode that the user chose as the '
              'selected one.',
        );
      }

      // A choice that other code makes, as a screen of the app may. The app
      // is in the mode of the device by now, so the choice changes the mode.
      await tester.runAsync(() => appThemeMode.choose(ThemeMode.dark));
      await tester.pumpAndSettle();
      expect(
        selected(),
        ThemeMode.dark,
        reason: 'The entry shows the mode that other code chose: it reads '
            'the mode of the app, and keeps none of its own.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
