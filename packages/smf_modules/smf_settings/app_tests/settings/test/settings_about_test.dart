// A test that continuous integration runs in the apps with the settings
// module: the app starts with main() of lib/main.dart, which the app entry
// role puts into every app, and goes to the settings screen through the
// navigation of the router role. The last row of the screen, which tells
// what the app is, opens the about dialog of Flutter with the name of the
// app, and the dialog opens the page with the licenses of the packages of
// the app.
//
// The matrix sets up the mocks of the platform side of every module of the
// app before the tests of each test file (flutter_test_config.dart), so
// the start-up runs whatever other modules the app has.
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/router/app_router.dart';
import 'package:{{app_name}}/core/router/navigation.dart';
import 'package:{{app_name}}/features/settings/settings_screen.dart';
import 'package:{{app_name}}/main.dart' as app;

/// The name of the app as the module writes it: the name of its package
/// in title case, such as `My App` for `my_app`.
final String _appName = '{{app_name}}'
    .split('_')
    .map((word) => '${word[0].toUpperCase()}${word.substring(1)}')
    .join(' ');

/// Starts the app as on a device, with what its main() puts around it, and
/// waits for its first screen.
///
/// main() runs in real time, so a start-up that waits for a timer or for
/// input and output, as that of a module may, does not keep the fake time
/// of the test waiting forever. An error of main() fails the test, which
/// tester.runAsync would only report to the handler of the errors of
/// Flutter. The handlers of errors that the start-up installs, such as
/// those of crash reporting, and the builder of the widget of an error go
/// back to those of the test once main() returns.
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
    'the last row of the settings screen opens the about dialog with the '
    'name of the app, and the dialog the licenses',
    (tester) async {
      await _startApp(tester);
      // From the navigator of the page that the user sees.
      appRouter
          .navigatorOf(tester.element(find.byType(Navigator).last))
          .go(const SettingsSettingsLocation());
      await tester.pumpAndSettle();
      expect(
        find.byType(SettingsScreen),
        findsOneWidget,
        reason: 'The route of the module shows the settings screen.',
      );

      // The list builds its rows as they come into view, and the entries
      // of the other modules of the app come before the row.
      final list = find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(Scrollable),
      );
      final about = find.descendant(
        of: find.byType(SettingsScreen),
        matching: find.byType(AboutListTile),
      );
      await tester.scrollUntilVisible(about, 200, scrollable: list.first);
      expect(about, findsOneWidget, reason: 'The screen has the row once.');
      expect(
        tester
            .widgetList(find.descendant(of: list.first, matching: about))
            .length,
        1,
        reason: 'The row is in the list of the screen.',
      );

      await tester.tap(about);
      await tester.pumpAndSettle();
      final dialog = find.byType(AboutDialog);
      expect(dialog, findsOneWidget, reason: 'The row opens the dialog.');
      expect(
        find.descendant(of: dialog, matching: find.text(_appName)),
        findsOneWidget,
        reason: 'The about dialog names the app.',
      );

      // The page of the licenses reads them from the assets of the app in
      // real time, which the fake time of the test never lets finish, so
      // the test only waits for the page to come.
      final licenses = MaterialLocalizations.of(
        tester.element(dialog),
      ).viewLicensesButtonLabel;
      await tester
          .tap(find.descendant(of: dialog, matching: find.text(licenses)));
      await tester.pump();
      await tester.pump(const Duration(seconds: 1));
      expect(
        tester.widget<LicensePage>(find.byType(LicensePage)).applicationName,
        _appName,
        reason: 'The dialog opens the licenses of the app.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
