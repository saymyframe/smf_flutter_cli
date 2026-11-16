// A test that continuous integration runs in the apps with the
// firebase_remote_config module, on the real Firebase packages, whose
// platform side is a device and a project in memory
// (firebase_remote_config_mocks.dart): the check of a value of remote config
// that the probe of the module starts in the start check (checkDelivery of
// integration_test/firebase_remote_config/probe.dart). It writes a request
// for a parameter of its own into the temporary directory of the app, which
// .github/scripts/start_app.sh of the repository of SMF answers in CI, and
// then its verdict: `passed` once the value that it asked for became active
// in the app, and `failed: ` and the problem when the parameter became
// active with another value or not in time. Here the test answers, as the
// project publishes the value while the app runs.
//
// The app follows the project only while it has a parameter, which the test
// takes from RemoteValues.defaults of the app. So the tests that answer are
// skipped in an app without parameters, and there the check asks for
// nothing and fails at once, saying why.
//
// It has a file of its own, since the probe starts the check once in a run
// of the app, and the start-up of the app runs once in a test file. The
// check needs the controller of remote config that the start-up starts, so
// the start-up runs first, as on a device, with the mocks of the platform
// side of every module of the app, which the matrix sets up before the
// tests of each test file (flutter_test_config.dart). The temporary
// directory of the app is one of the test.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../integration_test/firebase_remote_config/probe.dart';
import '../firebase_remote_config_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseRemoteConfig device;
  late Directory temporary;

  setUpAll(() => device = mockFirebaseRemoteConfig());
  setUp(
    () => temporary =
        Directory.systemTemp.createTempSync('firebase_remote_config_'),
  );
  tearDown(() => temporary.deleteSync(recursive: true));

  File request() =>
      File('${temporary.path}/smf_start_request_firebase_remote_config');
  File report() =>
      File('${temporary.path}/smf_start_report_firebase_remote_config');

  /// The text of [file] once the check wrote it, in at most 5 seconds.
  Future<String?> written(File file) async {
    final until = DateTime.now().add(const Duration(seconds: 5));
    while (!file.existsSync() && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// Runs [action] in real time, and returns the lines that the check of a
  /// value of remote config printed meanwhile. A widget test ends with
  /// debugPrint as it began.
  Future<List<String>> checking(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    final printed = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message case final line?
          when line.startsWith('The check of a value of remote config')) {
        printed.add(line);
      }
    };
    try {
      await inRealTime(tester, 'checking a value of remote config', action);
    } finally {
      debugPrint = previous;
    }
    return printed;
  }

  /// The check on its own, with short waits, in the temporary directory of
  /// the test.
  Future<String> check() => checkDelivery(
        directory: temporary,
        valueWait: const Duration(milliseconds: 300),
        look: const Duration(milliseconds: 20),
        reminder: const Duration(milliseconds: 100),
      );

  // testWidgets takes no reason for a skip, and a group does.
  group('in an app with parameters', () {
    testWidgets(
      'the probe asks once for a value of remote config, and reports that it '
      'became active in the app once the project published it',
      (tester) async {
        await startUp(tester);
        late List<String> problems;
        String? requested;
        String? verdict;
        var askedAgain = true;

        final printed = await checking(tester, () async {
          problems = await IOOverrides.runZoned(
            () => probeFirebaseRemoteConfig(() async {}),
            getSystemTempDirectory: () => temporary,
          );
          requested = await written(request());
          if (requested == null) return;
          // A value that the check did not ask for changes nothing.
          await device.publish({'other_parameter': 'of the project'});
          final asked = jsonDecode(requested!) as Map<String, Object?>;
          await device.publish({
            asked['parameter']! as String: asked['value']! as String,
          });
          verdict = await written(report());
          request().deleteSync();
          await IOOverrides.runZoned(
            () => probeFirebaseRemoteConfig(() async {}),
            getSystemTempDirectory: () => temporary,
          );
          await Future<void>.delayed(const Duration(milliseconds: 200));
          askedAgain = request().existsSync();
        });

        expect(problems, isEmpty);
        expect(
          requested,
          isNotNull,
          reason: 'The probe starts the check, which asks for a value in an '
              'app with parameters.',
        );
        final asks = jsonDecode(requested!) as Map<String, Object?>;
        expect(
          asks,
          {
            'parameter': matches(RegExp(r'^remote_config_ci_[0-9a-f]{32}$')),
            'value': matches(RegExp(r'^[0-9a-f]{32}$')),
          },
          reason: 'The check asks for a parameter of its own, with a nonce '
              'that tells it apart from any other run of the check, and the '
              'nonce as the value.',
        );
        expect(asks['parameter'], '$parameterPrefix${asks['value']}');
        expect(
          verdict,
          'passed\n',
          reason: 'The value that the project published became active in the '
              'app: Firebase told of it in real time, and the controller of '
              'the remote config role activated it.',
        );
        expect(
          askedAgain,
          isFalse,
          reason: 'The probe starts the check once in a run of the app.',
        );
        expect(
          temporary.listSync().map((file) => file.uri.pathSegments.last),
          ['smf_start_report_firebase_remote_config'],
          reason: 'The check writes each file next to its place and renames '
              'it, so that it is there only whole.',
        );
        expect(printed, [
          startsWith(
            'The check of a value of remote config asked for '
            '${asks['parameter']}, in the state ',
          ),
          'The check of a value of remote config passed',
        ]);
      },
      // A widget test fails after ten minutes by default; a test that hangs
      // fails sooner.
      timeout: const Timeout(Duration(minutes: 2)),
    );

    testWidgets(
      'the check reports a parameter that became active with another value '
      'than it asked for',
      (tester) async {
        await startUp(tester);
        late String verdict;

        await checking(tester, () async {
          final checked = check();
          final asked =
              jsonDecode((await written(request()))!) as Map<String, Object?>;
          await device.publish({asked['parameter']! as String: 'another'});
          verdict = await checked;
        });

        expect(
          verdict,
          matches(
            RegExp(
              r'^failed: the parameter that the check asked for became '
              r'active with the value "another" rather than "[0-9a-f]{32}"$',
            ),
          ),
        );
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  }, skip: withoutParameters);

  testWidgets(
    'the check reports a value that does not become active in time, and in '
    'an app without parameters asks for nothing and fails at once',
    (tester) async {
      await startUp(tester);
      late String verdict;
      String? requested;
      String? reported;

      final printed = await checking(tester, () async {
        verdict = await check();
        requested =
            request().existsSync() ? request().readAsStringSync() : null;
        reported = report().readAsStringSync();
      });

      expect(reported, '$verdict\n');
      if (withoutParameters != null) {
        expect(
          verdict,
          'failed: the app has no parameter of remote config, so it follows '
          'no value that the project publishes, and no value can become '
          'active while it runs',
        );
        expect(
          requested,
          isNull,
          reason: 'An app without parameters asks for no value, which it '
              'would not follow.',
        );
      } else {
        expect(requested, isNotNull);
        expect(
          verdict,
          startsWith(
            'failed: the parameter that the check asked for did not become '
            'active in the app in 300 ms, in the state ',
          ),
        );
        expect(
          verdict,
          endsWith(
            'which needs the Firebase Remote Config Realtime API '
            '(firebaseremoteconfigrealtime.googleapis.com) in the project',
          ),
        );
        expect(
          printed,
          contains(
            startsWith(
              'The check of a value of remote config still waits for it, in '
              'the state ',
            ),
          ),
          reason: 'The log of a start whose value does not come tells the '
              'state of the app while the check waited.',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
