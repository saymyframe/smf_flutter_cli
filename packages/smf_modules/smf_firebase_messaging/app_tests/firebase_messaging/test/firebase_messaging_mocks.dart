// The platform side of Firebase Cloud Messaging for the tests that
// continuous integration runs in the apps with the firebase_messaging
// module: a device in memory, in place of the Firebase SDK of a device and
// of the server behind it. It starts as an app finds the device on its
// first launch with Google Play services or a signed build: Firebase has a
// registration token for it, which stays the same for as long as the tests
// of a test file last, as a backend expects of the address of a device,
// and no tap on a message launched the app. It never touches the
// notifications of the app. The matrix sets it up before the tests of
// every module of such an app (MatrixAppTest.mocks), so that any of them
// may run the start-up of the app, which starts the push messages on it.
// The mocks of Firebase Core come with the tests of firebase_core, which
// every app with the module has.
//
// firebase_messaging_platform_interface 4 has no mocks for tests, as those
// of Firebase Core and Crashlytics have, so this answers the messages of
// the plugin to the platform on its method channel, in the standard codec,
// and sends the messages of the platform to the plugin there. A version of
// the package that changes them breaks these tests.
//
// It answers at once, without a timer, so a call completes in a widget
// test too. It keeps to the platforms where the app relies on it: the
// plugin asks iOS for the token of the Apple Push Notification service
// before the registration token, and fails without it; a message whose tap
// launched the app is given once; and the platform tells of a new token,
// of a message in the foreground and of a tap on a message that it showed
// only when a test makes it do so.
//
// It differs from a device in this: it shows nothing, sends nothing to a
// server, and needs no network.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'firebase_core_mocks.dart';

/// The method channel of the plugin, on which the app calls the platform
/// and the platform tells the app of messages, taps and tokens, and under
/// which Firebase Core gives the plugin its constants.
const _channel = MethodChannel('plugins.flutter.io/firebase_messaging');

/// The registration token that the device of the mocks has unless a test
/// gives it another.
const String tokenOfTests = 'firebase-messaging-token-of-the-tests';

/// The platform side of Firebase Cloud Messaging in memory; see
/// [mockFirebaseMessaging].
final class MockFirebaseMessaging {
  MockFirebaseMessaging._();

  /// The registration token of the device, or `null` while Firebase has
  /// none: a test changes it as the platform does, without telling the
  /// app, or with [refreshAddress].
  String? token = tokenOfTests;

  /// The token of the Apple Push Notification service of the device on iOS,
  /// or `null` while iOS gave none, as on a build that is not signed for
  /// push messages: without it the plugin gives no registration token on
  /// iOS.
  String? apnsToken = 'apns-token-of-the-tests';

  /// The calls that reached the platform side, in their order.
  final List<MethodCall> calls = [];

  final Map<String, PlatformException> _failures = {};
  Map<String, Object?>? _launch;

  /// The names of the methods of the calls that reached the platform side,
  /// in their order, without the prefix `Messaging#`.
  List<String> get methods => [
        for (final call in calls) call.method.replaceFirst('Messaging#', ''),
      ];

  /// Answers the next call of [method], such as `getToken`, with an error
  /// with [code] and [message], as the platform sends them: the plugin
  /// turns it into a FirebaseException with that code and message.
  void failNext(
    String method, {
    required String code,
    required String message,
  }) =>
      _failures['Messaging#$method'] = PlatformException(
        code: 'firebase_messaging',
        message: message,
        details: {'code': code, 'message': message},
      );

  /// Has the device give [message], a message as the platform sends it
  /// (see [messageOfPlatform]), as the one whose tap launched the app, once.
  void launchWith(Map<String, Object?> message) => _launch = message;

  /// Tells the app of [message], which arrives while the app is in the
  /// foreground, as the platform does.
  Future<void> deliver(Map<String, Object?> message) =>
      _send('Messaging#onMessage', message);

  /// Tells the app of a tap of the user on [message], which the platform
  /// showed, while the app runs.
  Future<void> open(Map<String, Object?> message) =>
      _send('Messaging#onMessageOpenedApp', message);

  /// Gives the device the registration token [newToken], and tells the app
  /// of it, as the platform does.
  Future<void> refreshAddress(String newToken) {
    token = newToken;
    return _send('Messaging#onTokenRefresh', newToken);
  }

  Future<void> _send(String method, Object? arguments) async {
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    await messenger.handlePlatformMessage(
      _channel.name,
      _channel.codec.encodeMethodCall(MethodCall(method, arguments)),
      (_) {},
    );
  }

  /// Answers the messages of the plugin to the platform.
  void _install() {
    firebasePluginConstants[_channel.name] = {'AUTO_INIT_ENABLED': true};
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, (call) async {
      calls.add(call);
      if (_failures.remove(call.method) case final failure?) throw failure;
      return _answer(call);
    });
  }

  Object? _answer(MethodCall call) {
    switch (call.method) {
      case 'Messaging#getToken':
        return {'token': token};
      case 'Messaging#getAPNSToken':
        return {'token': apnsToken};
      case 'Messaging#getInitialMessage':
        final launch = _launch;
        _launch = null;
        return launch;
      case 'Messaging#setForegroundNotificationPresentationOptions':
        return null;
    }
    throw MissingPluginException('No answer for ${call.method}');
  }
}

/// A message as the platform sends it to the plugin: [id], a notification
/// with [title] and [body] if either is given, and [data], whose values iOS
/// may give as something other than texts.
Map<String, Object?> messageOfPlatform({
  String? id,
  String? title,
  String? body,
  Map<String, Object?> data = const {},
}) =>
    {
      'messageId': id,
      'data': data,
      'notification':
          title == null && body == null ? null : {'title': title, 'body': body},
    };

/// Answers the platform side of Firebase Cloud Messaging with a device in
/// memory that has the registration token [tokenOfTests], and returns it:
/// a test reads there what reached the platform side, and scripts what the
/// platform answers and tells.
///
/// The binding of the tests must be initialized first. A test file that
/// calls it for a device of its own does so before the app starts the push
/// messages, and one for iOS sets debugDefaultTargetPlatformOverride too,
/// with which the plugin asks for the token of the Apple Push Notification
/// service.
MockFirebaseMessaging mockFirebaseMessaging() =>
    MockFirebaseMessaging._().._install();
