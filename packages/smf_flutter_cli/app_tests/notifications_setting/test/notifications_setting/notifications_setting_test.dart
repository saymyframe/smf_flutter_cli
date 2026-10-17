// A test that continuous integration runs in the apps with the
// notifications role and the settings screen role, whichever modules
// provide them: the entry of the notifications, which the template of the
// notifications role gives the settings screen. The screen shows it once,
// with its title and whether the app may show notifications, Off or On, as
// the value of its row, in each language of the app. On a first launch a
// tap asks for the permission through the provider, and the entry shows
// On. On a small phone with a large text size, the state is below the
// title, and the texts stay in the row of the entry.
//
// It knows only the two roles, and starts the app once, since the start-up
// of an app may not run twice. The matrix writes setting.dart next to it,
// from the entries of the settings screen role and the languages of the
// localization role of the app: the type of the widget of the entry and
// its texts in each language. It opens the settings screen as the tests of
// the settings screen role do, and runs a call in real time as the test of
// the notifications role does, which every app with both roles has too.
// Each expectation gives its reason.
import 'package:flutter/material.dart';
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
    'the settings screen shows the entry of the notifications, with Off or '
    'On in the language of the app, and a tap on a first launch asks for '
    'the permission',
    (tester) async {
      await openSettings(tester);

      final entry = find.byType(notificationsSetting);
      Finder inEntry(String text) =>
          find.descendant(of: entry, matching: find.text(text));
      // The language that the app is in where the entry is.
      String language() =>
          Localizations.localeOf(tester.element(entry)).languageCode;
      addTearDown(tester.platformDispatcher.clearLocalesTestValue);
      // Has the device ask for each language of the app in turn, and checks
      // that the entry shows its title and the state that [state] reads,
      // which [what] tells, in each; then the device asks for the first
      // language of the app again.
      Future<void> inEachLanguage(
        String Function(SettingTexts texts) state,
        String what,
      ) async {
        for (final MapEntry(key: code, value: texts) in settingTexts.entries) {
          tester.platformDispatcher.localesTestValue = [Locale(code)];
          await tester.pumpAndSettle();
          expect(
            language(),
            code,
            reason: 'The app is in the language that the device asks for, '
                '$code, one of its languages.',
          );
          expect(
            inEntry(texts.title),
            findsOneWidget,
            reason: 'The entry shows its title in the language of the app, '
                '$code.',
          );
          expect(
            inEntry(state(texts)),
            findsOneWidget,
            reason: 'The entry shows $what in the language of the app, $code.',
          );
        }
        tester.platformDispatcher.localesTestValue = [
          Locale(settingTexts.keys.first),
        ];
        await tester.pumpAndSettle();
      }

      expect(
        entry,
        findsOneWidget,
        reason: 'The settings screen shows the entry of the notifications '
            'once.',
      );
      expect(
        appNotifications.permission.value,
        NotificationPermission.notAsked,
        reason: 'The mocks of the platform side of a provider start as on a '
            'first launch, as the notifications role says: the app may not '
            'show notifications and has not asked.',
      );
      await inEachLanguage(
        (texts) => texts.off,
        'Off, since the app may not show notifications,',
      );
      final texts = settingTexts.values.first;
      final title = tester.getRect(inEntry(texts.title));
      final state = tester.getRect(inEntry(texts.off));
      expect(
        state.left >= title.right &&
            state.top < title.bottom &&
            state.bottom > title.top,
        isTrue,
        reason: 'The entry shows whether the app may show notifications as '
            'the value of its row, after its title: $state and $title.',
      );
      final arrow = find.descendant(
        of: entry,
        matching: find.byIcon(Icons.chevron_right),
      );
      expect(
        arrow,
        findsOneWidget,
        reason: 'The row of the entry has an arrow, which tells that a tap '
            'leads on.',
      );
      expect(
        tester.getRect(arrow).left,
        greaterThanOrEqualTo(state.right),
        reason: 'The arrow of the row is after the state.',
      );

      // A tap, as a user who turns the notifications on, which the mocks of
      // the provider grant once the system asked.
      await inRealTime(tester, 'a tap on the entry', () async {
        await tester.tap(entry);
        for (var turn = 0;
            turn < 300 &&
                appNotifications.permission.value !=
                    NotificationPermission.granted;
            turn++) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });
      await tester.pumpAndSettle();
      expect(
        (appNotifications.permission.value, askedSaved),
        (NotificationPermission.granted, true),
        reason: 'A tap on the entry of an app that has not asked asks for '
            'the permission, which the mocks of a provider grant when the '
            'app asks, as the role says, and the app remembers that it '
            'asked.',
      );
      await inEachLanguage(
        (texts) => texts.on,
        'On, since the app may show notifications,',
      );

      // A small phone with the text at three times its size, about the
      // largest that the settings of a device have.
      tester.view.physicalSize = const Size(320, 480);
      tester.platformDispatcher.textScaleFactorTestValue = 3;
      addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      await tester.pumpAndSettle();
      expect(
        tester.takeException(),
        isNull,
        reason: 'The settings screen with the entry of the notifications '
            'fits a small phone with a large text size.',
      );
      // The screen scrolls to the entry, which the large title may have
      // moved out of view: a list builds what is out of view too, but
      // keeps it off the stage.
      await tester.ensureVisible(
        find.byType(notificationsSetting, skipOffstage: false),
      );
      await tester.pumpAndSettle();
      final largeTitle = tester.getRect(inEntry(texts.title));
      final largeState = tester.getRect(inEntry(texts.on));
      expect(
        largeState.top,
        greaterThanOrEqualTo(largeTitle.bottom),
        reason: 'At a large text size, the state is below the title of the '
            'entry, where it has the width of the row.',
      );
      final row = tester.getRect(entry);
      for (final text in [largeTitle, largeState]) {
        expect(
          text.left >= row.left && text.right <= row.right,
          isTrue,
          reason: 'The texts of the entry stay in its row on a small phone '
              'with a large text size: $text of $row.',
        );
      }
      expect(
        arrow,
        findsOneWidget,
        reason: 'The row of the entry keeps its arrow at a large text size.',
      );
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
