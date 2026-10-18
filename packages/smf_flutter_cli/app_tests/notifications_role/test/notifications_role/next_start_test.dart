// A test that continuous integration runs in the apps with the
// notifications role, whichever module provides it: the next start of the
// app keeps the notifications that the app scheduled, until they are
// cancelled, and the permission that the app had: the one that the user
// gave, and denied once the app asked, which the preferences remember.
//
// It knows only the role. The start-up of the app runs first, as on a
// device, with the mocks of the platform side of every module of the app,
// which the matrix sets up before the tests of each test file
// (flutter_test_config.dart). The next start is initNotifications() of the
// role again, which creates the service of the provider anew, with what
// the device kept, and starts appNotifications with it, and
// initPreferences() of the preferences role again, which opens the
// preferences anew and gives the restorer of the role what they saved.
// The tests of the file run in their order, and only the last asks for the
// permission. Each expectation gives its reason, which a provider of the
// role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/notifications/app_notifications.dart';
import 'package:{{app_name}}/core/preferences/app_preferences.dart';

import 'notifications_role.dart';

/// Starts the notifications again, as the next launch of the app does.
Future<void> _nextStart(WidgetTester tester) =>
    inRealTime(tester, 'initNotifications()', initNotifications);

/// The notifications that are scheduled, as a test compares them.
Future<Map<int, String>> _scheduled(WidgetTester tester) async {
  late Map<int, String> scheduled;
  await inRealTime(tester, 'listing the scheduled notifications', () async {
    scheduled = byId(await appNotifications.scheduled());
  });
  return scheduled;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'a scheduled notification is still scheduled after the next start, '
    'until it is cancelled',
    (tester) async {
      await startUp(tester);
      final ofApp = notificationOfTests(7);
      final owned = notificationOfTests(-7, owner: ownerOfTests);

      await inRealTime(tester, 'scheduling', () async {
        await appNotifications.cancelAll();
        await appNotifications.schedule(ofApp, at: tomorrow);
        await appNotifications.schedule(owned, at: tomorrow);
      });
      await _nextStart(tester);
      final kept = await _scheduled(tester);
      await inRealTime(tester, 'cancelling', () async {
        await appNotifications.cancel(7);
      });
      await _nextStart(tester);
      final afterCancel = await _scheduled(tester);
      await inRealTime(tester, 'cancelling', () async {
        await appNotifications.cancelAll();
      });
      await _nextStart(tester);
      final none = await _scheduled(tester);

      expect(
        kept,
        byId([ofApp, owned]),
        reason: 'The next start keeps the notifications that the app '
            'scheduled.',
      );
      expect(
        afterCancel,
        byId([owned]),
        reason: 'A notification that the app cancelled is not scheduled at '
            'the next start, and the others are.',
      );
      expect(
        none,
        isEmpty,
        reason: 'After cancelAll(), the next start has no notification '
            'scheduled.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the next start has the permission that the app had: denied once the '
    'app asked, and the one that the user gave',
    (tester) async {
      await startUp(tester);
      late NotificationPermission saidAsked;
      late NotificationPermission askedAtNextStart;
      late NotificationPermission forgotten;
      late NotificationPermission allowed;

      await inRealTime(tester, 'the next start after asking', () async {
        // The app asked at an earlier launch, and the user did not allow
        // it, so the app may not show notifications.
        await createAppPreferences().setBool(askedKey, true);
        await initPreferences();
        saidAsked = appNotifications.permission.value;
        await initNotifications();
        askedAtNextStart = appNotifications.permission.value;
        await forgetAsking();
        forgotten = appNotifications.permission.value;
        allowed = await appNotifications.request();
      });
      await _nextStart(tester);
      final allowedAtNextStart = appNotifications.permission.value;
      late bool enabledAtNextStart;
      await inRealTime(tester, 'asking the service', () async {
        enabledAtNextStart = await createNotificationsService().areEnabled();
      });

      expect(
        (saidAsked, askedAtNextStart),
        (NotificationPermission.denied, NotificationPermission.denied),
        reason: 'An app that may not show notifications and asked at an '
            'earlier launch, as the preferences remember under the key of '
            'the role, has the permission denied, also after the next start '
            'of the notifications.',
      );
      expect(
        forgotten,
        NotificationPermission.notAsked,
        reason: 'Once the preferences say that the app did not ask, it has '
            'the permission notAsked.',
      );
      expect(
        (allowed, allowedAtNextStart, enabledAtNextStart),
        (NotificationPermission.granted, NotificationPermission.granted, true),
        reason: 'The next start keeps the permission that the user gave: the '
            'service that it creates says that the app may show '
            'notifications.',
      );
    },
    timeout: timeout,
  );
}
