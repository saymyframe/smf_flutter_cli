import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_email_feedback/src/email_feedback_module.dart';
import 'package:smf_email_feedback/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the feedback role: which file opens the mail and with what,
/// how a link of a mail is built, why the app asks the device nothing first,
/// and what shows where no mail app opens.
final String agentNote = '''
With `url_launcher`:

- `EmailFeedbackService` in `$serviceFile` implements `FeedbackService` of `${FeedbackRole.serviceFile}`: it opens a new mail to `${EmailFeedbackModule.addressKey.name}` of `${EnvRole.dotEnvFile}` with `launchUrl` and a `mailto:` link from `emailFeedbackLink()` of `$mailFile`, with the version of the app from `PackageInfo.fromPlatform()` and the device from `DeviceInfoPlugin()`.
- Build such a link with `Uri.encodeComponent`, never with `Uri(queryParameters: ...)`, which writes a space as `+`.
- Never call `canLaunchUrl` first: Android 11 and later answer false without `<queries>` in the manifest, which the app does not have.
- Where no mail app opens the mail, `showEmailFeedbackSheet()` of `$sheetFile` shows the address to copy.
''';
