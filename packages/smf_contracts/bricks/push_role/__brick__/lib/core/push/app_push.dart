import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../notifications/app_notifications.dart';
import 'push_service.dart';

export 'push_service.dart' show PushMessage;

/// The push messages of the app: the address of the device, the messages
/// that arrive while the app is in the foreground, and the taps of the user
/// on them.
final appPush = AppPushController._();

/// Receives the push messages of the app through the service of the
/// provider of push messages. The app has one, [appPush].
///
/// It shows a message with a title or a body that arrives while the app is
/// in the foreground as a notification of the app, through
/// [appNotifications], where the platform does not show it itself. Such a
/// notification has [appPush] as its owner, so a tap on it reaches [taps]
/// and not [NotificationsController.taps].
///
/// An error of the service on its streams, of a notification that the
/// controller shows, of an address that it asks for, or of the message that
/// launched the app, has no caller, so it reaches the handlers of the
/// uncaught errors of the app, and the controller goes on.
final class AppPushController {
  AppPushController._();

  /// The owner of the notifications that show the messages, under
  /// [notificationOwnerKey] in their data.
  static const _owner = {{{push_owner}}};

  /// The key under which such a notification keeps its message in its data.
  static const _messageKey = {{{message_key}}};

  PushService? _service;
  StreamSubscription<PushMessage>? _serviceMessages;
  StreamSubscription<PushMessage>? _serviceTaps;
  StreamSubscription<String>? _serviceAddresses;
  StreamSubscription<NotificationTap>? _notificationTaps;
  PushMessage? _launchMessage;

  /// The service whose address the controller is asking for, if any.
  PushService? _asking;

  /// Tells when the user comes back to the app.
  _ResumeObserver? _observer;

  final ValueNotifier<String?> _address = ValueNotifier(null);

  final StreamController<PushMessage> _messages =
      StreamController<PushMessage>.broadcast();

  final StreamController<PushMessage> _taps =
      StreamController<PushMessage>.broadcast();

  /// The address of the device, to which the backend of the app sends the
  /// messages for it, or `null` while the platform gives none. Send each new
  /// one to the backend: it may come late, such as on iOS, and it may
  /// change. A widget follows it with a `ValueListenableBuilder`.
  ///
  /// The controller asks for it when it starts, without waiting for it, and
  /// again each time the user comes back to the app while it has none.
  ValueListenable<String?> get address => _address;

  /// The message whose tap launched the app, or `null` if the app was
  /// launched in another way: known once `bootstrap()` is over. The message
  /// is not among the [taps].
  PushMessage? get launchMessage => _launchMessage;

  /// Tells of each message that arrives while the app is in the foreground:
  /// a broadcast stream, the same for the life of the app.
  late final Stream<PushMessage> messages = _messages.stream;

  /// Tells of each tap of the user on a message while the app runs, whether
  /// the platform or the app showed it: a broadcast stream, the same for the
  /// life of the app.
  late final Stream<PushMessage> taps = _taps.stream;

  /// Starts with [service]: follows its messages, its taps and its address,
  /// asks for the address without waiting for it, and takes the message
  /// whose tap launched the app.
  ///
  /// `initPush()` calls it in `bootstrap()`, after the notifications of the
  /// app started, so [launchMessage] is known before the first frame. It may
  /// be called again, with the service that the app has from then on:
  /// `initPush()` does so in a test of the next launch of the app, and a
  /// test gives it a service of its own. The address is then that of the
  /// new service, and `null` until it gives one.
  ///
  /// If the service fails to give the message that launched the app, the
  /// app still starts: the error reaches the handlers of the uncaught errors
  /// of the app, and [launchMessage] is the message of a notification that
  /// the app showed, if its tap launched the app, or `null`.
  Future<void> start(PushService service) async {
    unawaited(_serviceMessages?.cancel());
    unawaited(_serviceTaps?.cancel());
    unawaited(_serviceAddresses?.cancel());
    _service = service;
    _launchMessage = null;
    _address.value = null;
    // An error of these streams has no caller: it reaches the handlers of
    // the uncaught errors of the app, and the streams go on.
    _serviceMessages = service.messages.listen(_onMessage);
    _serviceTaps = service.taps.listen(_taps.add);
    _serviceAddresses = service.addressChanges.listen(_setAddress);
    _notificationTaps ??= appNotifications
        .tapsOf(_owner)
        .listen((tap) => _taps.add(_messageIn(tap.data)));
    if (_observer == null) {
      final observer = _observer = _ResumeObserver(_askForAddress);
      WidgetsBinding.instance.addObserver(observer);
    }
    _askForAddress();
    PushMessage? launched;
    try {
      launched = await service.launchMessage();
    } on Object catch (error, stackTrace) {
      // A provider that fails here would otherwise keep the app from
      // starting.
      Zone.current.handleUncaughtError(error, stackTrace);
    }
    final tap = appNotifications.launchTapOf(_owner);
    _launchMessage = launched ?? (tap == null ? null : _messageIn(tap.data));
  }

