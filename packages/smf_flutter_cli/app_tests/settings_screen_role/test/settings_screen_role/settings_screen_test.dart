// A test that continuous integration runs in the apps with the settings
// screen role, whichever module provides it: the route that the provider
// names as the settings screen (SettingsScreenRoute) shows the screen of
// the route, so code that knows only the role finds the screen of any
// provider.
//
// It knows only the role, and starts the app once, since the start-up of
// an app may not run twice. The expectation gives its reason.
import 'package:flutter_test/flutter_test.dart';

import 'open_settings.dart';
import 'settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'the route of the settings screen shows the screen',
    (tester) async {
      await openSettings(tester);

      expect(
        find.byType(settingsScreen),
        findsOneWidget,
        reason: 'The location of the route that the provider names shows the '
            'settings screen.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
