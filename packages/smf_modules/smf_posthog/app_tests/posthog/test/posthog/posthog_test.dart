// A test that continuous integration runs in the apps with the posthog
// module whose .env has a project token: what only this provider of the
// analytics role does, on the real posthog_flutter, over the mocks of its
// platform side (posthog_mocks.dart), a device that keeps the setting of
// collection as the SDK of PostHog for iOS does.
//
// The start sets PostHog up with the token of .env, its default host, the
// setting of collection that the app starts with, and the private defaults
// of the module, and registers the flavor of the build. Each call of the
// service reaches PostHog as PostHog names it. A property of a user without
// an id waits for the next id. setUserId(null) resets PostHog only while it
// collects: a reset forgets the setting of collection that PostHog keeps, so
// after one, an app that collects nothing before its code chose has PostHog
// keep that collection is on again, and while collection is off the service
// gives PostHog the user once collection is on again. What the code chose
// holds at the next start.
//
// The app may have other analytics services, which only the tests of their
// own modules know, so the test uses the service of the module rather than
// createAnalyticsService(), which forwards to all of them. Each test starts
// PostHog on a new device, as a new install does.
@Timeout(Duration(minutes: 2))
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:posthog_flutter/posthog_flutter.dart';
import 'package:{{app_name}}/core/analytics/analytics_service.dart';
import 'package:{{app_name}}/core/analytics/posthog_analytics_service.dart';
import 'package:{{app_name}}/core/env/app_env.dart';

import '../posthog_mocks.dart';
import 'posthog.dart';

/// Whether the app collects from its first start, which the tests branch on
/// when the app runs.
final bool _collectedFromFirstStart = analyticsCollectedFromFirstStart;

/// The methods with which PostHog keeps again that collection is on after a
/// reset, in an app that collects nothing before its code chose: through
/// off, which records nothing meanwhile.
final List<String> _onAgain =
    _collectedFromFirstStart ? <String>[] : <String>['disable', 'enable'];

/// Starts PostHog on a new device, as a new install of the app does, then
/// turns collection on, or off without [collecting], with the service where
/// the app does not start so, and forgets what reached the device.
Future<AnalyticsService> _start({bool collecting = true}) async {
  mockPostHog();
  final service = await initPostHogAnalytics();
  if (collecting != _collectedFromFirstStart) {
    await service.setAnalyticsCollectionEnabled(collecting);
  }
  postHogDevice.calls.clear();
  postHogDevice.events.clear();
  return service;
}

