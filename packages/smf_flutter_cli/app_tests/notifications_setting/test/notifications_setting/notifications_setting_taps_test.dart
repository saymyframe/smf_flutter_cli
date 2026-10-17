// A test that continuous integration runs in the apps with the
// notifications role and the settings screen role, whichever modules
// provide them: what a tap on the entry of the notifications does, which
// the template of the notifications role gives the settings screen, over a
// service of the test that scripts what a provider answers. While the app
// has not asked, a tap asks the user once, and the entry shows what the
// user answered. Once the app asked, and while the app may show
// notifications, a tap opens the settings of the system and asks nothing.
// And the entry follows what the user changed there once the user comes
// back to the app.
//
// It knows only the two roles, and starts the app once, since the start-up
// of an app may not run twice. The matrix writes setting.dart next to it,
// from the entries of the settings screen role and the languages of the
// localization role of the app: the type of the widget of the entry and
// its texts in each language. It opens the settings screen as the tests of
// the settings screen role do, and takes the service of the tests, which
// scripts what a provider answers, from the files of the test of the
// notifications role, which every app with both roles has too. Each
// expectation gives its reason.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';

import '../notifications_role/notifications_role.dart';
import '../settings_screen_role/open_settings.dart';
import 'setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  testWidgets(
    'a tap on the entry of the notifications asks while the app has not '
    'asked, and opens the settings of the system after that, and the entry '
    'follows what the user changed there',
    (tester) async {
      await openSettings(tester);

      final entry = find.byType(notificationsSetting);
      // The texts of the entry in the language of the app, the first of the
      // app on the English device of the tests.
      final texts = settingTexts.values.first;
      // What the entry shows of whether the app may show notifications:
      // On, Off, or both or neither of them.
      String shown() {
        bool shows(String text) => find
            .descendant(of: entry, matching: find.text(text))
            .evaluate()
            .isNotEmpty;
        return switch ((shows(texts.on), shows(texts.off))) {
          (true, false) => 'On',
          (false, true) => 'Off',
          (true, true) => 'On and Off',
          (false, false) => 'neither On nor Off',
        };
      }

      // Starts appNotifications with [service], as the start-up of the app
      // does with the service of the provider, once the app forgot that it
      // asked, and lets the entry show what the service says.
      Future<void> startWith(ScriptedNotifications service) async {
        await inRealTime(
          tester,
          'starting with a service of the test',
          () async {
            await forgetAsking();
            await appNotifications.start(service);
          },
        );
        await tester.pumpAndSettle();
      }

      // Taps the entry, as the user does, and returns the calls that the
      // tap made to [service]. It waits in real time until the tap reached
      // the service, for three seconds at most, and a moment more for the
      // calls after the first one and for the app to save that it asked,
      // then lets the entry show what the service answered.
      Future<List<String>> tap(ScriptedNotifications service) async {
        final before = service.calls.length;
        await inRealTime(tester, 'a tap on the entry', () async {
          await tester.tap(entry);
          for (var turn = 0;
              turn < 300 && service.calls.length == before;
              turn++) {
            await Future<void>.delayed(const Duration(milliseconds: 10));
          }
          await Future<void>.delayed(const Duration(milliseconds: 100));
        });
        await tester.pumpAndSettle();
        return service.calls.sublist(before);
      }

      // A system whose user does not allow the notifications of the app.
      final refuses = ScriptedNotifications(answer: SystemAnswer.refuses);
      await startWith(refuses);
      final notAsked = (appNotifications.permission.value, shown());
      final firstTap = await tap(refuses);
      final afterNo = (appNotifications.permission.value, shown(), askedSaved);
      final secondTap = await tap(refuses);
      // The user turns the notifications on in the settings of the system,
      // and comes back to the app.
      refuses.enabled = true;
      await comeBack(tester);
      await tester.pumpAndSettle();
      final turnedOn = (appNotifications.permission.value, shown());
      final tapWhileOn = await tap(refuses);
      // The user turns them off there, and comes back.
      refuses.enabled = false;
      await comeBack(tester);
      await tester.pumpAndSettle();
      final turnedOff = (appNotifications.permission.value, shown());

      // A system whose user allows them.
      final allows = ScriptedNotifications();
      await startWith(allows);
      final allowingTap = await tap(allows);
      final afterYes = (appNotifications.permission.value, shown());

      expect(
        entry,
        findsOneWidget,
        reason: 'The settings screen shows the entry of the notifications '
            'once.',
      );
      expect(
        notAsked,
        (NotificationPermission.notAsked, 'Off'),
        reason: 'The entry shows Off while the app may not show '
            'notifications and has not asked.',
      );
      expect(
        firstTap,
        ['areEnabled', 'request', 'areEnabled'],
        reason: 'A tap on the entry of an app that has not asked asks the '
            'user, once, and then takes what the user answered from the '
            'service.',
      );
      expect(
        afterNo,
        (NotificationPermission.denied, 'Off', true),
        reason: 'Once the user did not allow it, the entry shows Off, and the '
            'app remembers that it asked.',
      );
      expect(
        secondTap,
        ['openSettings'],
        reason: 'A tap on the entry of an app that asked opens the settings '
            'of the system, where the user turns the notifications on, and '
            'asks nothing: the system may ask no more.',
      );
      expect(
        turnedOn,
        (NotificationPermission.granted, 'On'),
        reason: 'The entry shows On once the user turned the notifications '
            'on in the settings of the system and came back to the app.',
      );
      expect(
        tapWhileOn,
        ['openSettings'],
        reason: 'A tap on the entry of an app that may show notifications '
            'opens the settings of the system, where the user turns them '
            'off, and asks nothing.',
      );
      expect(
        turnedOff,
        (NotificationPermission.denied, 'Off'),
        reason: 'The entry shows Off once the user turned the notifications '
            'off in the settings of the system and came back to the app.',
      );
      expect(
        allowingTap,
        ['areEnabled', 'request', 'areEnabled'],
        reason: 'A tap on the entry of an app that has not asked asks the '
            'user, once, also on a system whose user allows it.',
      );
      expect(
        afterYes,
        (NotificationPermission.granted, 'On'),
        reason: 'The entry shows On once the user allowed the notifications '
            'of the app.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
