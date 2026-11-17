// The probe of the email_feedback module, which the start check runs on a
// device once the first screen of the app settled, the only place where the
// platform side of package_info_plus and of device_info_plus is the real
// one, also in a release build, whose shrinker may take a class of a plugin
// away; the tests of the module run it over the mocks too (probe_test.dart):
// the mail that the app would open tells the version and the build number
// that package_info_plus gives, and the version of the system and the model
// that device_info_plus gives, and the app offers the way to write exactly
// when .env has an address.
//
// It uses no test framework. It only reads: it opens no mail, which would
// leave the app on a device, and no problem names the address.
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:{{app_name}}/core/env/app_env.dart';
import 'package:{{app_name}}/core/feedback/app_feedback.dart';
import 'package:{{app_name}}/core/feedback/email_feedback_mail.dart';
import 'package:{{app_name}}/core/feedback/email_feedback_service.dart';

/// How long the probe waits for each read of the platform.
const Duration _readTime = Duration(milliseconds: 1500);

/// The probe of the start check: what is wrong with what the mail of the
/// app tells about the app and the device, and with whether the app offers
/// the way to write. It waits for no screen, so it leaves [settle] out.
Future<List<String>> probeEmailFeedback(
  Future<void> Function() settle,
) async {
  final problems = <String>[];
  final details = await emailFeedbackDetails();
  final appLine = details.first;
  final deviceLine = details.last;
  try {
    final info = await PackageInfo.fromPlatform().timeout(_readTime);
    if (info.version.trim().isEmpty || info.buildNumber.trim().isEmpty) {
      problems.add(
        'package_info_plus gives the version "${info.version}" and the build '
        'number "${info.buildNumber}" of the app, so the mail cannot tell '
        'them.',
      );
    } else if (!appLine.contains(' ${info.version} (${info.buildNumber})')) {
      problems.add(
        'The mail tells the app as "$appLine", without the version '
        '${info.version} and the build number ${info.buildNumber} that '
        'package_info_plus gives.',
      );
    }
  } on Object catch (error) {
    problems
        .add('package_info_plus fails to read the app: ${error.runtimeType}.');
  }
  try {
    final (version, model) = switch (defaultTargetPlatform) {
      TargetPlatform.android => await DeviceInfoPlugin()
          .androidInfo
          .timeout(_readTime)
          .then((info) => (info.version.release, info.model)),
      TargetPlatform.iOS =>
        await DeviceInfoPlugin().iosInfo.timeout(_readTime).then(
              (info) => (
                info.systemVersion,
                info.modelName == 'Unknown device'
                    ? info.utsname.machine
                    : info.modelName,
              ),
            ),
      _ => (null, null),
    };
    for (final (what, value) in [
      ('the version of the system', version),
      ('the model', model),
    ]) {
      if (value == null) continue;
      if (value.trim().isEmpty || !deviceLine.contains(value.trim())) {
        problems.add(
          'The mail tells the device as "$deviceLine", without $what that '
          'device_info_plus gives, "$value".',
        );
      }
    }
  } on Object catch (error) {
    problems.add(
      'device_info_plus fails to read the device: ${error.runtimeType}, so '
      'the mail tells "$deviceLine".',
    );
  }
  final hasAddress = isEmailFeedbackAddress(AppEnv.emailFeedbackAddress);
  if (appFeedback.available != hasAddress) {
    problems.add(
      'The app ${appFeedback.available ? 'offers' : 'does not offer'} the way '
      'to write, though .env ${hasAddress ? 'has' : 'has no'} address.',
    );
  }
  return problems;
}