/// Starts the app again on the device, as its next launch does.
Future<AnalyticsService> _startAgain() {
  postHogDevice.startAgain();
  return initPostHogAnalytics();
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('With a project token', () {
    test(
        'the start sets PostHog up with the token of .env, its default host, '
        'the setting of collection of the app and the private defaults of '
        'the module, and registers the flavor of the build', () async {
      mockPostHog();

      await initPostHogAnalytics();

      expect(postHogStarted, isTrue);
      expect(postHogDevice.methods, ['setup', 'isOptOut', 'register']);
      final config = postHogDevice.config!;
      expect(config.projectToken, AppEnv.posthogProjectToken);
      expect(config.host, 'https://us.i.posthog.com');
      expect(
        config.optOut,
        !_collectedFromFirstStart,
        reason: 'A new install collects as the app says until its code chose.',
      );
      expect(postHogDevice.optedOut, !_collectedFromFirstStart);
      expect(
        (
          config.personProfiles,
          config.sessionReplay,
          config.surveys,
          config.preloadFeatureFlags,
          config.capturePushNotificationSubscriptions,
          config.capturePushNotificationOpened,
        ),
        (
          PostHogPersonProfiles.identifiedOnly,
          false,
          false,
          false,
          false,
          false
        ),
      );
      expect(
        (
          config.captureApplicationLifecycleEvents,
          config.errorTrackingConfig.captureFlutterErrors,
          config.errorTrackingConfig.capturePlatformDispatcherErrors,
          config.errorTrackingConfig.captureNativeExceptions,
          config.debug,
        ),
        (true, false, false, false, false),
        reason: 'PostHog records the lifecycle of the app, and no error, '
            'which the crash reporting of the app reports.',
      );
      expect(postHogDevice.registered, {'app_flavor': '{{default_flavor}}'});
    });

    test(
        'each call of the service reaches PostHog as PostHog names it, and '
        'every event has the flavor of the build', () async {
      final service = await _start();

      await service.logEvent('smf_test', parameters: {'count': 1});
      await service.logSignIn(
        method: 'email',
        parameters: {'screen': 'sign_in'},
      );
      await service.logSignIn();
      await service.logSignUp(method: 'email');
      await service.setUserId('user-1');
      await service.setUserProperty(name: 'plan', value: 'free');
      await service.setUserProperty(name: 'plan', value: null);
      await service.setAnalyticsCollectionEnabled(false);

      expect(postHogDevice.calls, [
        [
          'capture',
          'smf_test',
          {'count': 1},
        ],
        [
          'capture',
          'login',
          {'screen': 'sign_in', 'method': 'email'},
        ],
        ['capture', 'login', <String, Object>{}],
        [
          'capture',
          'sign_up',
          {'method': 'email'},
        ],
        ['identify', 'user-1', null],
        [
          'setPersonProperties',
          {'plan': 'free'},
        ],
        [
          'capture',
          r'$set',
          {
            r'$unset': ['plan'],
          },
        ],
        ['disable'],
      ]);
      expect(
        [
          for (final event in postHogDevice.events)
            (event.event, event.properties['app_flavor']),
        ],
        [
          ('smf_test', '{{default_flavor}}'),
          ('login', '{{default_flavor}}'),
          ('login', '{{default_flavor}}'),
          ('sign_up', '{{default_flavor}}'),
          (r'$identify', '{{default_flavor}}'),
          (r'$set', '{{default_flavor}}'),
          (r'$set', '{{default_flavor}}'),
        ],
      );
      expect(postHogDevice.people['user-1'], isEmpty);
    });

    test(
        'a property of a user without an id waits for the next id, and one '
        'that the code cleared meanwhile does not', () async {
      final service = await _start();

      await service.setUserProperty(name: 'plan', value: 'free');
      await service.setUserProperty(name: 'team', value: 'a');
      await service.setUserProperty(name: 'team', value: null);

      expect(
        postHogDevice.calls,
        isEmpty,
        reason: 'PostHog would make a person profile for a user without an '
            'id.',
      );
      await service.setUserId('user-2');
      expect(postHogDevice.calls, [
        [
          'identify',
          'user-2',
          {'plan': 'free'},
        ],
      ]);
      expect(postHogDevice.people['user-2'], {'plan': 'free'});
    });

    test(
        'setUserId(null) while PostHog collects starts a new anonymous user '
        'with the flavor, and the next start still collects', () async {
      final service = await _start();
      await service.setUserId('user-3');
      postHogDevice.calls.clear();

      await service.setUserId(null);

      expect(
        postHogDevice.methods,
        ['reset', 'register', ..._onAgain],
        reason: 'reset() forgets the registered properties and the setting of '
            'collection, so an app that collects nothing before its code '
            'chose has PostHog keep again that collection is on.',
      );
      expect(postHogDevice.distinctId, isNot('user-3'));
      expect(postHogDevice.registered, {'app_flavor': '{{default_flavor}}'});
      await service.logEvent('after_sign_out');
      expect(
        postHogDevice.events.last.properties['app_flavor'],
        '{{default_flavor}}',
        reason: 'Every event has the flavor of the build, after a reset too.',
      );
      await _startAgain();
      expect(
        postHogDevice.optedOut,
        isFalse,
        reason: 'A collection that the code turned on stays on at the next '
            'start, also after the user signed out.',
      );
    });

    test(
        'while collection is off, setUserId() neither resets PostHog nor '
        'identifies the user, the next start collects nothing, and PostHog '
        'gets the user once collection is on again', () async {
      final service = await _start();
      await service.setUserId('user-4');
      await service.setAnalyticsCollectionEnabled(false);
      postHogDevice.calls.clear();

      await service.setUserId(null);
      expect(
        postHogDevice.calls,
        isEmpty,
        reason: 'A reset would forget that collection is off on the device.',
      );
      await service.setUserId('user-5');
      await service.setUserProperty(name: 'plan', value: 'pro');
      expect(postHogDevice.calls, isEmpty);

      await service.setAnalyticsCollectionEnabled(true);
      expect(postHogDevice.calls, [
        ['enable'],
        [
          'identify',
          'user-5',
          {'plan': 'pro'},
        ],
      ]);

      await service.setAnalyticsCollectionEnabled(false);
      await service.setUserId(null);
      postHogDevice.calls.clear();
      await service.setAnalyticsCollectionEnabled(true);
      expect(
          postHogDevice.methods, ['enable', 'reset', 'register', ..._onAgain]);

      await service.setAnalyticsCollectionEnabled(false);
      await service.setUserId(null);
      await _startAgain();
      expect(
        postHogDevice.optedOut,
        isTrue,
        reason: 'A collection that the code turned off stays off at the next '
            'start, also after the user signed out.',
      );
    });

    test('a sign-out that comes while collection turns off resets nothing',
        () async {
      final service = await _start();
      await service.setUserId('user-6');
      postHogDevice.calls.clear();

      await Future.wait([
        service.setAnalyticsCollectionEnabled(false),
        service.setUserId(null),
      ]);

      expect(postHogDevice.methods, ['disable']);
      expect(postHogDevice.storedOptOut, isTrue);
    });

    test('the next start keeps what the code chose', () async {
      var service = await _start();
      await service.setAnalyticsCollectionEnabled(false);

      service = await _startAgain();
      expect(postHogDevice.optedOut, isTrue);
      await service.logEvent('while_off');
      expect(postHogDevice.events, isEmpty);

      await service.setAnalyticsCollectionEnabled(true);
      service = await _startAgain();
      expect(postHogDevice.optedOut, isFalse);
      await service.logEvent('while_on');
      expect(
        [for (final event in postHogDevice.events) event.event],
        ['while_on'],
      );
    });
  }, skip: hasToken ? false : withoutToken);
}
