import 'package:smf_contracts/smf_contracts.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'in_app_review';

/// The path in the app of the file with the service of the module.
const serviceFile = 'lib/core/review/in_app_review_service.dart';

/// The page of Google that tells how to see the review dialog of Google
/// Play before the app is published.
const testPage =
    'https://developer.android.com/guide/playcore/in-app-review/test';

/// The page of Google on the In-App Review API of Google Play, whose section
/// "Data Safety" tells what Google Play collects through the dialog.
const reviewPage = 'https://developer.android.com/guide/playcore/in-app-review';

/// The section of the module in the README of the app, next to the section
/// of the review role: what shows the dialog and what opens the page, that
/// the app asks only where its code asks, how to see the dialog on Android,
/// what Google Play collects through it, and the privacy policy that both
/// stores require.
const String readmeSection = '''
The app asks for the review dialog of its store with [in_app_review](https://pub.dev/packages/in_app_review): `$serviceFile` implements the reviews of the app on it, as the section "${ReviewRole.readmeHeading}" tells. On iOS the dialog is that of StoreKit, and on Android that of the In-App Review API of Google Play. The page of the app in its store opens with [url_launcher](https://pub.dev/packages/url_launcher), and the version of the app, in which the app asks at most once, comes from [package_info_plus](https://pub.dev/packages/package_info_plus).

The app asks only where its code calls `appReview.requestIfDue()`, and nothing asks on its own.

Google Play shows the dialog only in an app that it installed. To see it before the app is published ([Test in-app reviews]($testPage)):

1. Upload a build of the flavor `prod` to the internal test track in Play Console.
2. Add a Gmail account to the testers of that track. It is the primary account of the Play Store on the device: an account of Google Workspace does not work.
3. Install the app once from the internal test track with that account. From then on, local builds of the flavor `prod` may show the dialog on that device: uninstall the copy from Google Play first, since a local build has another signature. Google Play does not limit how often it shows the dialog to an app from the internal test track.
4. Never send the review of a test, or delete it in the Play Store: Google Play shows no dialog to an account that has reviewed the app.

An app from internal app sharing shows the dialog too, but its review cannot be sent. Anywhere else, such as on an emulator without the Play Store, the request fails, the app records nothing, and the next call of `appReview.requestIfDue()` asks again.

Through the dialog, Google Play collects the rating and the text of the review, which become a public review on Google Play, or which only you see for an app on a closed test track: see the section "Data Safety" of [the In-App Review API]($reviewPage). The privacy manifest of in_app_review on iOS declares no data that it collects.

Both stores require a link to a privacy policy in the listing of the app and inside the app.
''';
