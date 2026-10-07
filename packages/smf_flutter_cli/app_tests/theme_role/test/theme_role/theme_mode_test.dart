// A test that continuous integration runs in the apps with the theme role,
// whichever module provides it: the app shows the theme mode that is
// chosen. The root MaterialApp of the app takes the mode, and the screen
// below it gets the light theme of the provider of the role in the light
// mode and its dark theme in the dark mode, and in the mode of the device
// the one that the device asks for.
//
// It is a test of the app entry role too: the root gets the mode from an
// inherited widget around it, which the arguments of the root read from its
// context, so the root must rebuild when that widget notifies, whichever
// module provides the app entry. And the root asks the system for the icons
// of the status bar that suit the theme, dark ones on a light theme and
// light ones on a dark theme, with the widget that the template of that
// role puts around every route.
//
// It knows only the roles. The app starts once, with main() of
// lib/main.dart, since the start-up of an app may not run twice, with the
// mocks of the platform side of every module of the app, which the matrix
// sets up before the tests of each test file (flutter_test_config.dart).
// Each expectation gives its reason, which a provider of a role with a
// known bug fails the test with (brokenProviders of the fixture registry).
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/theme/app_theme.dart';
import 'package:{{app_name}}/core/theme/theme_mode.dart';
import 'package:{{app_name}}/main.dart' as app;

import 'theme_role.dart';

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
/// reports an expectation that fails as in any test.
Future<void> _startApp(WidgetTester tester) async {
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

/// The root MaterialApp of the app.
Finder get _root => find.byType(MaterialApp).first;

/// Why the root has the mode that was chosen.
const String _rootFollows = 'The root of the app rebuilds when the mode '
    'that its arguments read from its context changes, and takes the mode '
    'that was chosen.';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the app shows the mode that is chosen: its root takes the mode, and '
    'the screen below it gets the light or the dark theme of the app',
    (tester) async {
      final device = tester.platformDispatcher
        ..platformBrightnessTestValue = Brightness.light;
      addTearDown(device.clearPlatformBrightnessTestValue);
      addTearDown(forgetMode);
      await _startApp(tester);

      ThemeMode? modeOfRoot() => tester.widget<MaterialApp>(_root).themeMode;
      // The context that the root calls the functions of the provider with:
      // below what main() puts around the root.
      BuildContext contextOfRoot() => tester.element(_root);
      // The theme that a screen gets: that of the navigator of the app,
      // which the root shows its screens in.
      ThemeData shown() => Theme.of(
            tester.element(
              find
                  .descendant(of: _root, matching: find.byType(Navigator))
                  .first,
            ),
          );
      // The icons of the status bar that the root asks the system for: those
      // of the region around the navigator of the app. A screen with an app
      // bar has a region of its own below it, for the icons that suit its
      // bar, which are up to the theme of the bar.
      Brightness? iconsOfRoot() {
        final regions =
            tester.widgetList<AnnotatedRegion<SystemUiOverlayStyle>>(
          find.ancestor(
            of: find
                .descendant(of: _root, matching: find.byType(Navigator))
                .first,
            matching: find.byType(AnnotatedRegion<SystemUiOverlayStyle>),
          ),
        );
        return regions.isEmpty
            ? null
            : regions.first.value.statusBarIconBrightness;
      }

      expect(
        appThemeMode.value,
        ThemeMode.system,
        reason: 'An app in which no mode was chosen follows the device.',
      );
      expect(
        modeOfRoot(),
        ThemeMode.system,
        reason: 'The root of the app has the mode of the app.',
      );
      expect(
        shown().brightness,
        Brightness.light,
        reason: 'In the mode of the device, the theme of the app is light on '
            'a light device.',
      );
      expect(
        shown().colorScheme,
        createLightTheme(contextOfRoot()).colorScheme,
        reason: 'The light theme of the app is the one that the provider of '
            'the theme role creates for the root.',
      );
      expect(
        iconsOfRoot(),
        Brightness.dark,
        reason: 'On a light theme, the root of the app asks the system for '
            'dark icons of the status bar, around every route.',
      );

      await chooseMode(tester, ThemeMode.dark);
      expect(modeOfRoot(), ThemeMode.dark, reason: _rootFollows);
      expect(
        shown().brightness,
        Brightness.dark,
        reason: 'In the dark mode, the theme of the app is dark.',
      );
      expect(
        shown().colorScheme,
        createDarkTheme(contextOfRoot()).colorScheme,
        reason: 'The dark theme of the app is the one that the provider of '
            'the theme role creates for the root.',
      );
      expect(
        iconsOfRoot(),
        Brightness.light,
        reason: 'On a dark theme, the root of the app asks the system for '
            'light icons of the status bar, around every route.',
      );

      // The device goes dark, and the light mode is chosen.
      device.platformBrightnessTestValue = Brightness.dark;
      await chooseMode(tester, ThemeMode.light);
      expect(modeOfRoot(), ThemeMode.light, reason: _rootFollows);
      expect(
        shown().brightness,
        Brightness.light,
        reason: 'In the light mode, the theme of the app is light, on a dark '
            'device too.',
      );

      // Back to the mode of the device, which is dark.
      await chooseMode(tester, ThemeMode.system);
      expect(modeOfRoot(), ThemeMode.system, reason: _rootFollows);
      expect(
        shown().brightness,
        Brightness.dark,
        reason: 'In the mode of the device, the theme of the app is dark on '
            'a dark device.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
