// A test that continuous integration runs in the apps with the
// email_feedback module, on the real package_info_plus and
// device_info_plus, whose platform side is the device of the mocks
// (email_feedback_mocks.dart): the probe of the module, which the start
// check runs on a device, finds no problem there. It finds a version that
// package_info_plus does not give, and a device that device_info_plus fails
// to read, and an app that does not offer the way to write though .env has
// an address, and none of its problems names the address.
//
// It reads the app and the device without starting the app, as the probe
// does on a device once the app has started.
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:{{app_name}}/core/env/app_env.dart';
import 'package:{{app_name}}/core/feedback/app_feedback.dart';
import 'package:{{app_name}}/core/feedback/email_feedback_service.dart';

import '../../integration_test/email_feedback/probe.dart';
import '../email_feedback_mocks.dart';

/// What the probe finds, as on a device.
Future<List<String>> probe() => probeEmailFeedback(() async {});

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late MailDevice device;

  setUp(() => device = mockEmailFeedback());

  tearDown(() => setVersion('1.0.0', '1'));

  test(
      'the probe finds no problem on the device of the mocks, on Android and '
      'on iOS', () async {
    final found = [await probe()];
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      found.add(await probe());
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }

    expect(
      found,
      [isEmpty, isEmpty],
      reason: 'The mail tells the version, the build number, the version of '
          'the system and the model that the platform gives, and the app '
          'offers the way to write with the address of .env.',
    );
  });

  test(
      'the probe finds a version that package_info_plus does not give and a '
      'device that device_info_plus fails to read, and names no address',
      () async {
    setVersion('', '');
    device.deviceFails = true;
    final problems = await probe();

    expect(problems, [
      'package_info_plus gives the version "" and the build number "" of the '
          'app, so the mail cannot tell them.',
      'device_info_plus fails to read the device: PlatformException, so the '
          'mail tells "Android".',
    ]);
    final address = AppEnv.emailFeedbackAddress!;
    expect(
      problems.where((problem) => problem.contains(address)),
      isEmpty,
      reason: 'No problem of the probe names the address of .env.',
    );
  });

  test(
      'the probe finds an app that does not offer the way to write though '
      '.env has an address', () async {
    // The service of the module without an address, as a provider that
    // does not read .env would be.
    appFeedback.use(EmailFeedbackService());
    try {
      expect(
        await probe(),
        [
          'The app does not offer the way to write, though .env has an '
              'address.'
        ],
        reason: 'The probe compares whether the app offers the way to write '
            'with whether .env has an address.',
      );
    } finally {
      appFeedback.use(createFeedbackService());
    }
  });
}
