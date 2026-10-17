import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../preferences/app_preferences.dart';
import 'notifications_service.dart';

export 'notifications_service.dart' show AppNotification, NotificationTap;

/// Whether the app may show notifications.
enum NotificationPermission {
  /// The user allowed it.
  granted,

  /// The app asked, and the user did not allow it or turned the
  /// notifications of the app off later. The system may ask no more: iOS
  /// asks once, and Android after a second no. So the app opens its
  /// settings, where the user turns the notifications on:
  /// [NotificationsController.openSettings].
  denied,

  /// The app may not show notifications, and has not asked yet.
  notAsked,
}

/// The key under which a notification with an owner names its owner in its
/// [AppNotification.data], such as a push message that the app shows itself.
///
/// [NotificationsController.taps] and [NotificationsController.launchTap]
/// leave out the taps on such a notification, which
/// [NotificationsController.tapsOf] and
/// [NotificationsController.launchTapOf] give to the owner. A notification
/// with an owner has a negative id, so that it never takes the place of a
/// notification of the app.
const String notificationOwnerKey = {{{owner_key}}};

/// The notifications of the app: the permission to show them, the
/// notifications that the app shows now or at a time to come, and the taps
/// of the user on them.
final appNotifications = NotificationsController._();

/// Shows the notifications of the app through the service of the provider
/// of notifications, keeps the permission to show them up to date, and
/// tells of the taps on them. The app has one, [appNotifications].
///
/// A call made before the app started the service waits for it, and fails
/// with the error of that start if it fails.
///
/// What the service throws reaches the code that called. An error of the
/// service when the user comes back to the app, or one that its taps send,
/// has no caller, so it reaches the handlers of the uncaught errors of the
/// app, and the controller goes on.
final class NotificationsController {
  NotificationsController._();

  /// The key under which the preferences remember that the app asked for
  /// the permission.
  static const _askedKey = {{{asked_key}}};

  /// The smallest and the largest id of a notification: the platforms keep
  /// it in 32 bits.
  static const _smallestId = -0x80000000;
  static const _largestId = 0x7FFFFFFF;

  NotificationsService? _service;
  StreamSubscription<NotificationTap>? _serviceTaps;
  NotificationTap? _launchTap;

  /// Completes when the app has started for the first time, with the error
  /// of that start if it failed. Nothing but a call that waits for the start
  /// reports that error, which the start throws itself.
  final Completer<void> _started = Completer<void>()..future.ignore();

  /// The preferences that remember that the app asked, once the app opened
  /// them.
  AppPreferences? _preferences;

  /// Whether the app asked for the permission.
  bool _asked = false;

  /// Whether the service last said that the app may show notifications.
  bool _enabled = false;

  /// The request for the permission that is on its way, if any.
  Future<NotificationPermission>? _request;

  /// Tells when the user comes back to the app.
  _ResumeObserver? _observer;

  final StreamController<NotificationTap> _taps =
      StreamController<NotificationTap>.broadcast();

  final ValueNotifier<NotificationPermission> _permission =
      ValueNotifier(NotificationPermission.notAsked);

  /// Whether the app may show notifications. It follows what the user
  /// answers, and what the user changed in the settings of the system once
  /// the user comes back to the app. A widget follows it with a
  /// `ValueListenableBuilder`.
  ValueListenable<NotificationPermission> get permission => _permission;

  /// The tap on a notification of the app that launched the app, or `null`
  /// if the app was launched in another way: known once `bootstrap()` is
  /// over. The tap is not among the [taps]. It is `null` for a tap on a
  /// notification of an owner, as [taps] leaves those out.
  NotificationTap? get launchTap => switch (_launchTap) {
        final tap? when _isOfApp(tap) => tap,
        _ => null,
      };

  /// Tells of each tap on a notification of the app while the app runs,
  /// with the data of the notification: a broadcast stream, the same for
  /// the life of the app. It leaves out the taps on the notifications of an
  /// owner, which [tapsOf] gives, and those with a negative id: the
  /// notification of an owner whose data the provider could not read.
  late final Stream<NotificationTap> taps = _taps.stream.where(_isOfApp);

  /// Tells of each tap on a notification whose owner is [owner], as it is
  /// under [notificationOwnerKey] in its data: a broadcast stream.
  Stream<NotificationTap> tapsOf(String owner) =>
      _taps.stream.where((tap) => _ownerOf(tap) == owner);

  /// The tap on a notification whose owner is [owner] that launched the
  /// app, or `null`.
  NotificationTap? launchTapOf(String owner) => switch (_launchTap) {
        final tap? when _ownerOf(tap) == owner => tap,
        _ => null,
      };

  /// Starts with [service]: takes the tap that launched the app, follows
  /// the taps, and asks whether the app may show notifications.
  ///
  /// `initNotifications()` calls it in `bootstrap()`, so [permission] and
  /// [launchTap] are known before the first frame. It may be called again,
  /// with the service that the app has from then on: `initNotifications()`
  /// does so in a test of the next launch of the app, and a test gives it a
  /// service of its own.
  ///
  /// If the service fails to tell whether the app may show notifications,
  /// the future fails with its error, and so do the calls that waited for
  /// the first start. A call after that goes to the service.
  Future<void> start(NotificationsService service) async {
    unawaited(_serviceTaps?.cancel());
    _service = service;
    _launchTap = service.launchTap;
    // An error of the taps has no caller: it reaches the handlers of the
    // uncaught errors of the app, and the taps go on.
    _serviceTaps = service.taps.listen(_taps.add);
    if (_observer == null) {
      final observer = _observer = _ResumeObserver(
        () => unawaited(_refresh()),
      );
      WidgetsBinding.instance.addObserver(observer);
    }
    try {
      await _refresh();
    } on Object catch (error, stackTrace) {
      if (!_started.isCompleted) _started.completeError(error, stackTrace);
      rethrow;
    }
    if (!_started.isCompleted) _started.complete();
  }

