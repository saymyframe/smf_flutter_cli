import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_auth/src/identity_providers.dart';
import 'package:smf_firebase_core/smf_firebase_core.dart';

/// The path in the app of the script that enables in the Firebase project
/// of the app the sign-in methods that the app needs: Email/Password,
/// Anonymous when the app is in the mode `anonymous`, and the ways to sign
/// in of the app with an identity provider, with what they need of the
/// project.
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
/// - The code for the ways to sign in of Google is in sections of the brick
///   that the provider of the module fills from the ways to sign in of the
///   app (see [scriptVarsOf]). So the script of an app without one is the
///   script of Email/Password and Anonymous alone: the code that enables
///   Google comes with a way to sign in of Google, and what such a way
///   needs of the project, `_needs` ([SignInNeed]), with the code that sets
///   it up, comes with one that needs something.
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
///   `firebase.json` and enables those that are `true`, and Google with
///   the name and the support email of its consent screen
///   (`lib/deploy/auth/deploy.js` of firebase-tools 15.34.0). It disables
///   nothing, so neither does the script. Google needs both fields: without
///   them the Firebase CLI waited for Google for 180 seconds and failed,
///   and with them it was done in 17. The name is that of the app, as
///   flutter_core names the app on the devices, and the support email the
///   address of the account of the Firebase CLI: the one that `--account`
///   names, or else the one that `firebase login:list` prints that it is
///   logged in as. The script does not read that list with `--json`, which
///   has the tokens of the accounts. When the Firebase CLI is logged in as
///   no user, as with a service account, the script leaves Google out and
///   says so.
/// - It runs the Firebase CLI in a temporary directory, with a
///   `firebase.json` of its own there, and removes the directory
///   afterwards. Every call runs there, the one for the version too: the
///   Firebase CLI opens its log, `firebase-debug.log`, in the directory it
///   runs in, on every call (`lib/logger.js`). So the Firebase CLI writes
///   no file of the app. With an `auth` key in `firebase.json` of the app,
///   every later `firebase deploy` of the app would deploy the sign-in
///   methods too, and ask for the permissions of that. A `.firebaserc`
///   would make `flutterfire configure` take its project without asking.
/// - For a way to sign in that needs it, and only for the project that
///   `firebase.json` names, whose apps it names there, it registers the
///   SHA-1 and SHA-256 of the Android debug key of the machine
///   ([SignInNeed.androidCertificate]) with
///   `firebase apps:android:sha:create`, those that
///   `firebase apps:android:sha:list` does not list. It reads them with
///   keytool, from where the Android Gradle plugin 9 keeps the key
///   (`AbstractAndroidLocations` of the plugin), and creates the key as the
///   plugin does when there is none. It takes the keytool on the PATH, in
///   JAVA_HOME or of Android Studio at its default place, the first that
///   runs.
/// - Then it downloads the Firebase files of the app again with
///   `firebase apps:sdkconfig --json` ([SignInNeed.serverClient] for
///   Android, [SignInNeed.iosClient] for iOS): they have the clients of
///   Google only once Google is enabled. It writes them where
///   `flutterfire configure` wrote them, a file that changed only, and only
///   once it has the clients. Right after it enabled Google, it asks for a
///   file without them again for 15 seconds at most: a check against a
///   real project found them in the first answer. `--out` refuses a file
///   that exists in a run without a terminal
///   (`lib/commands/apps-sdkconfig.js`).
/// - Then it writes the URL scheme of the iOS app, the reversed id of its
///   client of Google, into `CFBundleURLTypes` of `ios/Runner/Info.plist`,
///   as text with the libraries of Dart. It adds a scheme and removes none,
///   and leaves a file that has it as it is. It stops at a file in any
///   other form, with what to add there by hand.
/// - Apple is enabled in the Firebase console, which no command of the
///   Firebase CLI does, so in an app with a way to sign in of Apple the
///   script tells what to set there, with the code for that alone.
/// - It runs the Firebase CLI with `NO_UPDATE_NOTIFIER`, without its check
///   for a newer version: that check runs on as a process of its own in
///   the same directory (`update-notifier-cjs` of firebase-tools 15.14.0),
///   and on Windows the directory of a process that runs cannot be
///   removed. When the script cannot remove the directory, it says so and
///   exits with its code all the same.
/// - It watches for Ctrl+C: it lets the process that runs end, removes the
///   directory and exits with 130. In a terminal the process gets the
///   signal with the script, and elsewhere the script passes it on, which
///   Windows has no way to do. A script that is stopped in another way
///   leaves the directory.
/// - It passes `--non-interactive`, and then its other arguments as they
///   are, to `firebase deploy`, and an account that they name to every
///   call. The Firebase CLI takes the account that `firebase login:use`
///   chose for the directory it runs in, which here is the temporary one.
///   So after a failure the script tells of `--account`, unless the
///   arguments name an account, which it then names, and of `--debug`,
///   since the log is removed with the directory. A step that fails after
///   the methods are enabled ends the script with the code 1, and what it
///   did before stays done.
/// - It asks the Firebase CLI for its version first, and stops with what to
///   do when the Firebase CLI is missing or older than
///   [firstFirebaseCliWithSignIn] (an older one adds a web app to a project
///   with only Android and iOS apps), by the rule of [firebaseCliWithSignIn]:
///   the last line that is a version counts, and a pre-release of that
///   version comes before it. A version that it cannot read passes, since
///   the Firebase CLI then tells itself what it cannot do.
const enableSignInScript = 'tool/enable_firebase_sign_in.dart';

