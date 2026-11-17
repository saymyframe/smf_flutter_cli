import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_email_feedback/src/email_feedback_module.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Feedback by email';

/// The name of the file with the service of the module.
const serviceFileName = 'email_feedback_service.dart';

/// The path in the app of the file with the service of the module.
const serviceFile = 'lib/core/feedback/$serviceFileName';

/// The path in the app of the file with the link and the lines of the mail,
/// which needs only Dart.
const mailFile = 'lib/core/feedback/email_feedback_mail.dart';

/// The path in the app of the file with the sheet that shows the address
/// where no mail app opens.
const sheetFile = 'lib/core/feedback/email_feedback_sheet.dart';

/// The name of the key of the address in `.env`.
final String _key = EmailFeedbackModule.addressKey.name;

/// The file of the values of the app.
const String _env = EnvRole.dotEnvFile;

/// The section of the module in the README of the app, next to the section
/// of the feedback role and of the values in `.env`: where the mail goes and
/// that the address is public, what the mail holds, what the app needs of
/// the platform, what shows where no mail app opens, where its texts are,
/// how to see it, and what leaves the device.
final String readmeSection = '''
`appFeedback.open(context)` opens a new mail to you in the mail app of the device, with [url_launcher](https://pub.dev/packages/url_launcher): `$serviceFile` implements the feedback of the app on it, as the section "${FeedbackRole.readmeHeading}" tells. The mail goes to the address in `$_key` of `$_env`, such as `$_key=support@example.com`, and the section "${EnvRole.readmeHeading}" leads to how the values of `$_env` get into the app. Until it has an address, the app does not offer the way to write, and a debug build prints which key to fill in. In an app with a settings screen, its row "Write to us" hides then. In an app without one, `appFeedback.available` is false, so hide your own button. The address goes into the app, where anyone can read it, so use an address for support with a filter of spam rather than your own.

The subject of the mail is "Feedback: " in the language of the app and `emailFeedbackAppName`, the name of the app in `$mailFile`, the same in every flavor, so a filter of your mail finds it. The body leaves room for the message, then tells the name, the version and the build number of the app from [package_info_plus](https://pub.dev/packages/package_info_plus), the flavor of the build, which the flavor for a release leaves out, and the system and the model of the device from [device_info_plus](https://pub.dev/packages/device_info_plus). The user sees all of it and may change it before sending. `emailFeedbackLink()` in that file encodes each part as RFC 6068 asks, so a space is `%20` and never `+`.

The app asks the device nothing before it opens the mail, so it needs no `<queries>` in the manifest of Android and no `LSApplicationQueriesSchemes` in `Info.plist`. Where no mail app opens the mail, such as on the iOS simulator, which has no Mail, or on an Android emulator without a mail app, a sheet shows the address with a button that copies it (`$sheetFile`).

The texts of the mail and of the sheet are texts of the module. In an app with localization, they are texts of the app, which `$serviceFile` and `$sheetFile` read from `context.l10n`: change them where the provider of the localization keeps the texts of the app, in each language. In an app without it, they are the English texts in those two files.

To see the mail, run the app on an iPhone, or on an Android device or emulator with a mail app and an account in it, such as Gmail. In an app with a settings screen, tap "Write to us" there. In an app without one, tap your own button that calls `appFeedback.open(context)`.

What the mail tells about the app and the device is read on the device, and leaves it only in a mail that the user sends from their own mail app: the app itself sends nothing.
''';