  /// Asks the user for the permission to show notifications, unless the app
  /// has it, and completes with the permission once the user answered.
  ///
  /// Ask where the user turns on something that notifies, so that the
  /// question explains itself. Where the platform has no question, the
  /// service opens the settings of the system instead. After
  /// [NotificationPermission.denied] the system may ask no more: iOS asks
  /// once, and Android after a second no. So open its settings then:
  /// [openSettings].
  ///
  /// A request while another is on its way completes with that one. If the
  /// preferences fail to save that the app asked, the future completes with
  /// their error: [permission] is up to date by then, but the next launch
  /// of the app takes it that the app has not asked.
  Future<NotificationPermission> request() =>
      _request ??= _ask().whenComplete(() => _request = null);

  /// Opens the settings of the system for the notifications of the app.
  Future<void> openSettings() async => (await _ready()).openSettings();

  /// Shows [notification] now.
  ///
  /// Its id is a 32-bit integer, 0 or more unless the notification has an
  /// owner under [notificationOwnerKey] in its data, which takes a negative
  /// id. Its future fails with an [ArgumentError] for another id.
  Future<void> show(AppNotification notification) async {
    _check(notification);
    await (await _ready()).show(notification);
  }

  /// Shows [notification] at about [at], not to the minute, also when the
  /// app is closed then. Its future fails with an [ArgumentError] when [at]
  /// is not in the future, and for an id that [show] does not take.
  Future<void> schedule(
    AppNotification notification, {
    required DateTime at,
  }) async {
    _check(notification);
    if (!at.isAfter(DateTime.now())) {
      throw ArgumentError.value(at, 'at', 'The time is not in the future');
    }
    await (await _ready()).schedule(notification, at);
  }

  /// Removes the notification [id], whether it is shown or scheduled.
  Future<void> cancel(int id) async => (await _ready()).cancel(id);

  /// Removes every notification of the app, shown or scheduled, those of an
  /// owner too.
  Future<void> cancelAll() async => (await _ready()).cancelAll();

  /// The notifications that are scheduled and not shown yet, those of an
  /// owner too.
  Future<List<AppNotification>> scheduled() async =>
      (await _ready()).scheduled();

  /// The service, once the app has started for the first time.
  Future<NotificationsService> _ready() async {
    if (!_started.isCompleted) await _started.future;
    return _service!;
  }

  Future<NotificationPermission> _ask() async {
    final service = await _ready();
    if (await service.areEnabled()) {
      _enabled = true;
      _update();
      return _permission.value;
    }
    await service.request();
    _asked = true;
    _enabled = await service.areEnabled();
    _update();
    await _preferences?.setBool(_askedKey, true);
    return _permission.value;
  }

  /// Asks the service whether the app may show notifications.
  Future<void> _refresh() async {
    _enabled = await _service!.areEnabled();
    _update();
  }

  /// Takes that the app asked from [preferences], and keeps it as it is when
  /// they have nothing saved. It keeps [preferences] for the next request.
  void _restore(AppPreferences preferences) {
    _preferences = preferences;
    _asked = preferences.getBool(_askedKey) ?? _asked;
    _update();
  }

  void _update() => _permission.value = _enabled
      ? NotificationPermission.granted
      : _asked
          ? NotificationPermission.denied
          : NotificationPermission.notAsked;

  static String? _ownerOf(NotificationTap tap) =>
      tap.data[notificationOwnerKey];

  /// Whether [tap] is on a notification of the app: one without an owner,
  /// whose id is not negative.
  static bool _isOfApp(NotificationTap tap) =>
      tap.id >= 0 && _ownerOf(tap) == null;

  /// Throws an [ArgumentError] for an id of [notification] that the app
  /// does not take; see [show].
  static void _check(AppNotification notification) {
    final AppNotification(:id, :data) = notification;
    if (id < _smallestId || id > _largestId) {
      throw ArgumentError.value(id, 'id', 'The id is no 32-bit integer');
    }
    final owned = data.containsKey(notificationOwnerKey);
    if (id < 0 && !owned) {
      throw ArgumentError.value(
        id,
        'id',
        'A negative id is for a notification with an owner, which names it '
            'under notificationOwnerKey in its data',
      );
    }
    if (id >= 0 && owned) {
      throw ArgumentError.value(
        id,
        'id',
        'A notification with an owner has a negative id',
      );
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

/// Restores from [preferences] whether the app asked for the permission to
/// show notifications, and keeps them for the next request: a restorer of
/// the preferences, which the app calls before its first frame.
void restoreNotifications(AppPreferences preferences) =>
    appNotifications._restore(preferences);

/// Returns the service of the provider of notifications, which
/// [initNotifications] created: `bootstrap()` awaits it before the first
/// frame, and there is none to return before that.
///
/// The code of the app does not call it: it uses [appNotifications].
NotificationsService createNotificationsService() => _notificationsService;

{{{smf_notifications__implementations}}}
