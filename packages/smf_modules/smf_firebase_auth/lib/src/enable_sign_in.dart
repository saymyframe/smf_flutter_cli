import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';

/// The path in the app of the script that enables in the Firebase project
/// of the app the sign-in methods that the app needs: Email/Password, and
/// Anonymous when the app is in the mode `anonymous`.
///
/// The script is a file of the app, so the user runs it again later: for
/// another project, or after the mode of the app changed. It has only the
/// libraries of Dart, so `dart` runs it without the packages of the app.
///
/// - It reads the mode from the constant `authMode` in
///   [AuthRole.sessionFile], where the template of the auth role writes the
///   choice and where the developer of the app changes it. It reads the
///   line, since `dart` cannot load a file that imports Flutter. So the
///   script is the same in every mode, and follows a mode that changed.
/// - It reads the id of the project from `firebase.json` of the app, where
///   `flutterfire configure` of flutterfire_cli 1.4.1 writes it for each
///   platform (`lib/src/common/utils.dart` there): flutterfire writes no
///   `.firebaserc`. The arguments of the script may name another project
///   with `--project`.
/// - It enables the methods with `firebase deploy --only auth` of the
///   Firebase CLI, which reads them from the `auth` key of a
///   `firebase.json` and enables those that are `true`
///   (`lib/deploy/auth/deploy.js` of firebase-tools 15.14.0). It disables
///   nothing, so neither does the script.
/// - It gives the Firebase CLI a `firebase.json` of its own, in a temporary
///   directory that it removes afterwards, and runs the Firebase CLI there
///   with the project as `--project`. It writes nothing into the app: with
///   an `auth` key in `firebase.json` of the app, every later
///   `firebase deploy` of the app would deploy the sign-in methods too, and
///   ask for the permissions of that. A `.firebaserc` would make
///   `flutterfire configure` take its project without asking.
/// - It passes `--non-interactive`, and then its own arguments as they are.
///   The Firebase CLI takes the account that `firebase login:use` chose for
///   the directory it runs in, which here is the temporary one, so the
///   script tells of `--account` when the Firebase CLI fails.
/// - It asks the Firebase CLI for its version first, and stops with what to
///   do when the Firebase CLI is missing or older than
///   [firstFirebaseCliWithSignIn].
const enableSignInScript = 'tool/enable_firebase_sign_in.dart';

/// The command of [enableSignIn] as the user types it in the directory of
/// the app.
const enableSignInCommand = 'dart $enableSignInScript';

/// The first version of the Firebase CLI that has `deploy --only auth`.
const firstFirebaseCliWithSignIn = '15.6.0';

/// The check of the machine that [enableSignIn] needs: a Firebase CLI that
/// has `deploy --only auth`. The package of firebase_core knows how to ask
/// the Firebase CLI for its version, and this module which version its
/// command needs.
const firebaseCliWithSignIn = FirebaseCliVersionCheck(
  minimum: firstFirebaseCliWithSignIn,
);

/// What the user has to know before [enableSignIn] runs: the Firebase CLI
/// enables the methods through a web app of the project, and adds one,
/// named "Default Web App", to a project that has none
/// (`lib/deploy/auth/prepare.js` of firebase-tools 15.14.0, reported as
/// issue 11250 of firebase/firebase-tools). The Firebase console enables
/// the methods without it.
const enableSignInNotice = 'The Firebase CLI adds a web app named "Default '
    'Web App" to a project that has no web app, because it enables the '
    'methods through one (firebase/firebase-tools#11250). The Firebase '
    'console enables them without it: '
    'https://console.firebase.google.com/project/_/authentication/providers.';

/// The step that continues the step of firebase_core that runs
/// `flutterfire configure` ([FirebaseCoreModule.configureStep]), and
/// enables the sign-in methods of the app in the Firebase project that the
/// user chose there, with [enableSignInScript].
///
/// It changes the Firebase project, so it has a notice,
/// [enableSignInNotice], and a run asks the user before it: a run that
/// cannot ask, or that skips external setup, leaves the step for later
/// with its command, and so does a run in which flutterfire did not
/// configure the app. The Firebase CLI asks nothing, so the step runs
/// without the terminal. It needs a Firebase CLI with the command,
/// [firebaseCliWithSignIn].
final PostGenStep enableSignIn = PostGenStep(
  const ToolRef('dart'),
  const [enableSignInScript],
  followUpOf: FirebaseCoreModule.configureStep,
  description: 'Enabling the sign-in methods of the app in its Firebase '
      'project',
  notice: enableSignInNotice,
  skippable: true,
  external: true,
  needs: [firebaseCliWithSignIn.id],
);
