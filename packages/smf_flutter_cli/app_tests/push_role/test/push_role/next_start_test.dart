// A test that continuous integration runs in the apps with the push role,
// whichever module provides it: a service that the function of the
// provider creates again has the address that the device kept, so the next
// start of the app has the same address, as a backend that keeps the
// address of the device expects.
//
// It knows only the role. The start-up of the app runs first, as on a
// device, with the mocks of the platform side of every module of the app,
// which the matrix sets up before the tests of each test file
// (flutter_test_config.dart), and the mocks give the device an address
// that stays the same from one launch to the next, as the role asks of
// them. The next start is initPush() of the role again, which creates the
// service of the provider anew, with what the device kept, and starts
// appPush with it: the address of the app is null until the new service
// gives one. Each expectation gives its reason, which a provider of the
// role with a known bug fails the test with (brokenProviders of the
// fixture registry).
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/push/app_push.dart';

import 'push_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'a service that the function of the provider creates again has the '
    'address that the device kept, so the next start has the same one',
    (tester) async {
      await startUp(tester);
      final first = await addressOfApp(tester);
      final heard = <String?>[];
      void listener() => heard.add(appPush.address.value);
      appPush.address.addListener(listener);
      addTearDown(() => appPush.address.removeListener(listener));

      await inRealTime(tester, 'initPush()', initPush);
      final next = await addressOfApp(tester);
      String? answer;
      await inRealTime(tester, 'asking the service', () async {
        answer = await createPushService().address();
      });

      expect(
        first,
        isNotNull,
        reason: 'The mocks of the platform side of a provider give the '
            'device an address, as the push role says.',
      );
      expect(
        heard.isEmpty ? 'nothing' : heard.first,
        isNull,
        reason: 'The next start has the address of the new service: the '
            'address of the app is null until that service gives one.',
      );
      expect(
        (next, answer),
        (first, first),
        reason: 'A backend keeps the address of a device, so a service that '
            'the function of the provider creates again has the address that '
            'the device kept, and the next start has the same one.',
      );
    },
    timeout: timeout,
  );
}
