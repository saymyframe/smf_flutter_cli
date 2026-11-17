import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_update_required/src/update_required_module.dart';

/// The heading of the section of the module in the README of the app.
const readmeHeading = 'Update required';

/// The folder of the files of the module in the app.
const folder = 'lib/features/update_required';

/// The path in the app of the file with `updateStatus`.
const statusFile = '$folder/update_status.dart';

/// The path in the app of the file with the comparison of versions.
const compareFile = '$folder/version_compare.dart';

/// The path in the app of the file with the screen.
const screenFile = '$folder/update_required_screen.dart';

/// The name of the parameter of remote config with the lowest version.
final String _parameter = UpdateRequiredModule.minimumVersion.name;

/// The section of the module in the README of the app, next to the sections
/// of the remote config role and of the review role: what takes the place of
/// the app and when, how the versions compare, what "Not now" is for, the
/// App Store ID on iOS, where the texts are, the order against an
/// onboarding, what the stores allow and when to raise the lowest version,
/// and that only the backend of the app can really refuse an old version.
final String readmeSection = '''
While the version of the app is below the lowest version that may run, the screen "Update required" takes the place of the app, and its button "Update" opens the page of the app in its store. The lowest version is `$_parameter`, a parameter of remote config (see the section ${RemoteConfigRole.readmeHeading}), whose default is empty, which is no lowest version. Raise it in the backend of remote config, and the screen shows without a new version of the app: at the next start, or while the app runs once the new value comes. Lower it or empty it, and the user is back where they were.

The version of the app is its version name, such as `1.4.0` of `version: 1.4.0+12` in `pubspec.yaml`, without the build number. The two compare number by number, and a missing number is 0, so `1.2` equals `1.2.0` and `1.10.0` is above `1.9.2`. A lowest version that is not one to four numbers between dots, such as `2.0.0-beta`, keeps the app running, and a debug build prints why. The comparison is in `$compareFile`.

The screen is hard until the user taps "Update". From then on, or at once when no app of the device opened the store page, which the screen says, it also offers "Not now", which lets the user in for this launch. A store page that does not answer within 10 seconds counts as opened. So a lowest version above the version that the store has, set before the review of a release or during a staged rollout, costs a user one trip to the store and never locks anyone out. The next launch, and another lowest version, show the screen again.

The store page is that of the section ${ReviewRole.readmeHeading}: on Android the page of the app in Google Play, and on iOS its page in the App Store, which needs the App Store ID of the app in `${ReviewRole.appStoreIdKey.name}` of `${EnvRole.dotEnvFile}`. Without it, the app has no store page on iOS, and the screen never shows there: a debug build says so. Before the app is in Google Play, "Update" leads to a page that says the item was not found.

The guard `${UpdateRequiredModule.id}.${UpdateRequiredModule.guard}` of `${RouterRole.routeGuards}` shows the screen, `$screenFile`, in place of every other screen, and `updateStatus` of `$statusFile` has what it reads, so nothing navigates to the screen. Its texts are texts of the module. In an app with localization, they are texts of the app, which the screen reads from `context.l10n`: change them where the provider of the localization keeps the texts of the app, in each language. In an app without it, they are the English texts in that file. In an app with an onboarding, the order of the modules of the app decides which of the two comes first on a launch that needs both: the guard of the module that comes first in the app.

The stores have no forced update of their own: Apple has no API for it, and the app only shows this screen. Raise the lowest version only when the old versions really cannot work any more, such as after a change of your backend that they do not understand, and only once the new version is in both stores for every user. Never raise it above the last version that the oldest system that the app supports can install: a user on that system can update to nothing newer. Where the backend of remote config gives a parameter a value for each platform, give each platform its own lowest version when the stores differ.

An app that stays offline never learns a new lowest version, and a user may stay on an old version with "Not now", so only the backend of the app can really refuse an old version, such as by the version that each request names.
''';
