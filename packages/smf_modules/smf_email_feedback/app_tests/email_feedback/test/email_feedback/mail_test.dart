// A test that continuous integration runs in the apps with the
// email_feedback module: what reaches the developer, which is a duty of the
// provider of the feedback role and no guarantee of the role, on the real
// url_launcher, package_info_plus and device_info_plus, whose platform side
// is a device with a mail app (email_feedback_mocks.dart). On Android and on
// iOS, in each language of the app, the service of the module opens one new
// mail outside the app, to the address of .env, without asking the device
// first whether it can. The link has %20 for a space and never +, and a line
// break of a mail. The subject is the word of the module and the name of the
// app, and the body tells the app with its version, its build number and
// its flavor, and the device. A device that fails to tell what it is leaves
// its part out, as does a version that is unknown, and the mail still
// opens. Without an address, or with a value that is none, the service does
// not offer the way to write and opens nothing.
//
// It uses the service of the module, and leaves what every provider of the
// feedback role does to the test of the role. It starts the app once, since
// the start-up of an app may not run twice. Each expectation gives its
// reason.
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/env/app_env.dart';
import 'package:{{app_name}}/core/feedback/email_feedback_mail.dart';
import 'package:{{app_name}}/core/feedback/email_feedback_service.dart';

import '../email_feedback_mocks.dart';
import 'email_feedback.dart';
import 'of_app.dart';

/// The line about the device of the mocks on each platform.
const Map<TargetPlatform, String> _deviceLines = {
  TargetPlatform.android: 'Android 14 (SDK 34), Google Pixel 7',
  TargetPlatform.iOS: 'iOS 17.4, iPhone 15 Pro',
};

/// The name of each platform of the device lines, as the mail tells it
/// when the device fails to tell what it is.
const Map<TargetPlatform, String> _platformNames = {
  TargetPlatform.android: 'Android',
  TargetPlatform.iOS: 'iOS',
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets(
    'the service opens one new mail outside the app to the address of .env, '
    'without asking the device first, with the subject and the body in the '
    'language of the app and %20 for a space, and tells the app and the '
    'device on Android and on iOS',
    (tester) async {
      await startApp(tester);
      final device = mockEmailFeedback();
      final address = AppEnv.emailFeedbackAddress;
      expect(
        isEmailFeedbackAddress(address),
        isTrue,
        reason: 'The test of the module gives the key of the address in .env '
            'an address, so the service has what it needs in the tests of '
            'every app, as the feedback role asks of the mocks of every '
            'provider.',
      );
      final flavor = appFlavor;
      expect(
        flavor,
        allOf(isNotNull, isNot(releaseFlavor)),
        reason: 'flutter test builds the default flavor of the app, which the '
            'mail names.',
      );
      final appLine = '$emailFeedbackAppName 1.0.0 (1), $flavor';

      /// Opens a new mail from a page of the test in the language [code] on
      /// [platform], and returns what the open completed with and the one
      /// mail that reached the mail app.
      Future<(bool?, OpenedMail?)> openOn(
        TargetPlatform platform,
        String code,
      ) async {
        debugDefaultTargetPlatformOverride = platform;
        try {
          await useLanguage(tester, code);
          final context = await contextBelowRoot(tester);
          device.opened.clear();
          final (:answer, :error) = await answerWithin(
            tester,
            createEmailFeedbackService().open(context),
          );
          expect(error, isNull, reason: 'The service never throws.');
          await closeTestPage(tester);
          expect(
            device.questions,
            0,
            reason: 'The service never asks the device first whether it can '
                'open the mail, which Android 11 and later answer no to an '
                'app whose manifest names no other app, though a mail app is '
                'there, on ${platform.name} in $code.',
          );
          expect(
            device.opened,
            hasLength(1),
            reason: 'Each open gives the mail app one new mail, on '
                '${platform.name} in $code.',
          );
          return (answer, device.opened.firstOrNull);
        } finally {
          debugDefaultTargetPlatformOverride = null;
        }
      }

      for (final platform in _deviceLines.keys) {
        for (final code in emailFeedbackTexts.keys) {
          final texts = textsIn(code);
          final (answer, mail) = await openOn(platform, code);
          final where = 'on ${platform.name} in $code';

          expect(
            answer,
            isTrue,
            reason: 'The mail app of the device opened the mail, $where, so '
                'the open completes with true.',
          );
          expect(
            mail!.mode,
            'externalApplication',
            reason: 'The mail opens in the mail app, outside the app, $where.',
          );
          expect(
            mail.link.scheme,
            'mailto',
            reason: 'A new mail opens with a mailto: link, $where.',
          );
          expect(
            Uri.decodeComponent(mail.link.path),
            address!.trim(),
            reason: 'The mail goes to the address of .env, $where.',
          );
          expect(
            mail.raw.contains('+'),
            isFalse,
            reason: 'A mail app shows a + of the link as a plus, so a space '
                'is %20 and a + of the address %2B, as RFC 6068 asks: the '
                'link was ${mail.raw}, $where.',
          );
          expect(
            mail.raw,
            allOf(contains('%20'), contains('%0D%0A')),
            reason: 'The link has a space as %20 and a line break of a mail '
                'as %0D%0A, $where.',
          );
          expect(
            partsOf(mail.raw),
            {
              'subject': '${texts['subject']}: $emailFeedbackAppName',
              'body': '\r\n\r\n${texts['details']}\r\n$appLine\r\n'
                  '${_deviceLines[platform]}',
            },
            reason: 'The subject is the word of the module in the language of '
                'the app and the name of the app, and the body leaves room for '
                'the message, then tells the app with its version, its build '
                'number and its flavor, and the device, $where.',
          );
        }
      }

      // A device that fails to tell what it is leaves the model out, and
      // the mail still opens with the platform alone.
      final first = emailFeedbackTexts.keys.first;
      device.deviceFails = true;
      for (final platform in _deviceLines.keys) {
        final (answer, mail) = await openOn(platform, first);
        expect(
          (answer, partsOf(mail!.raw)['body']!.split('\r\n').last),
          (true, _platformNames[platform]),
          reason: 'A device that fails to tell what it is leaves its part of '
              'the mail out, and the mail tells the platform alone and still '
              'opens, on ${platform.name}.',
        );
      }
      device.deviceFails = false;

      // A version that the platform does not give is left out.
      setVersion('', '');
      try {
        final (answer, mail) = await openOn(TargetPlatform.android, first);
        expect(
          (answer, partsOf(mail!.raw)['body']!.split('\r\n')[3]),
          (true, '$emailFeedbackAppName, $flavor'),
          reason: 'A version and a build number that the platform does not '
              'give are left out of the mail, which still opens.',
        );
      } finally {
        setVersion('1.0.0', '1');
      }

      // Without an address, or with a value that is none, the service does
      // not offer the way to write.
      for (final value in [null, '', 'not-an-address', 'a@b.com,c@d.com']) {
        final service = EmailFeedbackService(address: value);
        final context = await contextBelowRoot(tester);
        device.opened.clear();
        final (:answer, :error) = await answerWithin(
          tester,
          service.open(context),
        );
        await tester.pumpAndSettle();
        expect(
          (
            service.available,
            answer,
            error,
            device.opened.length,
            sheet.evaluate().length,
          ),
          (false, false, null, 0, 0),
          reason: 'With "$value" in .env, the service does not offer the way '
              'to write: it is not available, its open completes with false '
              'and opens no mail and no sheet.',
        );
        await closeTestPage(tester);
      }
    },
    timeout: timeout,
  );
}
