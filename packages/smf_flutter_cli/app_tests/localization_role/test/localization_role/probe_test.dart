// A test that continuous integration runs in the apps with the localization
// role, whichever module provides it: the probe of the role
// (integration_test/localization_role/probe.dart), which the start check
// runs on a device, finds no problem in an app that keeps the contract of
// the role, and puts back the choice of the user that it found.
//
// It runs the probe as the start check does, once the first screen of the
// app settled, and then once more on a device that prefers the last
// language of the app. There the probe finds the app in a language that it
// does not choose first, so what it checks before it chooses a language,
// the texts in the language that it finds, is no repeat of its first
// choice. The test does not start on such a device: in an app whose root
// cannot be in that language, Flutter would report the app before the
// probe ran. A provider of the role with a known bug fails the test with
// the problems that the probe finds (brokenProviders of the fixture
// registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/l10n/app_locale.dart';

import '../../integration_test/localization_role/probe.dart';
import 'app.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the probe of the role finds no problem',
    (tester) async {
      await startApp(tester);
      var problems = <String>[];

      await inRealTime(tester, 'the probe of the role', () async {
        problems = await probeLanguages(tester.pumpAndSettle);
      });

      expect(
        problems,
        isEmpty,
        reason: 'The probe finds no problem with an app that keeps the '
            'contract of the role.',
      );
      expect(
        appLocale.value,
        isNull,
        reason: 'The probe puts back the choice that it found.',
      );

      tester.platformDispatcher.localesTestValue = [appLocales.last];
      await tester.pumpAndSettle();
      expect(
        languageOnScreen(),
        appLocales.last.languageCode,
        reason: 'The app follows the device into the last of its languages, '
            'where the probe runs again.',
      );
      await inRealTime(
        tester,
        'the probe of the role on a device in another language',
        () async {
          problems = await probeLanguages(tester.pumpAndSettle);
        },
      );

      expect(
        problems,
        isEmpty,
        reason: 'The probe finds no problem with an app that follows a '
            'device in the last of its languages.',
      );
    },
    timeout: timeout,
  );
}
