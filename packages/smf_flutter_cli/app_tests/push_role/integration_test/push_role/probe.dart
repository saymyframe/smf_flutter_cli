// The probe of the push role, whichever module provides it, which the
// start check runs on a device once the first screen of the app settled,
// the only place where the platform side of the provider is the real one,
// and which the test of the role runs too (provider_test.dart): the app,
// which the start check launched without a tap on a message, has no launch
// message, and once it has an address, the service of the provider gives
// the same one.
//
// It uses no test framework. It only reads: it asks for no permission and
// sends nothing. It does not wait for the address, which a device may get
// late or never, as on a macOS virtual machine, and it never writes the
// address into what it returns, since the address of a device is for the
// backend of the app alone.
import 'package:{{app_name}}/core/push/app_push.dart';

/// The probe of the start check: what is wrong with the push messages of
/// the app as the start-up left them. It waits for no screen, so it leaves
/// [settle] out.
Future<List<String>> probePush(Future<void> Function() settle) async {
  final address = appPush.address.value;
  // A failure of the service reaches the start check, which reports it.
  final answer = address == null ? null : await createPushService().address();
  return [
    if (appPush.launchMessage != null)
      'The app was launched without a tap on a message, but it has a launch '
          'message.',
    if (address != null && answer != address)
      'The address of the app is not the one that the service of the '
          'provider gives.',
  ];
}
