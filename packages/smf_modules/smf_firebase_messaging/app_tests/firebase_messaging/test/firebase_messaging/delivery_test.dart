// A test that continuous integration runs in the apps with the
// firebase_messaging module, on the real Firebase packages, whose platform
// side is a device in memory (firebase_messaging_mocks.dart): the check of
// a push message that the probe of the module starts in the start check
// (checkDelivery of integration_test/firebase_messaging/probe.dart). Once
// the app has an address, it writes a request for a message to it into the
// temporary directory of the app, which .github/scripts/start_app.sh of the
// repository of SMF answers in CI, and then its verdict: `passed` once the
// message came with what it asked for, and `failed: ` and the problem when
// it came with something else, did not come in time, or when the app got
// no address, which then gets no request. The address is in the request
// alone, never in a verdict or in what the check prints. Here the test
// answers, with the message that the request asks for, as the platform
// tells the app of it.
//
// It has a file of its own, since the probe starts the check once in a run
// of the app, and the start-up of the app runs once in a test file. The
// probe reads appPush, so the start-up of the app runs first, as on a
// device, with the mocks of the platform side of every
// module of the app, which the matrix sets up before the tests of each
// test file (flutter_test_config.dart). The temporary directory of the app
// is one of the test.
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/push/app_push.dart';

