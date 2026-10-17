// A test that continuous integration runs in the apps with the
// firebase_messaging module, on the real Firebase packages, whose platform
// side is a device in memory (firebase_messaging_mocks.dart): the probe of
// the module (integration_test/firebase_messaging/probe.dart), which the
// start check runs on a device, finds nothing while the address of the app
// is the registration token that Firebase has, or while the app has no
// address, as on an iOS device without the token of the Apple Push
// Notification service. It tells when Firebase has another token, or none,
// for an app with an address, or gives none in time, and never writes a
// token into a problem.
//
// The probe reads appPush, so the start-up of the app runs first, as on a
// device, with the mocks of the platform side of every module of the app,
// which the matrix sets up before the tests of each test file
// (flutter_test_config.dart), and on a device of the test. To make the app
// and Firebase disagree, the test gives the device another token without
// telling the app.
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/push/app_push.dart';

import '../../integration_test/firebase_messaging/probe.dart';
import '../firebase_messaging_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseMessaging device;

  setUpAll(() => device = mockFirebaseMessaging());

  testWidgets(
    'the probe finds nothing while the address of the app is the token of '
    'Firebase or the app has none, and tells when Firebase has another token '
    'or none, without the token',
    (tester) async {
      await startUp(tester);
      late List<String> withAddress;
      late List<String> behindTheApp;
      late List<String> failing;
      late List<String> hanging;
      late List<String> withoutAddress;
      late List<String> withoutApnsToken;
      String? addressOfApp;

      await inRealTime(tester, 'probing', () async {
        final until = DateTime.now().add(const Duration(seconds: 5));
        while (
            appPush.address.value == null && DateTime.now().isBefore(until)) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
        addressOfApp = appPush.address.value;
        withAddress = await probeFirebaseMessaging(() async {});
        device.token = 'a token that the app was not told of';
        behindTheApp = await probeFirebaseMessaging(() async {});
        device.failNext(
          'getToken',
          code: 'unknown',
          message: 'java.io.IOException: SERVICE_NOT_AVAILABLE',
        );
        failing = await probeFirebaseMessaging(() async {});
        device.holdNext('getToken');
        hanging = await problemsOfAddress(
          timeout: const Duration(milliseconds: 200),
        );
        // The next start, on a device that Firebase gives no token.
        device.token = null;
        await initPush();
        await aMoment();
        withoutAddress = await probeFirebaseMessaging(() async {});
        // And on iOS without the token of the Apple Push Notification
        // service, as a simulator on a macOS virtual machine. A widget test
        // ends with the platform of the tests.
        onIOS();
        try {
          device
            ..token = tokenOfTests
            ..apnsToken = null;
          await initPush();
          await aMoment();
          withoutApnsToken = await probeFirebaseMessaging(() async {});
        } finally {
          onAndroid();
          // The next start on Android ends the wait of the service of iOS
          // for the token of the Apple Push Notification service, so no
          // timer outlives the test.
          device.apnsToken = 'apns-token-of-the-tests';
          await initPush();
        }
      });

      expect(addressOfApp, tokenOfTests);
      expect(
        [withAddress, withoutAddress, withoutApnsToken],
        everyElement(isEmpty),
        reason: 'The probe finds nothing while the address of the app is the '
            'registration token of Firebase, and nothing for an app without '
            'an address, which a device may get late or never.',
      );
      expect(
        behindTheApp,
        [
          'The address of the app is not the registration token that '
              'Firebase Cloud Messaging has on this device.',
        ],
      );
      expect(
        failing,
        [
          'The app has an address, but Firebase Cloud Messaging gives no '
              'registration token on this device: '
              '[firebase_messaging/unknown] java.io.IOException: '
              'SERVICE_NOT_AVAILABLE',
        ],
      );
      expect(
        hanging,
        [
          'The app has an address, but Firebase Cloud Messaging gave no '
              'registration token on this device within 0:00:00.200000.',
        ],
        reason: 'The probes of the start check share a minute, so the probe '
            'waits for a hanging platform only as long as it says.',
      );
      expect(
        [
          for (final problem in [...behindTheApp, ...failing, ...hanging])
            if (problem.contains(tokenOfTests) ||
                problem.contains('a token that the app was not told of'))
              problem,
        ],
        isEmpty,
        reason: 'The probe never writes the address of the device into a '
            'problem: it is for the backend of the app alone.',
      );
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
