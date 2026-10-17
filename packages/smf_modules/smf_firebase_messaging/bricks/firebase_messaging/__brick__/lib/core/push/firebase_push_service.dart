import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_service.dart';

/// Returns the push messages of the app on Firebase Cloud Messaging. It asks
/// the user nothing.
///
/// Firebase is initialized first, as `bootstrap()` does. On iOS it sets the
/// presentation options of a notification that arrives while the app is in
/// the foreground to an alert, a badge and a sound. firebase_messaging
/// answers iOS for every such notification, the local notifications of the
/// app too, with those options: without them, iOS would show none of them.
PushService createFirebasePushService() {
  final service = FirebasePushService(FirebaseMessaging.instance);
  if (service.platformShowsInForeground) {
    unawaited(
      FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
        alert: true,
        badge: true,
        sound: true,
      ),
    );
  }
  return service;
}

/// [message] as a push message of the app: its id, the title and the body
/// of its notification, and its data, with a value that is no string as its
/// JSON.
PushMessage _messageOf(RemoteMessage message) => PushMessage(
      id: message.messageId,
      title: message.notification?.title,
      body: message.notification?.body,
      data: {
        for (final MapEntry(:key, :value) in message.data.entries)
          key: value is String ? value : jsonEncode(value),
      },
    );

/// The push messages of the app on
/// [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging).
///
/// The code of the app does not use it: it receives push messages through
/// `appPush` of `app_push.dart`.
///
/// The address of the device is the registration token of Firebase Cloud
/// Messaging. On iOS it needs the token of the Apple Push Notification
/// service, which may come a while after the app started, or never, as on a
/// build that is not signed for push messages: [address] is `null` until
/// then, and [addressChanges] tells of the token once Firebase has it.
///
/// On Android, the system shows a message that arrives in the background,
/// in the channel and with the icon that the manifest of the app names, and
/// the app shows one that arrives in the foreground. On iOS, the system
/// shows both, with the presentation options of
/// [createFirebasePushService].
final class FirebasePushService implements PushService {
  /// Creates the service on [messaging].
  ///
  /// It reads the stream of the new tokens at once, which sets up the
  /// plugin, so that the messages and the taps that the platform tells of
  /// from then on reach the streams of the service.
  FirebasePushService(this._messaging)
      : addressChanges = _messaging.onTokenRefresh;

  final FirebaseMessaging _messaging;

  @override
  bool get platformShowsInForeground =>
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  final Stream<String> addressChanges;

  @override
  final Stream<PushMessage> messages =
      FirebaseMessaging.onMessage.map(_messageOf);

  @override
  final Stream<PushMessage> taps =
      FirebaseMessaging.onMessageOpenedApp.map(_messageOf);

  @override
  Future<String?> address() async {
    try {
      return await _messaging.getToken();
    } on Object catch (error) {
      // iOS has no token before the one of the Apple Push Notification
      // service comes, and Android none without Google Play services or a
      // network. The token comes on addressChanges once Firebase has it.
      if (kDebugMode) {
        debugPrint('Firebase Cloud Messaging has no address yet: $error');
      }
      return null;
    }
  }

  @override
  Future<PushMessage?> launchMessage() async {
    try {
      final message = await _messaging.getInitialMessage();
      return message == null ? null : _messageOf(message);
    } on Object catch (error) {
      if (kDebugMode) {
        debugPrint('Firebase Cloud Messaging has no launch message: $error');
      }
      return null;
    }
  }
}