import '../../integration_test/firebase_messaging/probe.dart';
import '../firebase_messaging_mocks.dart';
import 'service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late MockFirebaseMessaging device;
  late Directory temporary;

  setUpAll(() => device = mockFirebaseMessaging());
  setUp(
    () =>
        temporary = Directory.systemTemp.createTempSync('firebase_messaging_'),
  );
  tearDown(() => temporary.deleteSync(recursive: true));

  File request() =>
      File('${temporary.path}/smf_start_request_firebase_messaging');
  File report() =>
      File('${temporary.path}/smf_start_report_firebase_messaging');

  /// The text of [file] once the check wrote it, in at most 5 seconds.
  Future<String?> written(File file) async {
    final until = DateTime.now().add(const Duration(seconds: 5));
    while (!file.existsSync() && DateTime.now().isBefore(until)) {
      await Future<void>.delayed(const Duration(milliseconds: 10));
    }
    return file.existsSync() ? file.readAsStringSync() : null;
  }

  /// Runs [action] in real time, and returns the lines that the check of a
  /// push message printed meanwhile. A widget test ends with debugPrint as
  /// it began.
  Future<List<String>> checking(
    WidgetTester tester,
    Future<void> Function() action,
  ) async {
    final printed = <String>[];
    final previous = debugPrint;
    debugPrint = (message, {wrapWidth}) {
      if (message case final line?
          when line.startsWith('The check of a push')) {
        printed.add(line);
      }
    };
    try {
      await inRealTime(tester, 'checking a push message', action);
    } finally {
      debugPrint = previous;
    }
    return printed;
  }

  /// The message that the request of the check asks for, as the platform
  /// tells the app of it, with [title] and [body] in place of those that
  /// it asks for if they are given.
  Map<String, Object?> asked(String text, {String? title, String? body}) {
    final asked = jsonDecode(text) as Map<String, Object?>;
    return messageOfPlatform(
      id: 'asked',
      title: title ?? asked['title']! as String,
      body: body ?? asked['body']! as String,
      data: asked['data']! as Map<String, Object?>,
    );
  }

  testWidgets(
    'the probe asks once for a push message to the address of the app, and '
    'reports that it came with what it asked for; the check reports one that '
    'came with something else, one that did not come in time, and an app '
    'without an address, which asks for nothing; neither with the address',
    (tester) async {
      await startUp(tester);
      late List<String> problems;
      String? requested;
      String? verdict;
      var askedAgain = true;

      final printed = await checking(tester, () async {
        problems = await IOOverrides.runZoned(
          () => probeFirebaseMessaging(() async {}),
          getSystemTempDirectory: () => temporary,
        );
        requested = await written(request());
        if (requested == null) return;
        // A message that the check did not ask for changes nothing.
        await device.deliver(
          messageOfPlatform(id: 'other', title: 'Other', data: {'a': 'b'}),
        );
        await device.deliver(asked(requested!));
        verdict = await written(report());
        request().deleteSync();
        await IOOverrides.runZoned(
          () => probeFirebaseMessaging(() async {}),
          getSystemTempDirectory: () => temporary,
        );
        await Future<void>.delayed(const Duration(milliseconds: 200));
        askedAgain = request().existsSync();
      });

      expect(problems, isEmpty);
      expect(
        requested,
        isNotNull,
        reason: 'The probe starts the check, which asks for a message once '
            'the app has an address.',
      );
      final asks = jsonDecode(requested!) as Map<String, Object?>;
      expect(asks['address'], tokenOfTests);
      expect(asks['title'], messageTitle);
      expect(asks['body'], messageBody);
      expect(
        asks['data'],
        {nonceKey: matches(RegExp(r'^[0-9a-f]{32}$'))},
        reason: 'The message has a nonce of the check, which tells it apart '
            'from any other message.',
      );
      expect(verdict, 'passed\n');
      expect(
        askedAgain,
        isFalse,
        reason: 'The probe starts the check once in a run of the app.',
      );
      expect(
        temporary.listSync().map((file) => file.uri.pathSegments.last),
        ['smf_start_report_firebase_messaging'],
        reason: 'The check writes each file next to its place and renames '
            'it, so that it is there only whole.',
      );
      expect(printed, [
        startsWith('The check of a push message asked for one to the address '
            'of the app, in the state '),
        'The check of a push message passed',
      ]);
      expect(
        [
          for (final line in printed)
            if (line.contains(tokenOfTests)) line
        ],
        isEmpty,
        reason: 'The address of the device is in the request alone.',
      );

      // The check on its own, with short waits, for what it reports when
      // the message is not what it asked for, and when nothing comes.
      late String otherTexts;
      late String tooLate;
      late String withoutAddress;
      String? requestedWithoutAddress;
      String? reported;

      final printedOnFailures = await checking(tester, () async {
        Future<String> check() => checkDelivery(
              directory: temporary,
              addressWait: const Duration(milliseconds: 300),
              messageWait: const Duration(milliseconds: 300),
            );

        final wrongTexts = check();
        await device.deliver(
          asked((await written(request()))!, title: 'Wrong', body: 'Text'),
        );
        otherTexts = await wrongTexts;
        tooLate = await check();
        // The next start, on a device that Firebase gives no token.
        request().deleteSync();
        device.token = null;
        await initPush();
        withoutAddress = await check();
        requestedWithoutAddress =
            request().existsSync() ? request().readAsStringSync() : null;
        reported = report().readAsStringSync();
      });

      expect(
        otherTexts,
        'failed: the push message that the check asked for reached the app '
        'with the title "Wrong" rather than "$messageTitle" and the text '
        '"Text" rather than "$messageBody"',
      );
      expect(
        tooLate,
        startsWith(
          'failed: no push message that the check asked for reached the app '
          'in 300 ms, in the state ',
        ),
      );
      expect(
        withoutAddress,
        'failed: the app got no address of the device in 300 ms, so no push '
        'message can reach it',
      );
      expect(requestedWithoutAddress, isNull);
      expect(reported, '$withoutAddress\n');
      expect(
        [
          for (final text in [
            otherTexts,
            tooLate,
            withoutAddress,
            ...printedOnFailures,
          ])
            if (text.contains(tokenOfTests)) text,
        ],
        isEmpty,
        reason: 'No verdict and no line that the check prints has the address '
            'of the device.',
      );
    },
    // A widget test fails after ten minutes by default; a test that hangs
    // fails sooner.
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
