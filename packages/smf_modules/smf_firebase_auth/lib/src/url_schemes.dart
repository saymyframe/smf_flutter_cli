import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/bundles/google_url_schemes_bundle.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';

/// The path in the app of the script that writes the URL scheme of Google
/// of each iOS app that `firebase.json` names, `REVERSED_CLIENT_ID` of its
/// `GoogleService-Info.plist`, into `CFBundleURLTypes` of
/// [AppEntryRole.infoPlistFile], which all the flavors share.
///
/// The Google Sign-In SDK stops an iOS app whose Info.plist lacks the
/// scheme of its client, which google_sign_in does not catch. A Firebase
/// file has the client of the iOS app once Google is enabled in the project,
/// and flutterfire writes the file again in each of its runs. So the script
/// is in [FirebaseCoreModule.configuredHooksDirectory]:
/// [FirebaseCoreModule.configureScript] runs it after every run of
/// flutterfire, for each flavor, also one that is configured long after the
/// app was generated. The script that enables the sign-in methods runs it
/// too, once it downloaded the Firebase files with the clients.
///
/// It reads every iOS file of `firebase.json`, of every project, and adds
/// the scheme of each file that has a client, as a URL type of its own. A
/// scheme is there as the Google Sign-In SDK reads it: among the
/// `CFBundleURLSchemes` of `CFBundleURLTypes`, in any case, and not under
/// another key or in a comment. It removes none, leaves an Info.plist that
/// has them all as it is, and stops at one in a form that it does not know,
/// with what to add there by hand. A file without a client, as in a project
/// in which Google is not enabled, gets a line that names its project and
/// the command that enables Google there, with `--project` when
/// `firebase.json` names several projects, and no failure: configuring
/// Firebase is not a failure.
const urlSchemesHook =
    '${FirebaseCoreModule.configuredHooksDirectory}/$urlSchemesHookName';

/// The name of the file of [urlSchemesHook].
const urlSchemesHookName = 'write_google_url_schemes.dart';

/// The command of [urlSchemesHook] as the user types it in the directory of
/// the app.
const urlSchemesCommand = 'dart $urlSchemesHook';

/// The text of [urlSchemesHook]: the one file of the brick
/// `google_url_schemes` of the package, which no contribution renders.
///
/// A brick has the same files in every app, and this script belongs only in
/// an app whose ways to sign in need the client of the iOS app
/// ([needsIosClient]): [FirebaseCoreModule.configureScript] runs every Dart
/// file of its directory. So the render hook of the provider of the module
/// writes the file into such an app ([RoleOutput.files]), which renders no
/// mustache, and the file of the brick has none. It stays a Dart file in a
/// brick, rather than a string here, so that it reads and diffs as Dart. Like
/// every file of a brick, it is outside the analysis and the format of the
/// repository: the generated app formats and analyzes it with its own code.
final String urlSchemesHookText = utf8.decode(
  base64.decode(
    googleUrlSchemesBundle.files
        .singleWhere((file) => file.path == urlSchemesHook)
        .data,
  ),
);

/// Whether a way to sign in of the app, in [methods] by `firebaseMethodsOf`,
/// needs the client of the iOS app, whose reversed id is a URL scheme of the
/// app ([SignInNeed.iosClient]): the app then has [urlSchemesHook].
bool needsIosClient(Map<String, Set<SignInNeed>> methods) =>
    methods.values.any((needs) => needs.contains(SignInNeed.iosClient));
