import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_in_app_review/src/readme.dart';

/// The note of the module in the guide for coding agents of the app, in the
/// section of the review role: which file is on in_app_review and what it
/// calls, why it opens no page through the package, where the app asks,
/// and how a developer sees the dialog on Android.
const String agentNote = '''
With `in_app_review`:

- `InAppReviewService` in `$serviceFile` implements `ReviewService` of `${ReviewRole.serviceFile}`: it asks for the review dialog with `InAppReview.instance.requestReview()`, opens the page of the app in its store with `launchUrl` of url_launcher, and reads the version of the app with `PackageInfo.fromPlatform()` of package_info_plus. In `lib/`, only that file imports in_app_review.
- Keep `openStoreListing()` of in_app_review out of the app: on Android it opens the page of the id of the build that runs, such as that of the flavor `dev`, which has no page in Google Play. `appReview.openStorePage()` opens the right page.
- The app asks for the dialog only where its code calls `appReview.requestIfDue()`. Google Play shows the dialog only in an app that it installed, such as from an internal test track, and the README of the app tells how to see it there. A test review is never sent, since Google Play shows no dialog to an account that has reviewed the app.
''';
