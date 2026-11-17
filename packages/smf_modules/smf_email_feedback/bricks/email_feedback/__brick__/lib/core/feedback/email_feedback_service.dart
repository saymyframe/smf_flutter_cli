import 'dart:async';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import 'email_feedback_mail.dart';
import 'email_feedback_sheet.dart';
import 'feedback_service.dart';

/// Creates the feedback of the app by email, with the app: a new mail to
/// the address in `{{address_key}}` of `.env`.
FeedbackService createEmailFeedbackService() =>
    EmailFeedbackService(address: {{{env_email_feedback_address}}});

/// How long the mail waits for each read of what it tells about the app and
/// the device. A read that takes longer leaves its part out, and the mail
/// still opens.
const Duration _readTime = Duration(milliseconds: 1500);

/// The feedback of the app by email: "Write to us" opens a new mail to
/// [address] in the mail app of the device, with url_launcher.
///
/// The subject is "Feedback: " and [emailFeedbackAppName], in the language
/// of the app, so a filter of your mail finds it. The body leaves room for
/// the message, then tells the name, the version, the build number and the
/// flavor of the app, and the system and the model of the device, which the
/// user sees and may delete before sending. The flavor for a release, which
/// users install from a store, is not named.
///
/// It never asks the device first whether a mail app is there, as
/// `canLaunchUrl` would: Android 11 and later answer no to an app whose
/// manifest names no other app. Where no mail app opens the mail, such as
/// on the iOS simulator, which has no Mail, it shows a sheet with the
/// address, which the user copies.
final class EmailFeedbackService implements FeedbackService {
  /// Creates the feedback by email to [address], an email address such as
  /// `support@example.com`. With no address, or a value that is none, the
  /// app does not offer the way to write.
  EmailFeedbackService({this.address});

  /// The address that the mail goes to.
  final String? address;

  /// Whether the app printed that the address is missing.
  bool _printed = false;

  @override
  bool get available {
    final has = isEmailFeedbackAddress(address);
    if (!has && kDebugMode && !_printed) {
      _printed = true;
      debugPrint(
        '{{address_key}} in .env is empty or no email address, '
        'so "Write to us" hides: see "{{values_heading}}" in the README.',
      );
    }
    return has;
  }

  @override
  Future<bool> open(BuildContext context) async {
    if (!available) return false;
    final to = address!.trim();
    // The texts of the mail, read from the context before anything waits.
    final String feedback = {{{text_subject}}};
    final String header = {{{text_details}}};
    final lines = await emailFeedbackDetails();
    final link = emailFeedbackLink(
      address: to,
      subject: '$feedback: $emailFeedbackAppName',
      body: emailFeedbackBody(header: header, lines: lines),
    );
    try {
      // false is what iOS answers when no app opened the link.
      if (await launchUrl(link, mode: LaunchMode.externalApplication)) {
        return true;
      }
    } on PlatformException {
      // What Android throws when no app takes the link, or without an
      // activity.
    } on MissingPluginException {
      // A platform without url_launcher.
    }
    if (context.mounted) unawaited(showEmailFeedbackSheet(context, to));
    return false;
  }
}

/// The two lines about the app and the device that the mail tells: the
/// name, the version, the build number and the flavor of the app, and the
/// system and the model of the device. The two are read at once, each for
/// [_readTime] at most: a read that fails or takes longer leaves its part
/// out, and the device line then tells the platform alone.
Future<List<String>> emailFeedbackDetails() async {
  final (app, device) = await (_appLine(), _deviceLine()).wait;
  return [app, device];
}

/// The line about the app, from package_info_plus and the flavor of the
/// build.
Future<String> _appLine() async {
  PackageInfo? info;
  try {
    info = await PackageInfo.fromPlatform().timeout(_readTime);
  } on Object {
    info = null;
  }
  return emailFeedbackAppLine(
    version: info?.version,
    buildNumber: info?.buildNumber,
    flavor: appFlavor,
  );
}

/// The line about the device, from device_info_plus: the version of Android
/// with its SDK, the manufacturer and the model, or the version of iOS and
/// the model, and the platform alone elsewhere.
Future<String> _deviceLine() async {
  final platform = defaultTargetPlatform;
  try {
    switch (platform) {
      case TargetPlatform.android:
        final info = await DeviceInfoPlugin().androidInfo.timeout(_readTime);
        return emailFeedbackDeviceLine(
          system: 'Android',
          systemVersion: info.version.release,
          sdk: info.version.sdkInt,
          manufacturer: info.manufacturer,
          model: info.model,
        );
      case TargetPlatform.iOS:
        final info = await DeviceInfoPlugin().iosInfo.timeout(_readTime);
        // device_info_plus names a model newer than its table this way.
        final model = info.modelName == 'Unknown device'
            ? info.utsname.machine
            : info.modelName;
        return emailFeedbackDeviceLine(
          system: info.systemName,
          systemVersion: info.systemVersion,
          model: model,
        );
      case TargetPlatform.fuchsia:
      case TargetPlatform.linux:
      case TargetPlatform.macOS:
      case TargetPlatform.windows:
        return emailFeedbackDeviceLine(system: _nameOf(platform));
    }
  } on Object {
    return emailFeedbackDeviceLine(system: _nameOf(platform));
  }
}

/// The name of [platform], as the mail tells it.
String _nameOf(TargetPlatform platform) => switch (platform) {
      TargetPlatform.android => 'Android',
      TargetPlatform.iOS => 'iOS',
      TargetPlatform.fuchsia => 'Fuchsia',
      TargetPlatform.linux => 'Linux',
      TargetPlatform.macOS => 'macOS',
      TargetPlatform.windows => 'Windows',
    };
