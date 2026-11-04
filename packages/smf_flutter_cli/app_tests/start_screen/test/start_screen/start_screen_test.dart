// A test that continuous integration runs in the apps whose only role is the
// app entry, whichever module provides it, of what the start check of
// the CLI makes of the first screen of an app: problemsOfFirstScreen() of
// integration_test/start_screen.dart, which the app test start puts into
// every app next to the check. The check runs on a device, where no test
// framework sees it, so this test shows it the screens itself: the screen of
// a failed start, which main() of the app shows when bootstrap() throws, an
// app that started, and an ErrorWidget without an app.
//
// It needs no module and starts no app, so it runs in the apps whose only
// role is the app entry, such as the app of flutter_core alone and the app of
// firebase_core, and the app of several providers of the fixture registry
// does not.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/app/failed_start.dart';

import '../../integration_test/start_screen.dart';

/// What the probes of the test find.
const _ofProbes = ['a probe found a problem'];

/// What the start check makes of the screen that the test shows, with
/// probes that find [_ofProbes]: its problems, how many times it ran the
/// probes, and what it printed to the log of the device.
Future<({List<String> problems, int probesRan, String printed})> _check(
  WidgetTester tester,
) async {
  var probesRan = 0;
  final printed = <String?>[];
  final previous = debugPrint;
  try {
    debugPrint = (message, {wrapWidth}) => printed.add(message);
    final problems = await problemsOfFirstScreen(
      tester.binding.rootElement,
      probes: () async {
        probesRan++;
        return _ofProbes;
      },
    );
    return (
      problems: problems,
      probesRan: probesRan,
      printed: printed.join('\n'),
    );
  } finally {
    debugPrint = previous;
  }
}

void main() {
  // A widget test fails after ten minutes by default; a test that hangs
  // fails sooner.
  const timeout = Timeout(Duration(minutes: 2));

  testWidgets(
    'the screen of a failed start is a problem, with the first line of what '
    'bootstrap() threw, and no probe runs after it',
    (tester) async {
      final error = StateError(
        'the start-up of the test failed\nat its second line',
      );
      final stackTrace = StackTrace.current;
      await tester.pumpWidget(
        FailedStartApp(error: error, stackTrace: stackTrace),
      );

      final (:problems, :probesRan, :printed) = await _check(tester);

      expect(
        problems,
        ['the start-up failed: Bad state: the start-up of the test failed'],
        reason: 'The start check fails on the screen of a failed start, with '
            'the first line of what bootstrap() threw and without its stack '
            'trace.',
      );
      expect(
        probesRan,
        0,
        reason: 'No probe runs after a failed start: the app has none of '
            'what its start-up sets up, so a probe would only fail for what '
            'hides the cause.',
      );
      expect(
        printed,
        allOf(contains('$error'), contains('$stackTrace')),
        reason: 'The start check prints what bootstrap() threw and its stack '
            'trace to the log of the device, where a release app, whose '
            'screen shows neither, keeps them.',
      );
    },
    timeout: timeout,
  );

  testWidgets(
    'the first screen of an app that started is no problem, and the probes '
    'run from it',
    (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Text('The first screen')),
      );

      final (:problems, :probesRan, :printed) = await _check(tester);

      expect(
        problems,
        _ofProbes,
        reason: 'An app that started has no problem on its first screen, '
            'and the problems of the probes follow.',
      );
      expect(probesRan, 1, reason: 'The probes run once, from that screen.');
      expect(printed, isEmpty);
    },
    timeout: timeout,
  );

  testWidgets(
    'a screen without a WidgetsApp, and an ErrorWidget on the screen, are '
    'problems',
    (tester) async {
      await tester.pumpWidget(
        ErrorWidget(StateError('a widget did not build\nat its second line')),
      );

      final (:problems, :probesRan, printed: _) = await _check(tester);

      expect(
        problems,
        [
          'the screen has no WidgetsApp',
          'the screen shows an ErrorWidget: Bad state: a widget did not build',
          ..._ofProbes,
        ],
        reason: 'An app shows its first screen in a WidgetsApp, which '
            'MaterialApp and CupertinoApp build, and without an ErrorWidget.',
      );
      expect(probesRan, 1, reason: 'The probes run once, from that screen.');
    },
    timeout: timeout,
  );
}
