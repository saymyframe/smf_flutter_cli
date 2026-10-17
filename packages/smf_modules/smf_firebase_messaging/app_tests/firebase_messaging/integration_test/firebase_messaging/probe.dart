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
//
// The probe also starts a check that outlives it and the start check, once
// in a run of the app: whether a push message that a server sends to the
// address of the app reaches it (checkDelivery). A message may take longer
// than the minute that the probes share, and only a server with a key of
// the Firebase project can send one, so the check asks the script of CI
// that started the app, .github/scripts/start_app.sh of the repository of
// SMF, to answer once the start check passed. It writes a request,
// smf_start_request_firebase_messaging, into the temporary directory of
// the app: the address, and the title, the text and the data of the
// message. The script copies the request, runs the command that it was
// given for firebase_messaging, a test of the module that sends the
// message with the key of a service account, and then waits for the
// verdict that the check writes into smf_start_report_firebase_messaging
// there: `passed`, or `failed: ` and the problem. The check writes its
// verdict without a request when the app gets no address. Each file is
// written next to its place and renamed, so that it is there only whole.
// The address is in the request alone: no verdict and no line of the log
// of the check has it. Where nothing answers, as in a start without the
// answer or of a release app, whose files the script cannot read, the
// check writes its verdict once its time is up, and nothing reads it.
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/widgets.dart';
import 'package:{{app_name}}/core/push/app_push.dart';

/// How long the probe waits for the registration token that Firebase has on
/// the device, a local answer: the probes of the start check share a
/// minute.
const Duration tokenTimeout = Duration(seconds: 10);

/// The name of the exchange of the check with start_app.sh, in the names of
/// its files and of the answer that the script is given.
const String exchangeName = 'firebase_messaging';

/// How long the check waits for an address of the device: on an Android
/// emulator it comes in seconds, and on an iOS simulator of a Mac once the
/// device has the token of the Apple Push Notification service.
const Duration addressTimeout = Duration(seconds: 90);

/// How long the check waits for the message once it asked for it: longer
/// than start_app.sh waits for the answer and the verdict, so that the
/// script tells what it waited for when nothing comes.
const Duration messageTimeout = Duration(minutes: 10);

/// The title and the text of the message that the check asks for.
const String messageTitle = 'SMF start check';
const String messageBody = 'A push message that the start check asked for.';

/// The key of the data of the message with the nonce of the check, which
/// tells the message apart from any other.
const String nonceKey = 'smf_start_nonce';

/// The check of a push message that the probe started, if it started one.
Future<String>? _delivery;

/// The probe of the start check: the problems of [problemsOfAddress]. It
/// also starts [checkDelivery] the first time, without waiting for it. It
/// waits for no screen, so it leaves [settle] out.
Future<List<String>> probeFirebaseMessaging(
  Future<void> Function() settle,
) {
  _delivery ??= checkDelivery();
  return problemsOfAddress();
}

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

/// Checks that a push message that a server sends to the address of the
/// app reaches `appPush.messages` with what was sent, with start_app.sh as
/// the server: waits at most [addressWait] for the address, asks for a
/// message with a nonce of its own in a request in [directory], and waits
/// at most [messageWait] for it. Then writes its verdict there, `passed` or
/// `failed: ` and the problem, prints it and returns it.
///
/// The [directory] is the temporary directory of the app unless a test
/// gives another.
Future<String> checkDelivery({
  Directory? directory,
  Duration addressWait = addressTimeout,
  Duration messageWait = messageTimeout,
}) async {
  final files = directory ?? Directory.systemTemp;
  String verdict;
  try {
    final problem = await _problemOfDelivery(files, addressWait, messageWait);
    verdict = problem == null ? 'passed' : 'failed: $problem';
  } on Object catch (error) {
    verdict = 'failed: the check threw ${'$error'.trim().split('\n').first}';
  }
  try {
    _write(files, 'smf_start_report_$exchangeName', verdict);
  } on Object catch (error) {
    debugPrint('The check of a push message wrote no verdict: $error');
  }
  debugPrint('The check of a push message $verdict');
  return verdict;
}

/// What is wrong with the push message that the check asks for in
/// [directory], or `null` if it came with what was asked for.
Future<String?> _problemOfDelivery(
  Directory directory,
  Duration addressWait,
  Duration messageWait,
) async {
  final address = await _addressWithin(addressWait);
  if (address == null) {
    return 'the app got no address of the device in ${_timeOf(addressWait)}, '
        'so no push message can reach it';
  }
  final nonce = _nonce();
  final arrived = Completer<PushMessage>();
  final subscription = appPush.messages.listen((message) {
    if (message.data[nonceKey] == nonce && !arrived.isCompleted) {
      arrived.complete(message);
    }
  });
  try {
    _write(
      directory,
      'smf_start_request_$exchangeName',
      jsonEncode({
        'address': address,
        'title': messageTitle,
        'body': messageBody,
        'data': {nonceKey: nonce},
      }),
    );
    debugPrint(
      'The check of a push message asked for one to the address of the app, '
      'in the state ${WidgetsBinding.instance.lifecycleState} of the app, '
      'and waits for it.',
    );
    final message = await arrived.future.timeout(messageWait);
    final wrong = [
      if (message.title != messageTitle)
        'the title ${_quoted(message.title)} rather than "$messageTitle"',
      if (message.body != messageBody)
        'the text ${_quoted(message.body)} rather than "$messageBody"',
    ];
    return wrong.isEmpty
        ? null
        : 'the push message that the check asked for reached the app with '
            '${wrong.join(' and ')}';
  } on TimeoutException {
    return 'no push message that the check asked for reached the app in '
        '${_timeOf(messageWait)}, in the state '
        '${WidgetsBinding.instance.lifecycleState} of the app';
  } finally {
    await subscription.cancel();
  }
}

/// The address of the app, as soon as it has one within [wait], or `null`.
Future<String?> _addressWithin(Duration wait) async {
  final address = appPush.address;
  if (address.value case final value?) return value;
  final found = Completer<String?>();
  void listener() {
    if (address.value case final value? when !found.isCompleted) {
      found.complete(value);
    }
  }

  address.addListener(listener);
  try {
    return await found.future.timeout(wait, onTimeout: () => null);
  } finally {
    address.removeListener(listener);
  }
}

/// Writes [text] as one line into the file [name] in [directory], next to
/// it first and then renamed, so that the file is there only whole.
void _write(Directory directory, String name, String text) {
  final file = File('${directory.path}/$name');
  File('${file.path}.part')
    ..writeAsStringSync('$text\n', flush: true)
    ..renameSync(file.path);
}

/// A nonce that no other run of the check has: 16 random bytes in hex.
String _nonce() {
  final random = Random.secure();
  return [
    for (var byte = 0; byte < 16; byte++)
      random.nextInt(256).toRadixString(16).padLeft(2, '0'),
  ].join();
}

/// [text] in quotes, or `none`.
String _quoted(String? text) => text == null ? 'none' : '"$text"';

/// [duration] in seconds, or in milliseconds if it is not a whole second.
String _timeOf(Duration duration) => duration.inMilliseconds % 1000 == 0
    ? '${duration.inSeconds} s'
    : '${duration.inMilliseconds} ms';