/// The command of [enableSignIn] as the user types it in the directory of
/// the app.
const enableSignInCommand = 'dart $enableSignInScript';

/// The first version of the Firebase CLI whose `deploy --only auth` adds
/// no app to a project that has one.
///
/// `deploy --only auth` came with 15.6.0, and enables the methods through
/// an app of the project. Before 15.34.0 that had to be a web app, and the
/// Firebase CLI added one, named "Default Web App", to a project without
/// one, also to a project with the Android and iOS apps that
/// `flutterfire configure` registers. 15.34.0 takes an app of any platform,
/// and adds a web app only to a project without any app
/// (`lib/deploy/auth/prepare.js` of firebase-tools 15.34.0). The step runs
/// after `flutterfire configure`, so the project has the apps of the app by
/// then.
const firstFirebaseCliWithSignIn = '15.34.0';

/// The check of the machine that [enableSignIn] needs: a Firebase CLI whose
/// `deploy --only auth` adds no app to the project of the app,
/// [firstFirebaseCliWithSignIn]. The package of firebase_core knows how to
/// ask the Firebase CLI for its version, and this module which version its
/// command needs.
const firebaseCliWithSignIn = FirebaseCliVersionCheck(
  minimum: firstFirebaseCliWithSignIn,
);

/// What the user has to know before [enableSignIn] runs, beyond enabling
/// the sign-in methods: what the script does in the Firebase project and
/// in the app for a way to sign in of Google (see [enableSignInScript]).
///
/// The step is the same in every app, whatever its ways to sign in: a step
/// takes no condition on what a role chose, which the pipeline needs before
/// any role chooses, and a step that continues another takes no condition
/// at all. So the notice tells what the script does for a way to sign in
/// of Google, which is true in every app, and a run asks about the step in
/// every app.
const enableSignInNotice = 'For a way to sign in of Google, it also gives '
    'Google the name of the app and the email address of the account of the '
    'Firebase CLI for its consent screen, registers the SHA-1 and SHA-256 of '
    'the Android debug key of this machine, creating the key as the first '
    'debug build would if there is none, downloads the Firebase files of the '
    'app again and writes the URL scheme of the iOS app into '
    'ios/Runner/Info.plist.';

/// The ways to sign in of the app in [methods] as the script of the app
/// sets them up: by the id of their identity provider in Firebase
/// Authentication, in the order of the ways to sign in, each with what the
/// ways to sign in with it need of the Firebase project. One of an identity
/// provider that the module does not take is left out: the provider of the
/// module refuses the app.
Map<String, Set<SignInNeed>> firebaseMethodsOf(
  List<AppSignInMethod> methods,
) {
  final byId = <String, Set<SignInNeed>>{};
  for (final AppSignInMethod(:method) in methods) {
    if (identityProviders[method.issuer] case final provider?) {
      byId.putIfAbsent(provider.id, () => {}).addAll(method.needs);
    }
  }
  return byId;
}

/// The variables of the brick for the script of an app with the ways to
/// sign in [methods], by [firebaseMethodsOf]:
/// - `google`, whether the app has a way to sign in of Google, which gives
///   the script the code that enables Google;
/// - `apple`, whether the app has a way to sign in of Apple, which gives
///   the script the line that tells what to set in the Firebase console;
/// - `setup`, whether a way to sign in needs something of the project,
///   which gives the script the code that sets it up and the needs,
///   `needs`, the value of its constant `_needs`: the values of its enum
///   `_Need`, which are named after the [SignInNeed]s, in their order, on
///   one line, as `dart format` writes a set that fits on it.
///
/// `setup` comes only with `google`: the module sets up what a way to sign
/// in needs for Google alone (see [identityProviders]), and its provider
/// refuses an app with another one that needs something.
Map<String, Object> scriptVarsOf(Map<String, Set<SignInNeed>> methods) {
  final needs = [
    for (final need in SignInNeed.values)
      if (methods.values.any((needs) => needs.contains(need)))
        '_Need.${need.name}',
  ];
  return {
    'google': methods.containsKey('google.com'),
    'apple': methods.containsKey('apple.com'),
    'setup': needs.isNotEmpty,
    'needs': '{${needs.join(', ')}}',
  };
}

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
/// For a way to sign in of Google, the script also changes the project and
/// files of the app, so the step has a notice, [enableSignInNotice]: a run
/// asks about it once flutterfire configured the app. A step cannot tell
/// the ways to sign in of the app, so the step and its notice are the same
/// in every app. A run that leaves `flutterfire configure` for later, such
/// as one that cannot ask or that skips external setup, leaves this step
/// for later with it, with its command and its notice, and so does a run
/// in which flutterfire did not configure the app. The Firebase CLI asks
/// nothing, so the step runs without the terminal. It needs a Firebase CLI
/// that adds no app to the project, [firebaseCliWithSignIn].
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
