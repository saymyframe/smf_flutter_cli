// A test that continuous integration runs in the apps with the settings
// module: the settings screen has a back button, in an app bar, only when a
// screen below it is there to go back to. Alone in its stack, as go() of
// the router role shows it and as a destination of the main navigation has
// it, the screen has neither. Shown on top of another screen with push(),
// as the code of an app without a main navigation opens it, it has the
// button, which leads back.
//
// The matrix writes settings_of_app.dart next to this file, from the layout
// role of the app: whether the screen is a destination of the main
// navigation. The router role refuses to push a location of the main
// navigation over it, so the test pushes the screen only in an app where
// it is no destination.
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/settings/settings_screen.dart';

import 'settings_app.dart';
import 'settings_of_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the settings screen has a back button only on top of another screen, '
    'where the button leads back',
    (tester) async {
      await startApp(tester);
      final screen = find.byType(SettingsScreen);
      Finder onScreen(Type widget) =>
          find.descendant(of: screen, matching: find.byType(widget));

      if (!settingsInMainNavigation) {
        // On top of the screen that the app starts on, as the code of the
        // app opens it. The future of push() completes when the screen
        // closes, so nothing waits for it here.
        unawaited(
          appRouter
              .navigatorOf(tester.element(find.byType(Navigator).last))
              .push<void>(const SettingsSettingsLocation()),
        );
        await tester.pumpAndSettle();
        expect(
          screen,
          findsOneWidget,
          reason: 'push() shows the settings screen on top of the screen '
              'that the app starts on.',
        );
        expect(
          onScreen(BackButton),
          findsOneWidget,
          reason: 'On top of another screen, the settings screen has a back '
              'button.',
        );

        await tester.tap(onScreen(BackButton));
        await tester.pumpAndSettle();
        expect(
          screen,
          findsNothing,
          reason: 'The back button of the settings screen leads back to the '
              'screen below it.',
        );
      }

      await goToSettings(tester);
      expect(
        onScreen(BackButton),
        findsNothing,
        reason: 'Alone in its stack, the settings screen has no back '
            'button: nothing is below it to go back to.',
      );
      expect(
        onScreen(AppBar),
        findsNothing,
        reason: 'Without a back button to show, the settings screen has no '
            'app bar above its title.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
