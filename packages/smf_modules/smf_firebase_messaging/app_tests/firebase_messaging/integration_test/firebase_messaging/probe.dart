// The probe of the firebase_messaging module, which the start check runs on
// a device once the first screen of the app settled: the only place where
// the platform side of the plugin is the Firebase SDK. Once the app has an
// address of the device, it is the registration token that Firebase Cloud
// Messaging has on the device, the one to which a server sends.
//
// It returns at once and only reads: it asks for no permission, sends
// nothing and waits for no address, which a device may get late or never,
// as an iOS simulator on a macOS virtual machine never does. An app without
// an address is no problem then. It never writes the address into what it
// returns, since the address of a device is for the backend of the app
// alone. It uses no test framework. The test of the module runs it too
// (probe_test.dart).
import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:{{app_name}}/core/push/app_push.dart';

/// How long the probe waits for the registration token that Firebase has on
/// the device, a local answer: the probes of the start check share a
/// minute.
const Duration tokenTimeout = Duration(seconds: 10);

/// The probe of the start check: the problems of [problemsOfAddress]. It
/// waits for no screen, so it leaves [settle] out.
Future<List<String>> probeFirebaseMessaging(
  Future<void> Function() settle,
) =>
    problemsOfAddress();

/// What is wrong with the address of the app, compared with the
/// registration token that Firebase Cloud Messaging has on this device:
/// nothing while the app has no address, or the token is that address.
/// Firebase gives the token within [timeout], or the probe tells so.
Future<List<String>> problemsOfAddress({
  Duration timeout = tokenTimeout,
}) async {
  final address = appPush.address.value;
  if (address == null) return const [];
  final String? token;
  try {
    token = await FirebaseMessaging.instance.getToken().timeout(timeout);
  } on TimeoutException {
    return [
      'The app has an address, but Firebase Cloud Messaging gave no '
          'registration token on this device within $timeout.',
    ];
  } on Object catch (error) {
    return [
      'The app has an address, but Firebase Cloud Messaging gives no '
          'registration token on this device: $error',
    ];
  }
  return [
    if (token != address)
      'The address of the app is not the registration token that Firebase '
          'Cloud Messaging has on this device.',
  ];
}
