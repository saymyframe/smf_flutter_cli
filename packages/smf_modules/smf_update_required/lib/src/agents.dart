import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_update_required/src/readme.dart';
import 'package:smf_update_required/src/update_required_module.dart';

/// The heading of the section of the module in the guide for coding agents
/// of the app.
const agentHeading = 'Update required';

/// The note of the module in the guide for coding agents: what shows the
/// screen "Update required" and when, where its status is, how the versions
/// compare, when "Not now" shows, and what a test of another screen does
/// about it.
///
/// What a router does with a guard of the routes is for the router role to
/// tell, in its own section of the guide, which every app with the module
/// has.
final String agentNote = '''
- While the version of the app is below `${UpdateRequiredModule.minimumVersion.getter}` of `appRemoteConfig.value` (the parameter `${UpdateRequiredModule.minimumVersion.name}` of remote config), the guard `${UpdateRequiredModule.id}.${UpdateRequiredModule.guard}` of `${RouterRole.routeGuards}` shows `UpdateRequiredScreen` of `$screenFile` in place of every other screen. Its route is `${UpdateRequiredModule.id}.${UpdateRequiredModule.route}`, at `/update_required`. So no code navigates to it or away from it.
- `updateStatus` in `$statusFile` has what the guard reads, `supported`, and starts in `bootstrap()`. It reads the version of the app with `PackageInfo.fromPlatform()`, without the build number, and compares it with `versionBelow()` of `$compareFile`: number by number, a missing number is 0, and a version that is not numbers between dots keeps the app running.
- The screen shows only where `appReview.hasStorePage` holds, so on iOS only with the App Store ID in `.env`. Its button calls `updateStatus.openStore()`, which opens the store page through `appReview.openStorePage()` and waits for it at most 10 seconds. Once the store has opened, failed to open or not answered, the screen also shows "Not now", `updateStatus.continueForNow()`, which lets the user in for this launch although the version is below the lowest one.
- A test of another screen needs nothing: the default of the parameter is empty, so the app runs. A test of the screen gives `appRemoteConfig.start()` and `appReview.start()` services of its own, and `updateStatus.start(review: ...)` an `AppReviewController` of its own, such as one with an App Store ID that it scripts. It runs `updateStatus.start()` again for the next launch.
''';
