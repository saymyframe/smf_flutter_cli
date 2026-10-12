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
///   choice and where the developer of the app changes it, with the
///   expression of the role for it, [AuthRole.modeDeclaration]: `dart`
///   cannot load a file that imports Flutter. So the script is the same in
///   every mode, and follows a mode that changed. It stops when the file
///   does not tell the mode, rather than guess.
/// - It reads the id of the project from `firebase.json` of the app, where
///   `flutterfire configure` of flutterfire_cli 1.4.1 writes it for each
///   platform (`lib/src/common/utils.dart` there): flutterfire writes no
///   `.firebaserc`. Its arguments may name another project.
/// - The project of the Firebase CLI is the script's to give. The Firebase
///   CLI takes the last `--project` or `-P` of its arguments before `--`
///   (`parseOptions` of commander 5.1.0 in firebase-tools 15.14.0), so the
///   script takes that one too, passes none of them on, and gives the
///   Firebase CLI `--project=` with the project that it printed. It stops
///   at short options in one argument with `P` among them, which the
///   Firebase CLI may read as a project too. So the Firebase CLI never
///   gets another project than the one that the script named.
/// - It enables the methods with `firebase deploy --only auth` of the
///   Firebase CLI, which reads them from the `auth` key of a
///   `firebase.json` and enables those that are `true`
///   (`lib/deploy/auth/deploy.js` of firebase-tools 15.14.0). It disables
///   nothing, so neither does the script.
/// - It runs the Firebase CLI in a temporary directory, with a
///   `firebase.json` of its own there, and removes the directory
///   afterwards. Every call runs there, the one for the version too: the
///   Firebase CLI opens its log, `firebase-debug.log`, in the directory it
///   runs in, on every call (`lib/logger.js`). So no file of the app
///   changes. With an `auth` key in `firebase.json` of the app, every later
///   `firebase deploy` of the app would deploy the sign-in methods too, and
///   ask for the permissions of that. A `.firebaserc` would make
///   `flutterfire configure` take its project without asking.
/// - It runs the Firebase CLI with `NO_UPDATE_NOTIFIER`, without its check
///   for a newer version: that check runs on as a process of its own in
///   the same directory (`update-notifier-cjs` of firebase-tools 15.14.0),
///   and on Windows the directory of a process that runs cannot be
///   removed. When the script cannot remove the directory, it says so and
///   exits with the code of the Firebase CLI all the same.
/// - It watches for Ctrl+C: it lets the Firebase CLI end, removes the
///   directory and exits with 130. In a terminal the Firebase CLI gets the
///   signal with the script, and elsewhere the script passes it on, which
///   Windows has no way to do. A script that is stopped in another way
///   leaves the directory.
/// - It passes `--non-interactive`, and then its other arguments as they
///   are. The Firebase CLI takes the account that `firebase login:use`
///   chose for the directory it runs in, which here is the temporary one.
///   So after a failure the script tells of `--account`, unless the
///   arguments name an account, which it then names, and of `--debug`,
///   since the log is removed with the directory.
/// - It asks the Firebase CLI for its version first, and stops with what to
///   do when the Firebase CLI is missing or older than
///   [firstFirebaseCliWithSignIn], by the rule of [firebaseCliWithSignIn]:
///   the last line that is a version counts, and a pre-release of that
///   version comes before it. A version that it cannot read passes, since
///   the Firebase CLI then tells itself what it cannot do.
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
///
/// The address of that page is followed by a space, so that a terminal
/// which makes a link of it takes no punctuation into the link.
const enableSignInNotice = 'The Firebase CLI adds a web app named "Default '
    'Web App" to a project that has no web app, because it enables the '
    'methods through one (firebase/firebase-tools#11250). The page '
    'https://console.firebase.google.com/project/_/authentication/providers '
    'of the Firebase console enables them without it.';

/// The expression of the auth role for the declaration of `authMode`
/// ([AuthRole.modeDeclaration]) as code of the script; see [rawStringsOf].
final String modeDeclarationCode = rawStringsOf(AuthRole.modeDeclaration);

/// [pattern], a regular expression without a quote, as code of Dart: raw
/// strings next to each other, each on a line of its own after the first,
/// with two spaces before it, and of at most 78 columns with them.
///
/// A string ends before an alternative of the pattern where it can, and
/// none ends with a backslash, which would read as if it took the quote
/// after it.
String rawStringsOf(String pattern) {
  const width = 72;
  final lines = <String>[];
  var rest = pattern;
  while (rest.length > width) {
    final alternative = rest.lastIndexOf('|', width);
    var end = alternative > 0 ? alternative : width;
    while (rest[end - 1] == r'\') {
      end--;
    }
    lines.add("r'${rest.substring(0, end)}'");
    rest = rest.substring(end);
  }
  lines.add("r'$rest'");
  return lines.join('\n  ');
}

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
