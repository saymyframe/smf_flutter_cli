import 'dart:async';
import 'dart:convert';

import 'package:firebase_core/firebase_core.dart' show FirebaseException;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

import 'push_service.dart';

/// Returns the push messages of the app on Firebase Cloud Messaging. It asks
/// the user nothing.
///
/// Firebase is initialized first, as `bootstrap()` does. On iOS it sets the
/// presentation options of a notification that arrives while the app is in
/// the foreground to an alert, a badge and a sound. firebase_messaging
/// answers iOS with those options for every push message, and for the local
/// notifications of the app too while it is the delegate of the
/// notification center: without them, iOS would show none of them.
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

/// How long the service waits before it asks iOS for the token of the Apple
/// Push Notification service the first time: twice as long each next time,
/// up to [_longestWait], until it has waited [_longestWatch] in all.
const _firstWait = Duration(milliseconds: 500);
const _longestWait = Duration(seconds: 8);
const _longestWatch = Duration(minutes: 2);

/// The push messages of the app on
/// [Firebase Cloud Messaging](https://firebase.google.com/docs/cloud-messaging).
///
/// The code of the app does not use it: it receives push messages through
/// `appPush` of `app_push.dart`.
///
/// The address of the device is the registration token of Firebase Cloud
/// Messaging, to which the HTTP v1 API of Firebase Cloud Messaging sends.
/// firebase_messaging 17 deprecates the calls for that token in favour of
/// the Firebase Installation ID, which the app does not use, so the service
/// ignores the deprecation where it makes them.
///
/// On iOS the registration token needs the token of the Apple Push
/// Notification service, which may come a while after the app started, or
/// never, as on a build that is not signed for push messages: [address] is
/// `null` until then. When that token comes, firebase_messaging tells the
/// app of the registration token only if it changed, which it does not at
/// a later start of the app. So while something listens to
/// [addressChanges], the service asks iOS for the token now and then, which
/// needs no network, for at most two minutes, and tells of the registration
/// token once iOS has the token. [addressChanges] also tells of each new
/// token that Firebase gives the device.
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
  // ignore: deprecated_member_use
  FirebasePushService(this._messaging) : _tokens = _messaging.onTokenRefresh;

  final FirebaseMessaging _messaging;

  /// The new tokens that Firebase tells of.
  final Stream<String> _tokens;

  late final StreamController<String> _addresses =
      StreamController<String>.broadcast(
    onListen: _startListening,
    onCancel: _stopListening,
  );

  StreamSubscription<String>? _tokenSubscription;

  /// Whether the service waits for the token of the Apple Push Notification
  /// service, since [address] failed for want of it.
  bool _awaitingApnsToken = false;

  /// The timer of the next time the service asks iOS for that token.
  Timer? _nextCheck;

  /// How long the service waits before it asks next time, and how long it
  /// has waited for that token so far.
  Duration _wait = _firstWait;
  Duration _waited = Duration.zero;

  @override
  bool get platformShowsInForeground =>
      defaultTargetPlatform == TargetPlatform.iOS;

  @override
  Stream<String> get addressChanges => _addresses.stream;

  @override
  final Stream<PushMessage> messages =
      FirebaseMessaging.onMessage.map(_messageOf);

  @override
  final Stream<PushMessage> taps =
      FirebaseMessaging.onMessageOpenedApp.map(_messageOf);

  @override
  Future<String?> address() async {
    try {
      // ignore: deprecated_member_use
      return await _messaging.getToken();
    } on FirebaseException catch (error) {
      _printWithoutAddress(error);
      // The plugin gives no token on iOS before the device has the token of
      // the Apple Push Notification service.
      if (error.code == 'apns-token-not-set') _awaitApnsToken();
      return null;
    } on Object catch (error) {
      // Android has no token without Google Play services or a network.
      _printWithoutAddress(error);
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

  static void _printWithoutAddress(Object error) {
    if (kDebugMode) {
      debugPrint('Firebase Cloud Messaging has no address yet: $error');
    }
  }

  void _startListening() {
    _tokenSubscription = _tokens.listen(_tellAddress);
    if (_awaitingApnsToken) _scheduleCheck();
  }

  /// No timer of the service outlives the last listener.
  Future<void> _stopListening() async {
    _nextCheck?.cancel();
    _nextCheck = null;
    await _tokenSubscription?.cancel();
    _tokenSubscription = null;
  }

  void _tellAddress(String address) {
    _awaitingApnsToken = false;
    _nextCheck?.cancel();
    _nextCheck = null;
    _addresses.add(address);
  }

  void _awaitApnsToken() {
    if (_awaitingApnsToken) return;
    _awaitingApnsToken = true;
    _wait = _firstWait;
    _waited = Duration.zero;
    if (_addresses.hasListener) _scheduleCheck();
  }

  void _scheduleCheck() {
    if (_nextCheck != null) return;
    if (_waited >= _longestWatch) {
      _awaitingApnsToken = false;
      return;
    }
    final wait = _wait;
    _waited += wait;
    _wait = wait * 2 > _longestWait ? _longestWait : wait * 2;
    _nextCheck = Timer(wait, () => unawaited(_checkApnsToken()));
  }

  /// Asks iOS for the token of the Apple Push Notification service, and
  /// once it has one, Firebase for the registration token, which it tells
  /// of.
  Future<void> _checkApnsToken() async {
    _nextCheck = null;
    String? apnsToken;
    try {
      apnsToken = await _messaging.getAPNSToken();
    } on Object {
      apnsToken = null;
    }
    if (!_awaitingApnsToken || !_addresses.hasListener) return;
    if (apnsToken == null) return _scheduleCheck();
    _awaitingApnsToken = false;
    try {
      // ignore: deprecated_member_use
      final address = await _messaging.getToken();
      if (address != null && _addresses.hasListener) _addresses.add(address);
    } on Object catch (error) {
      _printWithoutAddress(error);
    }
  }
}
