// A test that continuous integration runs in the apps with the remote config
// role, whichever module provides it: appRemoteConfig, the controller that the
// template of the role generates, over a service of remote config of the test
// that scripts what a provider answers. The parameters of the app read their
// defaults until the service activated values, and then those values, each as
// its type takes it, or the default for a text that the type does not take.
// The start waits at most startWait for a service that hangs, and takes the
// values that come later. An app with parameters fetches at the start and
// each time the user comes back to it, and follows the values that the
// backend publishes where the service tells of them; an app without
// parameters asks the backend nothing. And the listeners hear only of a
// change, from the service of the last start alone.
//
// It knows only the role, and reads the parameters of the app from keys.dart,
// which the matrix writes from the data of the role. The start-up of the app
// runs first, as on a device, with the mocks of the platform side of every
// module of the app, which the matrix sets up before the tests of each test
// file (flutter_test_config.dart). Then each test starts appRemoteConfig with
// a service of its own, as the role lets a test do.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/remote_config/app_remote_config.dart';

import 'keys.dart';
import 'remote_config_role.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  // The tests of typed values need a parameter of the app.
  final withoutParameters =
      appParameters.isEmpty ? 'The app has no parameter.' : null;

  testWidgets(
    'the parameters of the app read their defaults until the service '
    'activated values, then those values as their types take them, and the '
    'default for a text that the type does not take',
    (tester) async {
      await startUp(tester);
      final service = ScriptedRemoteConfig(
        kept: {
          for (final parameter in appParameters)
            parameter.name: validTextOf(parameter).$1,
        },
      )..holds['open'] = Completer<void>();
      await startWith(tester, service);
      final beforeActivation = valuesOf(appRemoteConfig.value);
      await inRealTime(tester, 'the service opens', () async {
        service.holds.remove('open')!.complete();
        await aMoment();
      });
      final activated = valuesOf(appRemoteConfig.value);
      service.backend = {
        for (final parameter in appParameters)
          if (invalidTextOf(parameter) case final text?) parameter.name: text,
      };
      await comeBack(tester);
      final invalid = valuesOf(appRemoteConfig.value);

      expect(
        (beforeActivation, valuesOf(RemoteValues.initial)),
        (defaultsOfApp, defaultsOfApp),
        reason: 'Until the service activated values, each parameter of the '
            'app reads its default.',
      );
      expect(
        activated,
        {
          for (final parameter in appParameters)
            parameter.name: validTextOf(parameter).$2,
        },
        reason: 'Each parameter of the app reads the value that the service '
            'activated, as its type takes it: true or false in any case, a '
            'whole number, a finite number or any text.',
      );
      expect(
        invalid,
        defaultsOfApp,
        reason: 'A parameter reads its default when the backend gives it no '
            'value, or a value that its type does not take.',
      );
    },
    skip: withoutParameters,
    timeout: timeout,
  );

  testWidgets(
    'the start waits at most startWait for a service that hangs, and takes '
    'the values that come later',
    (tester) async {
      await startUp(tester);
      final service = ScriptedRemoteConfig(
        kept: {
          for (final parameter in appParameters)
            parameter.name: validTextOf(parameter).$1,
        },
      )..holds['open'] = Completer<void>();
      late Duration took;
      await inRealTime(tester, 'a start that hangs', () async {
        final watch = Stopwatch()..start();
        await appRemoteConfig.start(service);
        took = watch.elapsed;
      });
      final whileHanging = valuesOf(appRemoteConfig.value);
      await inRealTime(tester, 'the service answers', () async {
        service.holds.remove('open')!.complete();
        await aMoment();
      });

      expect(
        took < AppRemoteConfigController.startWait + const Duration(seconds: 1),
        isTrue,
        reason: 'The values never hold the start: it waits at most startWait '
            'for a service that hangs, but it took $took.',
      );
      expect(
        (whileHanging, valuesOf(appRemoteConfig.value)),
        (
          defaultsOfApp,
          {
            for (final parameter in appParameters)
              parameter.name: validTextOf(parameter).$2,
          },
        ),
        reason: 'While the service hangs, the parameters read their defaults, '
            'and the values that come later still become the values of the '
            'app.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'an app with parameters fetches at the start and each time the user '
    'comes back, and follows the values that the backend publishes where the '
    'service tells of them; an app without parameters asks the backend '
    'nothing',
    (tester) async {
      await startUp(tester);
      final live = ScriptedRemoteConfig(liveUpdates: true);
      await startWith(tester, live);
      final atStart = [...live.calls];
      await comeBack(tester);
      final afterComingBack = [...live.calls];
      final followed = live.followed;
      final quiet = ScriptedRemoteConfig();
      await startWith(tester, quiet);
      await comeBack(tester);

      if (appParameters.isEmpty) {
        expect(
          (atStart, afterComingBack, followed, quiet.calls),
          (
            ['open', 'activate'],
            ['open', 'activate'],
            false,
            ['open', 'activate'],
          ),
          reason: 'An app without parameters asks the backend nothing: its '
              'start opens the service and makes active what the device '
              'kept, and it fetches nothing, neither at the start nor when the '
              'user comes back, and listens to no value that the backend '
              'publishes.',
        );
        return;
      }
      expect(
        atStart,
        ['open', 'activate', 'fetch', 'activate'],
        reason: 'An app with parameters makes active what the device kept '
            'when it starts, and then fetches in the background and makes '
            'what it got active.',
      );
      expect(
        afterComingBack,
        [...atStart, 'fetch', 'activate'],
        reason: 'An app with parameters fetches again when the user comes '
            'back to the app.',
      );
      expect(
        (followed, quiet.followed, live.followed),
        (true, false, false),
        reason: 'An app with parameters follows the values that the backend '
            'publishes where the service tells of them, and only those of '
            'the service of the last start.',
      );
      expect(
        quiet.calls,
        ['open', 'activate', 'fetch', 'activate', 'fetch', 'activate'],
        reason: 'A service that tells of no published values is still asked '
            'at the start and when the user comes back.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'a value that the backend publishes while the app runs becomes the value '
    'of the app at once, without a fetch',
    (tester) async {
      await startUp(tester);
      final live = ScriptedRemoteConfig(liveUpdates: true);
      await startWith(tester, live);
      final before = [...live.calls];
      final parameter = appParameters.first;
      final (text, value) = validTextOf(parameter);
      await inRealTime(tester, 'publishing a value', () async {
        live.publish({parameter.name: text});
        await aMoment();
      });

      expect(
        (parameter.read(appRemoteConfig.value), live.calls),
        (value, [...before, 'activate']),
        reason: 'A value that the backend publishes while the app runs, '
            'which the service tells of, becomes active at once.',
      );
    },
    skip: withoutParameters,
    timeout: timeout,
  );

  testWidgets(
    'the listeners hear only of a change of the values, and nothing of a '
    'service that the app no longer has',
    (tester) async {
      await startUp(tester);
      final first = ScriptedRemoteConfig(liveUpdates: true);
      await startWith(tester, first);
      var heard = 0;
      void listener() => heard++;
      appRemoteConfig.addListener(listener);
      addTearDown(() => appRemoteConfig.removeListener(listener));
      final parameter = appParameters.first;
      final (text, _) = validTextOf(parameter);

      await inRealTime(tester, 'publishing a value', () async {
        first.publish({parameter.name: text});
        await aMoment();
      });
      final afterChange = heard;
      await comeBack(tester);
      final afterSameValues = heard;
      final second = ScriptedRemoteConfig();
      await startWith(tester, second);
      final afterNextStart = heard;
      await inRealTime(tester, 'the first service publishes', () async {
        first.publish({parameter.name: '$text again'});
        await aMoment();
      });

      expect(
        (afterChange, afterSameValues),
        (1, 1),
        reason: 'The listeners hear of a change of the values once, and of '
            'nothing when a fetch gives the same values.',
      );
      expect(
        (afterNextStart, heard, parameter.read(appRemoteConfig.value)),
        (2, 2, parameter.defaultValue),
        reason: 'A start with another service takes the defaults back, and '
            'the app takes nothing more of the service that it had before.',
      );
    },
    skip: withoutParameters,
    timeout: timeout,
  );
}
