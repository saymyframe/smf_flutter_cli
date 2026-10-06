// A test that continuous integration runs in the apps with the settings
// module: the app starts and goes to the settings screen. The last row of
// the screen, which tells what the app is, opens the about dialog of
// Flutter with the name of the app, and the dialog opens the page with the
// licenses of the packages of the app.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'settings_app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the last row of the settings screen opens the about dialog with the '
    'name of the app, and the dialog the licenses',
    (tester) async {
      await startApp(tester);
      await goToSettings(tester);
      final about = await showAboutRow(tester);

      await tester.tap(about);
      await tester.pumpAndSettle();
      final dialog = find.byType(AboutDialog);
      expect(dialog, findsOneWidget, reason: 'The row opens the dialog.');
      expect(
        find.descendant(of: dialog, matching: find.text(appName)),
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
        appName,
        reason: 'The dialog opens the licenses of the app.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
