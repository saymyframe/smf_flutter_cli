{{#has_router}}import 'package:flutter/foundation.dart' show debugPrint;
{{/has_router}}import 'package:flutter/services.dart' show appFlavor;
import 'package:posthog_flutter/posthog_flutter.dart';

import 'analytics_service.dart';

/// Whether PostHog started in this run of the app: once
/// [initPostHogAnalytics] completed. Until then, and in a build without a
/// project token, the app records nothing in PostHog.
bool get postHogStarted => _started;

bool _started = false;

/// Whether PostHog collects in this run of the app: what it kept on the
/// device from the last call of `setAnalyticsCollectionEnabled()`, or what
/// [analyticsCollectedFromFirstStart] says on a device where the code never
/// chose.
bool _collecting = analyticsCollectedFromFirstStart;

/// The id of the user that the code of the app set last, or `null` for a
/// user without an id.
String? _userId;

/// The user whom PostHog has identified, as far as this run of the app
/// knows: the id that the service identified last, or `null` once it reset
/// PostHog. Only while [_identityKnown] is true.
String? _identifiedId;

/// Whether this run knows whom PostHog has identified: once the service
/// identified a user or reset PostHog. Until then, PostHog may keep a user
/// of an earlier start, and its distinct id does not tell whether that is a
/// user or an anonymous id.
bool _identityKnown = false;

/// Whether the code set or cleared the id of the user while collection was
/// off. PostHog gets nothing then, so it gets that call once collection is on
/// again in this run.
bool _userHeld = false;

/// The properties of the user that PostHog has not got yet, `null` for one
/// that the code cleared: those of a user without an id, which go with the
/// next id, and those that the code set while collection was off.
final Map<String, Object?> _pendingProperties = {};

/// Starts PostHog with the project token and the host of `.env`, and returns
/// an analytics service that records to it. `bootstrap()` awaits it.
///
/// PostHog collects from its first start as [analyticsCollectedFromFirstStart]
/// says, and from then on as the code chose with
/// `setAnalyticsCollectionEnabled()`, which PostHog keeps on the device. It
/// makes a person profile only for a user with an id, and records no session
/// replay, no survey and no push message. Every event has the flavor of the
/// build in its property `app_flavor`.
///
/// Throws a [StateError] when the build has no project token that PostHog
/// takes (see [postHogProjectToken]), or a host that is no http or https
/// address: the app then records nothing in PostHog, and a debug build
/// prints why.
Future<AnalyticsService> initPostHogAnalytics() async {
  final token = postHogProjectToken({{{env_posthog_project_token}}});
  final host = {{{env_posthog_host}}};
  if (host != null && !_isWebAddress(host)) {
    throw StateError(
      'POSTHOG_HOST of this build is no http or https address, so the app '
      'records nothing in PostHog: leave it empty for US Cloud, or give it '
      'the host of your PostHog project, as the section "{{readme_heading}}" '
      'of its README tells.',
    );
  }
  final config = PostHogConfig(token)
    // What the code chose, which PostHog keeps on the device, wins over this.
    ..optOut = !analyticsCollectedFromFirstStart
    ..personProfiles = PostHogPersonProfiles.identifiedOnly
    ..sessionReplay = false
    ..surveys = false
    // No request for feature flags with the id of a user at each start: the
    // app reads none.
    ..preloadFeatureFlags = false
    // Push messages belong to the push role.
    ..capturePushNotificationSubscriptions = false
    ..capturePushNotificationOpened = false;
  if (host != null) config.host = host;
  _started = false;
  _userId = null;
  _identifiedId = null;
  _identityKnown = false;
  _userHeld = false;
  _pendingProperties.clear();
  await Posthog().setup(config);
  _collecting = !await Posthog().isOptOut();
  await _registerFlavor();
  _started = true;
  return const PostHogAnalyticsService();
}

/// The project token with which [initPostHogAnalytics] starts PostHog:
/// [value], the value of `POSTHOG_PROJECT_TOKEN` in this build.
///
/// Throws a [StateError] that tells what to do when the build has no token,
/// or one of spaces alone, with which PostHog would not start, and when it
/// has a personal API key of PostHog (`phx_`), which never goes into an app.
String postHogProjectToken(String? value) {
  if (value == null || value.trim().isEmpty) {
    throw StateError(
      'POSTHOG_PROJECT_TOKEN has no value in this build, so the app records '
      'nothing in PostHog. In .env, give it the project token of your PostHog '
      'project, and build the app as the section "{{values_heading}}" of its '
      'README says. The section "{{readme_heading}}" tells more.',
    );
  }
  if (value.trim().startsWith('phx_')) {
    throw StateError(
      'POSTHOG_PROJECT_TOKEN in .env is a personal API key of PostHog, which '
      'never goes into an app, so the app records nothing in PostHog. Give it '
      'the project token of your PostHog project, which starts with phc_, and '
      'roll the personal API key in PostHog if a build with it left your '
      'machine. The section "{{readme_heading}}" of its README tells more.',
    );
  }
  return value;
}

/// Whether [value] is an http or https address with a host.
bool _isWebAddress(String value) {
  final address = Uri.tryParse(value.trim());
  return address != null &&
      (address.scheme == 'http' || address.scheme == 'https') &&
      address.host.isNotEmpty;
}

/// Gives every event of the app the flavor of the build.
Future<void> _registerFlavor() =>
    Posthog().register('app_flavor', appFlavor ?? '{{default_flavor}}');

/// Records what users do in the app with PostHog.
///
/// A sign-in and a sign-up are the events `login` and `sign_up`, with the
/// method in their property `method`, as Firebase Analytics names them.
///
/// `setUserId(null)` starts a new anonymous user, so the app calls it when
/// the user signs out, not at each start. `setUserId(id)` of another user
/// than the one that PostHog has identified resets PostHog first, since
/// PostHog would ignore it and the events of that user would join the user
/// before. A property of a user without an
/// id waits for the next id, since PostHog would make a person profile for
/// it. PostHog keeps the user on the device from one start to the next, but
/// the service does not know that user, so after each start the app calls
/// `setUserId(id)` for a user who is signed in: until then, a property
/// waits in memory, and it is lost if the app closes. While collection is
/// off, PostHog gets neither a new user nor a property, and gets them once
/// collection is on again.
final class PostHogAnalyticsService implements AnalyticsService {
  /// Creates the service, which records to the PostHog that
  /// [initPostHogAnalytics] started.
  const PostHogAnalyticsService();

  @override
  Future<void> logEvent(String name, {Map<String, Object>? parameters}) =>
      Posthog().capture(eventName: name, properties: parameters);

  @override
  Future<void> logSignIn({String? method, Map<String, Object>? parameters}) =>
      Posthog().capture(
        eventName: 'login',
        properties: {...?parameters, 'method': ?method},
      );

  @override
  Future<void> logSignUp({
    required String method,
    Map<String, Object>? parameters,
  }) =>
      Posthog().capture(
        eventName: 'sign_up',
        properties: {...?parameters, 'method': method},
      );

  /// Turns collection on or off, which PostHog keeps on the device.
  ///
  /// Once it is on again, PostHog gets the user that the code set or
  /// cleared while it was off, and the properties that it set then.
  @override
  Future<void> setAnalyticsCollectionEnabled(bool enabled) async {
    // Before the call, so that a call of this service that comes meanwhile
    // already knows.
    _collecting = enabled;
    if (!enabled) {
      await Posthog().optOut();
      return;
    }
    await Posthog().optIn();
    if (_userHeld) {
      _userHeld = false;
      await _sendUser();
    } else if (_userId != null) {
      await _sendProperties();
    }
  }

  @override
  Future<void> setUserId(String? userId) async {
    if (userId == null || (_userId != null && _userId != userId)) {
      // The properties that wait belong to the user who leaves.
      _pendingProperties.clear();
    }
    _userId = userId;
    if (!_collecting) {
      _userHeld = true;
      return;
    }
    _userHeld = false;
    await _sendUser();
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    if (_userId == null) {
      // PostHog would make a person profile for a user without an id, so
      // the property waits for the next id. One that the code cleared has
      // nothing to wait for.
      if (value == null) {
        _pendingProperties.remove(name);
      } else {
        _pendingProperties[name] = value;
      }
      return;
    }
    if (!_collecting) {
      _pendingProperties[name] = value;
      return;
    }
    if (value == null) {
      await _unset([name]);
    } else {
      await Posthog().setPersonProperties(userPropertiesToSet: {name: value});
    }
  }
}

/// Gives PostHog the user that the code set last: identifies a user with an
/// id, with the properties that wait, and starts a new anonymous user
/// without one.
///
/// The SDKs of PostHog for Android and iOS ignore an identify of an id while
/// they have identified another one, and tell nobody, so that the events of
/// the next user would join the user before. So the service resets PostHog
/// before it identifies an id other than the one that PostHog has: first
/// when this run identified another user, as after a direct change of the
/// user or a sign-out while collection was off, whose reset waited; and once
/// the identify changed nothing, when PostHog kept a user of an earlier
/// start. A reset before every first identify of a run would cut the events
/// of an anonymous user, which PostHog links to the user whom it identifies,
/// from that user.
Future<void> _sendUser() async {
  final userId = _userId;
  if (userId == null) {
    await _reset();
    return;
  }
  if (_identityKnown && _identifiedId != null && _identifiedId != userId) {
    await _reset();
  }
  final (set, cleared) = _takePendingProperties();
  final userProperties = set.isEmpty ? null : set;
  await Posthog().identify(userId: userId, userProperties: userProperties);
  if (!_identityKnown && await Posthog().getDistinctId() != userId) {
    // PostHog kept the user of an earlier start, and ignored the identify.
    await _reset();
    await Posthog().identify(userId: userId, userProperties: userProperties);
  }
  _identifiedId = userId;
  _identityKnown = true;
  if (cleared.isNotEmpty) await _unset(cleared);
}

/// Resets PostHog to a new anonymous user, with the flavor, and in an app
/// that collects nothing before its code chose, the setting of collection
/// kept again.
Future<void> _reset() async {
  // reset() forgets the registered properties, and the setting of collection
  // that PostHog kept on the device.
  await Posthog().reset();
  _identifiedId = null;
  _identityKnown = true;
  await _registerFlavor();
  if (!analyticsCollectedFromFirstStart && _collecting) {
    // The next start of an app that collects nothing before its code chose
    // would collect nothing, though the user agreed: so PostHog keeps that
    // collection is on again, through off, which records nothing meanwhile,
    // since PostHog does nothing for a call that changes nothing.
    await Posthog().optOut();
    if (_collecting) await Posthog().optIn();
  }
}

/// Gives PostHog the properties that the code set or cleared for the user
/// with an id while collection was off.
Future<void> _sendProperties() async {
  final (set, cleared) = _takePendingProperties();
  if (set.isNotEmpty) {
    await Posthog().setPersonProperties(userPropertiesToSet: set);
  }
  if (cleared.isNotEmpty) await _unset(cleared);
}

/// The properties that wait, which it forgets: those that the code set, and
/// the names of those that it cleared.
(Map<String, Object>, List<String>) _takePendingProperties() {
  final set = <String, Object>{};
  final cleared = <String>[];
  for (final MapEntry(:key, :value) in _pendingProperties.entries) {
    if (value == null) {
      cleared.add(key);
    } else {
      set[key] = value;
    }
  }
  _pendingProperties.clear();
  return (set, cleared);
}

/// Clears the properties [names] of the user, with the event `$set` and its
/// `$unset`, which PostHog takes on any event.
Future<void> _unset(List<String> names) =>
    Posthog().capture(eventName: r'$set', properties: {r'$unset': names});{{#has_router}}

/// Records the screen the user sees in PostHog, which the router of the app
/// tells it about, named by the full name of its route, such as
/// `home.home`.
///
/// A screen that is no route of a module is the fallback start screen of the
/// app, recorded as `/`, or the error screen of the router, which is not
/// recorded: the location that the app cannot show may hold anything, such
/// as a token of a link. Nothing is recorded until PostHog started, or in a
/// build without a project token.
///
/// Nothing waits for the screen, so an error of the platform is printed
/// rather than left to the handler of the uncaught errors of the app.
void logPostHogScreen(String? route, String location) {
  if (!_started) return;
  final name = route ?? (Uri.parse(location).path == '/' ? '/' : null);
  if (name == null) return;
  Posthog().screen(screenName: name).catchError(
        (Object error) => debugPrint('PostHog: $error'),
      );
}{{/has_router}}