  /// Asks the service for the address while the controller has none, unless
  /// it is asking already.
  void _askForAddress() {
    final service = _service!;
    if (_address.value != null || identical(_asking, service)) return;
    _asking = service;
    unawaited(_answer(service));
  }

  Future<void> _answer(PushService service) async {
    try {
      final address = await service.address();
      // An answer of a service that the controller no longer has, or one
      // after the service told of an address, changes nothing.
      if (address != null &&
          identical(service, _service) &&
          _address.value == null) {
        _setAddress(address);
      }
    } finally {
      if (identical(_asking, service)) _asking = null;
    }
  }

  void _setAddress(String address) {
    if (address == _address.value) return;
    _address.value = address;
    if (kDebugMode) {
      debugPrint('The address of this device for push messages: $address');
    }
  }

  /// Tells of [message], and shows it as a notification of the app if the
  /// platform does not show it and it has a title or a body. An empty title
  /// or body counts as none.
  void _onMessage(PushMessage message) {
    _messages.add(message);
    final title = _textOf(message.title);
    final body = _textOf(message.body);
    final text = title ?? body;
    if (text == null || _service!.platformShowsInForeground) return;
    final json = jsonEncode({
      'id': message.id,
      'title': message.title,
      'body': message.body,
      'data': message.data,
    });
    unawaited(
      appNotifications.show(
        AppNotification(
          // An equal message takes the same id, so its notification takes
          // the place of the one that showed it before rather than adding
          // another, and a negative one, so it never takes the place of a
          // notification of the app.
          id: -1 - (json.hashCode & 0x7FFFFFFF),
          // A message with a body alone shows it as its title.
          title: text,
          body: title == null ? null : body,
          data: {
            ...message.data,
            notificationOwnerKey: _owner,
            _messageKey: json,
          },
        ),
      ),
    );
  }

  /// [text], or `null` if it is empty.
  static String? _textOf(String? text) =>
      text == null || text.isEmpty ? null : text;

  /// The message that [data], the data of a notification that showed a
  /// message, keeps under [_messageKey], or a message with the rest of the
  /// data if the notification lost it.
  static PushMessage _messageIn(Map<String, String> data) =>
      switch (_decoded(data[_messageKey])) {
        {
          'id': final String? id,
          'title': final String? title,
          'body': final String? body,
          'data': final Map<String, Object?> values,
        }
            when values.values.every((value) => value is String) =>
          PushMessage(
            id: id,
            title: title,
            body: body,
            data: Map<String, String>.from(values),
          ),
        _ => PushMessage(
            data: {
              for (final MapEntry(:key, :value) in data.entries)
                if (key != notificationOwnerKey && key != _messageKey)
                  key: value,
            },
          ),
      };

  /// What the JSON [text] holds, or `null` for no text or one that is no
  /// JSON.
  static Object? _decoded(String? text) {
    if (text == null) return null;
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}

/// Calls [_onResume] each time the app is resumed, whatever state it was in
/// before.
final class _ResumeObserver with WidgetsBindingObserver {
  _ResumeObserver(this._onResume);

  final VoidCallback _onResume;

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _onResume();
  }
}

/// Returns the service of the provider of push messages, which [initPush]
/// created: `bootstrap()` awaits it before the first frame, and there is
/// none to return before that.
///
/// The code of the app does not call it: it uses [appPush].
PushService createPushService() => _pushService;

{{{smf_push__implementations}}}
