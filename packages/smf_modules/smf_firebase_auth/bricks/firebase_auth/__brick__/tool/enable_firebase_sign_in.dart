// Enables the sign-in methods of the app in its Firebase project:
// Email/Password, and Anonymous when the app is in the mode `anonymous`,
// which the script reads from `authMode` of the app.
//
//     dart tool/enable_firebase_sign_in.dart
//
// The project is the one of `firebase.json` of the app, where
// `{{{configure_script}}}` writes the project of each flavor, or the one that
// `--project <id>` names. Where the flavors have several projects, the script
// needs `--project <id>`, and a run for each project. The script says which
// project it runs for, and gives the Firebase CLI that project and no other.
//
// The script enables the methods with `firebase deploy --only auth` of the
// Firebase CLI, which enables what its configuration names and disables
// nothing. It runs the Firebase CLI in a temporary directory, with a
// configuration of its own there, so no file of the app changes:
// `firebase.json` of the app stays as it is, and a `firebase deploy` of the
// app does not touch the sign-in methods. The Firebase CLI keeps its log in
// the directory that it runs in, so the log is not in the app either.
//
// The script removes the temporary directory when the Firebase CLI ends.
// After Ctrl+C it waits for the Firebase CLI to end, removes the directory
// and exits with the code 130. A script that is stopped in another way, as
// with `kill`, leaves the directory among the temporary files of the
// system, and so does Ctrl+C where the script cannot watch for it.
//
// The other arguments go to the Firebase CLI as they are. An account that
// `firebase login:use` chose for the directory of the app does not apply in
// the temporary directory: `--account <email>` names the account.{{#google}}
//
// For a way to sign in of Google, the script enables Google too, and gives
// it the name of the app and a support email for its consent screen: the
// email address of the account of the Firebase CLI, the one that
// `--account <email>` names, or else the one that the Firebase CLI is
// logged in as. With no such account, as with a service account, it leaves
// Google out and says so.{{/google}}{{#setup}}
//
// The ways to sign in of Google need more of the project and of the app,
// which the script then sets up for the apps that `firebase.json` names in
// the project of the run:
// - it registers the SHA-1 and SHA-256 of the Android debug key of this
//   machine for each Android app, and creates that key as the first debug
//   build would when there is none;
// - it downloads the Firebase files of those apps again once they have the
//   clients of Google, to the paths that `firebase.json` names;
// - it writes the URL scheme of each iOS app, the reversed id of its client
//   of Google, into `ios/Runner/Info.plist`, which all the flavors share. It
//   adds a scheme and removes none, and a file that has it already stays as
//   it is.
// These are the only files of the app that the script changes. Of the
// other arguments, those calls of the Firebase CLI get only the account.{{/setup}}{{#apple}}
//
// Apple is enabled in the Firebase console, which no command of the
// Firebase CLI does, so the script tells what to set there.{{/apple}}

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The first version of the Firebase CLI whose `deploy --only auth` adds no
/// web app to a project that has Android and iOS apps.
const _firstCli = '{{{minimum_firebase_cli}}}';

/// The file of the app with `authMode`, the sign-in mode of the app.
const _sessionFile = '{{{session_file}}}';

/// The mode in which the app signs in anonymous users.
const _anonymous = '{{{anonymous_mode}}}';{{#google}}

/// The name of the app, which Google shows on its consent screen.
const _appName = '{{app_name.titleCase()}}';{{/google}}{{#setup}}

/// What a way to sign in needs of the Firebase project, besides the
/// identity provider enabled.
enum _Need {
  /// The SHA-1 and SHA-256 of the key that signs the Android app.
  androidCertificate,

  /// The client of the iOS app in its Firebase file, whose reversed id is a
  /// URL scheme of the app.
  iosClient,

  /// The client of the server in the Firebase file of the Android app.
  serverClient,
}

/// What the ways to sign in of the app need of the Firebase project. SMF
/// wrote it from the ways to sign in of the app.
const _needs = {{{needs}}};

/// The file of the app with the URL schemes of the iOS app.
const _infoPlist = 'ios/Runner/Info.plist';{{/setup}}

/// The comments of [_sessionFile] and the declarations of `authMode` in it,
/// in the form that the file keeps: a declaration starts its line and has a
/// mode as its value, and only a declaration has the first group, the name
/// of its mode.
final _modeDeclaration = RegExp(
  {{{mode_declaration}}},
  multiLine: true,
);

/// This script, as the user runs it in the directory of the app.
const _command = 'dart tool/enable_firebase_sign_in.dart';

/// The script of the app that configures Firebase for a flavor.
const _configureScript = '{{{configure_script}}}';

/// The command that configures Firebase for a flavor of the app.
const _configure = 'dart $_configureScript <flavor> --project=<id>';

Future<void> main(List<String> arguments) async {
  // The app is the directory above `tool`, wherever the script is run from,
  // also through a link to it.
  final script = File.fromUri(Platform.script).resolveSymbolicLinksSync();
  try {
    exitCode = await _enable(File(script).parent.parent, arguments);
  } on _Stop catch (stop) {
    stderr.writeln(stop.why);
    exitCode = 1;
  }
}

/// Enables the sign-in methods that [app] needs in its Firebase project, or
/// in the one that [arguments] name, and returns the exit code of the
/// Firebase CLI, or 130 after Ctrl+C.
///
/// Throws a [_Stop] when it cannot tell the methods or the project, and
/// when the Firebase CLI of the machine cannot enable them.{{#setup}}
///
/// Once the methods are enabled, it sets up what the ways to sign in of the
/// app need there, and returns 1 when that fails.{{/setup}}
Future<int> _enable(Directory app, List<String> arguments) async {
  final mode = _modeOf(app);
  final anonymous = mode == _anonymous;
  final (named, passedOn) = _withoutProject(arguments);
  if (named != null && !_projectId.hasMatch(named)) {
    throw _Stop(
      'The arguments name "$named" as the Firebase project, which is no id '
      'of a project.',
    );
  }
  final project = named ?? _configuredProject(app);
  // This script as the user runs it again for the same project. Without the
  // project that the arguments name, it could stop at several projects.
  final again = named == null ? _command : '$_command --project $project';{{#google}}
  final account = _accountIn(passedOn);{{/google}}{{#setup}}
  // What the ways to sign in need is for the apps of the app in the
  // project.
  final apps = _appsOf(app, project);{{/setup}}

  // Every call of the Firebase CLI runs in this directory, also the one for
  // its version: the Firebase CLI keeps its log in the directory that it
  // runs in.
  final directory = Directory.systemTemp.createTempSync('firebase_sign_in_');
  Process? firebase;
  var interrupted = false;
  // Ctrl+C. In a terminal, the Firebase CLI gets the signal with the
  // script, and elsewhere the script passes it on, which Windows has no way
  // to do. Where the signal cannot be watched, Ctrl+C ends the script at
  // once, and the directory stays.
  final interrupts = ProcessSignal.sigint.watch().listen((_) {
    interrupted = true;
    if (!Platform.isWindows) firebase?.kill(ProcessSignal.sigint);
  }, onError: (Object _) {});
  Future<Process> start(List<String> arguments, ProcessStartMode mode) async =>
      firebase = await Process.start(
        'firebase',
        arguments,
        workingDirectory: directory.path,
        // Without its check for a newer version, which runs on as a process
        // of its own: on Windows, the directory of a process that runs
        // cannot be removed.
        environment: const {'NO_UPDATE_NOTIFIER': '1'},
        mode: mode,
        // On Windows, npm installs the Firebase CLI as `firebase.cmd`.
        runInShell: Platform.isWindows,
      );{{#google}}
  // Runs the Firebase CLI with [arguments], and returns its exit code, what
  // it printed and its errors.
  Future<(int, String, String)> run(List<String> arguments) async {
    final process = await start(arguments, ProcessStartMode.normal);
    final printed = process.stdout.transform(systemEncoding.decoder).join();
    final failed = process.stderr.transform(systemEncoding.decoder).join();
    final code = await process.exitCode;
    return (code, await printed, (await failed).trim());
  }{{/google}}{{#setup}}
  // Runs [executable], a tool such as keytool, with [arguments], in a shell
  // on Windows when [inShell], and returns its exit code, what it printed
  // and its errors. Ctrl+C reaches it as it reaches the Firebase CLI.
  Future<(int, String, String)> tool(
    String executable,
    List<String> arguments, {
    bool inShell = false,
  }) async {
    final process = firebase = await Process.start(
      executable,
      arguments,
      runInShell: inShell && Platform.isWindows,
    );
    final printed = process.stdout.transform(systemEncoding.decoder).join();
    final failed = process.stderr.transform(systemEncoding.decoder).join();
    final code = await process.exitCode;
    return (code, await printed, (await failed).trim());
  }{{/setup}}
  try {
    final int asked;
    final String version;
    final String errors;
    try {
      final process = await start(const ['--version'], ProcessStartMode.normal);
      final printed = process.stdout.transform(systemEncoding.decoder).join();
      final failed = process.stderr.transform(systemEncoding.decoder).join();
      asked = await process.exitCode;
      version = await printed;
      errors = (await failed).trim();
    } on ProcessException catch (error) {
      throw _Stop(_notRunning(error.message, project));
    }
    if (interrupted) return 130;
    if (asked != 0) {
      throw _Stop(
        _notRunning(
          'exit code $asked${errors.isEmpty ? '' : ': $errors'}',
          project,
        ),
      );
    }
    if (_olderCli(version) case final older?) {
      throw _Stop(
        'The Firebase CLI of this machine is $older, and enabling sign-in '
        'methods needs $_firstCli or later. Update it with "npm install -g '
        'firebase-tools" if npm installed it, or see '
        'https://firebase.google.com/docs/cli#update-cli\n'
        '${_inConsole(project)}',
      );
    }{{#google}}

    // Google shows the name of the app and a support email on its consent
    // screen: the email address of the account that the arguments name, or
    // else of the one that the Firebase CLI is logged in as here.
    final supportEmail = account ?? await _loggedInAs(run);
    if (interrupted) return 130;
    if (supportEmail == null) {
      stdout.writeln(_withoutGoogle(project, again));
    }
    final google = supportEmail != null;{{/google}}

    File('${directory.path}/firebase.json').writeAsStringSync(
      jsonEncode({
        'auth': {
          'providers': {
            'emailPassword': true,
            if (anonymous) 'anonymous': true,{{#google}}
            if (google)
              'googleSignIn': {
                'oAuthBrandDisplayName': _appName,
                'supportEmail': supportEmail,
              },{{/google}}
          },
        },
      }),
    );{{^google}}
    stdout.writeln(
      'Enabling Email/Password${anonymous ? ' and Anonymous' : ''} in the '
      'Firebase project $project (the mode of the app is $mode).',
    );{{/google}}{{#google}}
    final enabled = _listed([
      'Email/Password',
      if (anonymous) 'Anonymous',
      if (google) 'Google',
    ]);
    stdout.writeln(
      'Enabling $enabled in the Firebase project $project (the mode of the '
      'app is $mode).',
    );
    if (google) {
      stdout.writeln(
        'Google shows the name "$_appName" and the support email '
        '$supportEmail on its consent screen.',
      );
    }{{/google}}
    // What the Firebase CLI prints comes after this line.
    await stdout.flush();
    if (interrupted) return 130;
    final deploy = await start([
      'deploy',
      '--only',
      'auth',
      // The project that the line above names, and no other: the arguments
      // that are passed on name none.
      '--project=$project',
      '--non-interactive',
      ...passedOn,
    ], ProcessStartMode.inheritStdio);
    final code = await deploy.exitCode;
    if (interrupted) return 130;
    if (code != 0) {
      stderr.writeln(_afterFailure(code, project, passedOn, again));
    }{{#google}}
    if (code != 0) return code;{{/google}}{{#apple}}
    if (code == 0) stdout.writeln(_appleInConsole(project));{{/apple}}{{#setup}}
    try {
      await _setUp(
        app,
        _Cli(run, tool, project, account, again, () => interrupted),
        _needs,
        apps,
        waitForClients: google,
      );
    } on _Interrupted {
      return 130;
    } on _Failed catch (failed) {
      stderr
        ..writeln(failed.why)
        ..writeln(
          'What this script did before that stays done, and running it '
          'again does the rest: $again',
        );
      return 1;
    }{{/setup}}
    return code;
  } finally {
    await interrupts.cancel();
    try {
      directory.deleteSync(recursive: true);
    } on FileSystemException catch (error) {
      stderr.writeln(
        'The temporary directory ${directory.path} of this script is left: '
        '${error.message}.',
      );
    }
  }
}

/// Why the script stops before it runs the Firebase CLI.
final class _Stop implements Exception {
  const _Stop(this.why);

  final String why;
}{{#setup}}

/// Why the script stops once it enabled the sign-in methods, before it set
/// up all that the ways to sign in need.
final class _Failed implements Exception {
  const _Failed(this.why);

  final String why;
}

/// Ctrl+C, after which the script stops once the process that runs ended.
final class _Interrupted implements Exception {
  const _Interrupted();
}

/// The Firebase CLI and the other tools as the script runs them to set up
/// what the ways to sign in need: the Firebase CLI for [project], as
/// [account] if the arguments of the script name one, and the other tools,
/// both so that Ctrl+C reaches them, with the command that runs the script
/// again for the project, [again], and what tells whether the user pressed
/// Ctrl+C.
final class _Cli {
  _Cli(
    this._firebase,
    this._tool,
    this.project,
    this.account,
    this.again,
    this._interrupted,
  );

  final Future<(int, String, String)> Function(List<String> arguments)
      _firebase;
  final Future<(int, String, String)> Function(
    String executable,
    List<String> arguments, {
    bool inShell,
  }) _tool;
  final String project;
  final String? account;
  final String again;
  final bool Function() _interrupted;

  /// Runs [executable] with [arguments], in a shell on Windows when
  /// [inShell], and returns its exit code, its output and its errors.
  /// Throws an [_Interrupted] after Ctrl+C.
  Future<(int, String, String)> run(
    String executable,
    List<String> arguments, {
    bool inShell = false,
  }) async {
    final result = await _tool(executable, arguments, inShell: inShell);
    if (_interrupted()) throw const _Interrupted();
    return result;
  }

  /// Runs the Firebase CLI with [arguments], for the project and as the
  /// account of the script, and returns the result that it gives as JSON.
  ///
  /// Throws a [_Failed] that tells that the Firebase CLI did not do [what]
  /// when it fails or gives no result, and an [_Interrupted] after Ctrl+C.
  Future<Object?> json(List<String> arguments, String what) async {
    final (code, printed, errors) = await _firebase([
      ...arguments,
      '--project=$project',
      '--non-interactive',
      '--json',
      if (account case final account?) '--account=$account',
    ]);
    if (_interrupted()) throw const _Interrupted();
    final start = printed.indexOf('{');
    Object? answer;
    try {
      answer = start < 0 ? null : jsonDecode(printed.substring(start));
    } on FormatException {
      answer = null;
    }
    if (answer case {'status': 'success', 'result': final result}
        when code == 0) {
      return result;
    }
    final error = switch (answer) {
      {'error': final String error} => error,
      _ => [printed.trim(), errors].where((text) => text.isNotEmpty).join(' '),
    };
    throw _Failed(
      'The Firebase CLI did not $what (exit code $code)'
      '${error.isEmpty ? '' : ': $error'}\n${_accountHint(account, again)}',
    );
  }
}{{/setup}}

/// An id of a Firebase project, as the Firebase CLI takes it: lower-case
/// letters, digits and hyphens, after the domain of an organization, if it
/// has one.
final _projectId = RegExp(r'^(?:[a-z0-9][a-z0-9.-]*:)?[a-z0-9][a-z0-9-]*$');

/// How to enable the methods without the Firebase CLI: in the Firebase
/// console of [project], or of the project that the user picks there.
String _inConsole([String project = '_']) =>
    'The Firebase console enables the methods too, under Authentication > '
    'Sign-in method: https://console.firebase.google.com/project/$project/'
    'authentication/providers';

/// What the script tells when the Firebase CLI does not run, because of
/// [why].
String _notRunning(String why, String project) =>
    'The Firebase CLI did not run ($why). Install it, or put it on the '
    'PATH: https://firebase.google.com/docs/cli\n${_inConsole(project)}';{{#apple}}

/// What the script tells of Apple, which only the Firebase console of
/// [project] enables.
String _appleInConsole(String project) =>
    'Apple is enabled in the Firebase console, which the Firebase CLI '
    'cannot do: https://console.firebase.google.com/project/$project/'
    'authentication/providers\nThe deletion of an account of Apple also '
    'needs the Services ID and the OAuth code flow configuration of Apple '
    'there; see the section Firebase Authentication of README.md.';{{/apple}}{{#google}}

/// [items] as a sentence lists them, such as `A, B and C`.
String _listed(List<String> items) => items.length < 2
    ? items.join()
    : '${items.sublist(0, items.length - 1).join(', ')} and ${items.last}';

/// The page of the Firebase console with the sign-in methods of [project].
String _consoleOf(String project) =>
    'https://console.firebase.google.com/project/$project/authentication/'
    'providers';

/// What the script tells when it leaves Google out in [project], since the
/// Firebase CLI runs as no user account, and how to run it again, [again].
String _withoutGoogle(String project, String again) =>
    'Google is left out: its consent screen needs a support email, the '
    'email address of a user account of the Firebase CLI, and the Firebase '
    'CLI runs as none here, as with a service account. To enable Google, '
    'run: $again --account <email>, '
    'or enable it in the Firebase console: ${_consoleOf(project)}';

/// The account that [options], the arguments of the script for the Firebase
/// CLI, name: the last one before `--`, as the Firebase CLI takes it, if
/// any.
String? _accountIn(List<String> options) {
  final before = options.takeWhile((argument) => argument != '--').toList();
  String? account;
  for (final (index, option) in before.indexed) {
    if (option.startsWith('--account=')) {
      account = option.substring('--account='.length);
    } else if (option == '--account' && index + 1 < before.length) {
      account = before[index + 1];
    }
  }
  return account;
}

/// The email address of the user account that the Firebase CLI is logged
/// in as, as [run] runs it, or `null` if it is logged in as none, as with a
/// service account. It reads what `firebase login:list` prints, not what it
/// gives with `--json`, which has the tokens of the accounts.
Future<String?> _loggedInAs(
  Future<(int, String, String)> Function(List<String> arguments) run,
) async {
  final (code, printed, _) = await run(const ['login:list']);
  if (code != 0) return null;
  return RegExp(r'^Logged in as (\S+@\S+)$', multiLine: true)
      .firstMatch(printed.replaceAll('\r', ''))?[1];
}{{/google}}{{#setup}}

/// What the script tells of [account], the one that its arguments name,
/// after a call of the Firebase CLI failed, with the command that runs the
/// script again, [again].
String _accountHint(String? account, String again) => account != null
    ? '- The arguments name the account $account for it. "firebase '
        'login:list" shows the accounts that the Firebase CLI has.'
    : '- If it ran as the wrong account: this script runs the Firebase CLI '
        'in a temporary directory, where an account that "firebase '
        'login:use" chose for the directory of the app does not apply. To '
        'name the account, run: $again --account <email>';{{/setup}}

/// What the script tells after the Firebase CLI failed with the exit code
/// [code] for [project], with the arguments [passedOn]: which account it
/// may have run as, where its log was, and the other way to enable the
/// methods. [again] is the command that runs the script again.
String _afterFailure(
  int code,
  String project,
  List<String> passedOn,
  String again,
) {
  final options = passedOn.takeWhile((argument) => argument != '--').toList();
  // The last account that the options name is the one of the Firebase CLI.
  String? account;
  for (final (index, option) in options.indexed) {
    if (option.startsWith('--account=')) {
      account = option.substring('--account='.length);
    } else if (option == '--account' && index + 1 < options.length) {
      account = options[index + 1];
    }
  }
  return [
    'The Firebase CLI did not enable the sign-in methods (exit code $code).',
    if (account != null)
      '- The arguments name the account $account for it. "firebase '
          'login:list" shows the accounts that the Firebase CLI has.'
    else
      '- If it ran as the wrong account: this script runs the Firebase CLI '
          'in a temporary directory, where an account that "firebase '
          'login:use" chose for the directory of the app does not apply. To '
          'name the account, run: $again --account <email>',
    if (!options.contains('--debug'))
      '- Its log, firebase-debug.log, was in that temporary directory, '
          'which this script removes. To see what the Firebase CLI did, '
          'run: $again --debug',
    '- ${_inConsole(project)}',
  ].join('\n');
}

/// The text of [file], which is in UTF-8.
String _textOf(File file) {
  try {
    return file.readAsStringSync();
  } on FileSystemException catch (error) {
    throw _Stop(
      '${file.path} could not be read as a text in UTF-8 (${error.message}).',
    );
  }
}

/// The sign-in mode of [app], such as `required`, as `authMode` in
/// [_sessionFile] has it.
///
/// That file imports Flutter, so this script cannot import it, and reads
/// the declaration of the constant instead; see [_modeDeclaration].
String _modeOf(Directory app) {
  const cannotTell =
      'Cannot tell the sign-in mode of the app, by which this '
      'script enables Anonymous or leaves it out';
  final file = File('${app.path}/$_sessionFile');
  if (!file.existsSync()) {
    throw _Stop('$cannotTell: ${file.path} is missing.\n${_inConsole()}');
  }
  final modes = [
    for (final match in _modeDeclaration.allMatches(_textOf(file))) ?match[1],
  ];
  if (modes.length != 1) {
    throw _Stop(
      '$cannotTell: ${file.path} does not have one declaration such as '
      '"const AuthMode authMode = AuthMode.required;", which starts its line '
      'and has a mode of the app as its value.\n'
      '${_inConsole()}',
    );
  }
  return modes.single;
}

/// The project that [arguments] name for the Firebase CLI, if they name
/// one, and the arguments without what names it.
///
/// The Firebase CLI takes the last `--project <id>`, `--project=<id>`,
/// `-P <id>` or `-P<id>` before `--`, so the script does too, and passes
/// none of them on: it gives the Firebase CLI the project itself. It stops
/// at short options in one argument that have `P` among them, such as
/// `-jP`, which the Firebase CLI may read as a project too.
(String?, List<String>) _withoutProject(List<String> arguments) {
  final end = arguments.indexOf('--');
  final options = end < 0 ? arguments : arguments.sublist(0, end);
  String? project;
  final others = <String>[];
  for (var index = 0; index < options.length; index++) {
    final option = options[index];
    if (option == '--project' || option == '-P') {
      if (++index == options.length) {
        throw _Stop('$option needs the id of a Firebase project after it.');
      }
      project = options[index];
    } else if (option.startsWith('--project=')) {
      project = option.substring('--project='.length);
    } else if (option.startsWith('-P')) {
      project = option.substring(2);
    } else if (RegExp(r'^-[A-Za-z]*P').hasMatch(option)) {
      throw _Stop(
        'Cannot tell whether "$option" names a Firebase project. Name the '
        'project with --project <id>, apart from the other options.',
      );
    } else {
      others.add(option);
    }
  }
  return (project, [...others, if (end >= 0) ...arguments.sublist(end)]);
}

/// The id of the Firebase project in `firebase.json` of [app], where
/// [_configureScript] writes the project of each flavor: under `flutter`,
/// each platform of the app has the id of its project. Flavors may have
/// several projects, and a run of this script is for one.
String _configuredProject(Directory app) {
  final file = File('${app.path}/firebase.json');
  const orName = 'or name the project: $_command --project <id>';
  if (!file.existsSync()) {
    throw _Stop(
      '${file.path} is missing, so no flavor of the app is configured for '
      'Firebase yet. Configure one first with "$_configure" (see README.md), '
      '$orName',
    );
  }
  final Object? json;
  try {
    json = jsonDecode(_textOf(file));
  } on FormatException catch (error) {
    throw _Stop(
      '${file.path} is not JSON (${error.message}). Configure a flavor again '
      'with "$_configure" (see README.md), $orName',
    );
  }
  final projects = <String>{};
  void collect(Object? node) {
    if (node is! Map) return;
    for (final MapEntry(:key, :value) in node.entries) {
      if (key == 'projectId' && value is String) {
        projects.add(value);
      } else {
        collect(value);
      }
    }
  }

  collect(json is Map ? json['flutter'] : null);
  if (projects.isEmpty) {
    throw _Stop(
      '${file.path} names no Firebase project. Configure a flavor first with '
      '"$_configure" (see README.md), $orName',
    );
  }
  if (projects.length > 1) {
    final commands = [
      for (final project in projects) '$_command --project $project',
    ];
    throw _Stop(
      '${file.path} has several Firebase projects (${projects.join(', ')}), '
      'since flavors of the app may have projects of their own. A run of this '
      'script enables the methods in one project, so run it once for each:\n'
      '${commands.join('\n')}',
    );
  }
  final project = projects.single;
  if (!_projectId.hasMatch(project)) {
    throw _Stop(
      '${file.path} has "$project" as its Firebase project, which is no id '
      'of a project. Configure a flavor again with "$_configure" (see '
      'README.md), $orName',
    );
  }
  return project;
}

/// A version as `firebase --version` prints it on a line of its own: three
/// numbers, then a pre-release after `-` and a build after `+`, if any.
final _version = RegExp(r'^(\d+)\.(\d+)\.(\d+)(-[^+\s]+)?(\+\S+)?$');

/// The version of the Firebase CLI in [printed], what `firebase --version`
/// printed, if it comes before [_firstCli], or `null` if it does not.
///
/// The version is the last line that is one, since the Firebase CLI may
/// print more. A pre-release of [_firstCli] comes before it: it may lack
/// what the version has. A version that the script cannot read is none
/// before it: the Firebase CLI then tells itself what it cannot do.
String? _olderCli(String printed) {
  final version = [
    for (final line in printed.split('\n')) ?_version.firstMatch(line.trim()),
  ].lastOrNull;
  if (version == null) return null;
  final first = _firstCli.split('.').map(int.parse).toList();
  for (final (index, number) in first.indexed) {
    final found = int.tryParse(version[index + 1]!);
    if (found == null || found > number) return null;
    if (found < number) return version[0];
  }
  return version[4] == null ? null : version[0];
}{{#setup}}

/// The configurations of the platforms that `flutterfire configure` wrote
/// into `firebase.json` of [app], under `flutter`, or `null` when the file
/// is missing or is not JSON.
Object? _flutterfireOf(Directory app) {
  final file = File('${app.path}/firebase.json');
  if (!file.existsSync()) return null;
  try {
    return switch (jsonDecode(_textOf(file))) {
      {'flutter': final Object? flutter} => flutter,
      _ => null,
    };
  } on FormatException {
    return null;
  }
}

/// A Firebase app of the app, as `flutterfire configure` wrote it into
/// `firebase.json`: its platform, `android` or `ios`, its id, and the path
/// of its Firebase file in the app.
typedef _App = ({String platform, String id, String file});

/// The Firebase apps of [app] in [project], each once, as `firebase.json`
/// of the app names them: for each platform, the app of the platform, and
/// those of the build types of Android and of the build configurations and
/// the targets of iOS, if it has them.
List<_App> _appsOf(Directory app, String project) {
  final apps = <_App>{};
  void collect(String platform, Object? node) {
    if (node is! Map) return;
    if (node case {
      'projectId': final String id,
      'appId': final String appId,
      'fileOutput': final String file,
    } when id == project) {
      apps.add((platform: platform, id: appId, file: file));
    }
    for (final value in node.values) {
      collect(platform, value);
    }
  }

  if (_flutterfireOf(app) case {'platforms': final Map<Object?, Object?> of}) {
    for (final platform in const ['android', 'ios']) {
      collect(platform, of[platform]);
    }
  }
  return apps.toList();
}

/// Sets up in its Firebase project what the ways to sign in of [app] need,
/// [needs], for [apps], the Firebase apps of the app in that project.
/// [waitForClients] tells that this run enabled Google, whose clients may
/// come to the Firebase files a moment later.
///
/// Throws a [_Failed] when a step fails.
Future<void> _setUp(
  Directory app,
  _Cli cli,
  Set<_Need> needs,
  List<_App> apps, {
  required bool waitForClients,
}) async {
  if (apps.isEmpty) {
    stdout.writeln(
      'firebase.json of the app names no app of the project ${cli.project}, '
      'so this run registers no debug key, downloads no Firebase file and '
      'writes no URL scheme there. To set up a flavor of the app in that '
      'project, run "dart $_configureScript <flavor> '
      '--project=${cli.project}" first, and then this script again.',
    );
    return;
  }
  final android = [
    for (final app in apps)
      if (app.platform == 'android') app,
  ];
  final ios = [
    for (final app in apps)
      if (app.platform == 'ios') app,
  ];
  if (needs.contains(_Need.androidCertificate) && android.isNotEmpty) {
    await _registerDebugKey(cli, {for (final app in android) app.id});
  }
  final files = [
    if (needs.contains(_Need.serverClient)) ...android,
    if (needs.contains(_Need.iosClient)) ...ios,
  ];
  if (files.isEmpty) return;
  final schemes = await _downloadFiles(
    app,
    cli,
    files,
    waitForClients: waitForClients,
  );
  if (schemes != null && schemes.isNotEmpty) _writeUrlSchemes(app, schemes);
}

/// A hash of a certificate as the script compares it: its hexadecimal
/// digits in lower case, without the colons that keytool prints.
String _hashOf(String printed) =>
    printed.replaceAll(':', '').toLowerCase().trim();

/// Registers the SHA-1 and SHA-256 of the debug key of this machine for the
/// Android apps [ids] in the project of [cli], those of each that the
/// project does not have yet, and creates the debug key as the first debug
/// build would when there is none.
Future<void> _registerDebugKey(_Cli cli, Set<String> ids) async {
  final keystore = _debugKeystore();
  stdout.writeln(
    'Registering the SHA-1 and SHA-256 of the Android debug key of this '
    'machine, ${keystore.path}, for the Android app ${_listed([...ids])}.',
  );
  final keytool = await _keytool(cli) ??
      (throw _Failed(
        'keytool, which reads the debug key, was not found on the PATH, in '
        'JAVA_HOME or in Android Studio at ${_androidStudioKeytool()}. '
        'Install a JDK or Android Studio, or put keytool on the PATH, and '
        'run this script again.',
      ));
  final inShell = keytool == 'keytool';
  if (!keystore.existsSync()) {
    stdout.writeln(
      'There is no debug key yet, so this script creates it, as the first '
      'debug build would.',
    );
    keystore.parent.createSync(recursive: true);
    // As the Android Gradle plugin creates the debug key (KeystoreHelper of
    // the plugin 9): an RSA key of 2048 bits for 30 years in the keystore
    // of the default type of the JDK.
    final (code, _, errors) = await cli.run(
      keytool,
      [
        '-genkeypair',
        '-keystore',
        keystore.path,
        '-storepass',
        'android',
        '-alias',
        'androiddebugkey',
        '-keypass',
        'android',
        '-keyalg',
        'RSA',
        '-keysize',
        '2048',
        '-sigalg',
        'SHA256withRSA',
        '-validity',
        '10950',
        '-dname',
        'CN=Android Debug,O=Android,C=US',
      ],
      inShell: inShell,
    );
    if (code != 0) {
      throw _Failed(
        'keytool did not create the debug key ${keystore.path} (exit code '
        '$code)${errors.isEmpty ? '' : ': $errors'}',
      );
    }
  }
  final (code, printed, errors) = await cli.run(
    keytool,
    [
      '-list',
      '-v',
      '-keystore',
      keystore.path,
      '-alias',
      'androiddebugkey',
      '-storepass',
      'android',
    ],
    inShell: inShell,
  );
  final hashes = [
    for (final name in const ['SHA1', 'SHA256'])
      RegExp('^\\s*$name:\\s*([0-9A-Fa-f]{2}(?::[0-9A-Fa-f]{2})+)\\s*\$',
              multiLine: true)
          .firstMatch(printed)?[1],
  ];
  if (code != 0 || hashes.contains(null)) {
    throw _Failed(
      'keytool did not read the SHA-1 and SHA-256 of the debug key '
      '${keystore.path} (exit code $code)'
      '${errors.isEmpty ? '' : ': $errors'}',
    );
  }
  stdout.writeln(
    'The SHA-1 of the key is ${hashes[0]}, and its SHA-256 is ${hashes[1]}.',
  );
  for (final id in ids) {
    final listed = await cli.json(
      ['apps:android:sha:list', id],
      'list the SHA certificate hashes of the Android app $id',
    );
    final known = {
      if (listed is List)
        for (final certificate in listed)
          if (certificate case {'shaHash': final String hash}) _hashOf(hash),
    };
    final missing = [
      for (final hash in hashes.nonNulls)
        if (!known.contains(_hashOf(hash))) hash,
    ];
    for (final hash in missing) {
      // As keytool prints it, with colons, which the API of Firebase takes,
      // as a check against a real project showed.
      await cli.json(
        ['apps:android:sha:create', id, hash],
        'register $hash for the Android app $id',
      );
    }
    stdout.writeln(
      missing.isEmpty
          ? 'The Android app $id has them already.'
          : 'Registered them for the Android app $id.',
    );
  }
}

/// The debug key of Android of this machine, where the Android Gradle
/// plugin keeps it and creates it for the first debug build:
/// `debug.keystore` in the directory of the preferences of the Android
/// tools (`AbstractAndroidLocations` of the plugin 9). That is the
/// directory that ANDROID_USER_HOME names, or `.android` in the one that
/// ANDROID_PREFS_ROOT or ANDROID_SDK_HOME name, which are deprecated, or
/// else `.android` in the first directory that exists of TEST_TMPDIR,
/// XDG_CONFIG_HOME and the home directory.
File _debugKeystore() {
  final environment = Platform.environment;
  final separator = Platform.pathSeparator;
  String? named(String variable) => switch (environment[variable]) {
        final value? when value.isNotEmpty => value,
        _ => null,
      };
  String? dotAndroidIn(List<String?> directories) => [
        for (final directory in directories.nonNulls)
          if (Directory(directory).existsSync()) '$directory$separator.android',
      ].firstOrNull;
  final preferences = named('ANDROID_USER_HOME') ??
      dotAndroidIn([named('ANDROID_PREFS_ROOT'), named('ANDROID_SDK_HOME')]) ??
      dotAndroidIn([
        named('TEST_TMPDIR'),
        named('XDG_CONFIG_HOME'),
        named(Platform.isWindows ? 'USERPROFILE' : 'HOME'),
      ]);
  if (preferences == null) {
    throw const _Failed(
      'Cannot tell where the Android Gradle plugin keeps the debug key of '
      'this machine: no directory of ANDROID_USER_HOME and of the home '
      'directory exists.',
    );
  }
  return File('$preferences${separator}debug.keystore');
}

/// Where Android Studio has keytool, in the JDK that Flutter builds with
/// when JAVA_HOME is not set, at the default place of Android Studio on
/// this system.
String _androidStudioKeytool() {
  if (Platform.isMacOS) {
    return '/Applications/Android Studio.app/Contents/jbr/Contents/Home/bin/'
        'keytool';
  }
  if (Platform.isWindows) {
    final programs = Platform.environment['ProgramFiles'] ?? r'C:\Program Files';
    return '$programs\\Android\\Android Studio\\jbr\\bin\\keytool.exe';
  }
  return '/opt/android-studio/jbr/bin/keytool';
}

/// The keytool of a JDK of this machine that runs: the one on the PATH, the
/// one in JAVA_HOME or the one of Android Studio, or `null` if none runs.
/// A keytool that does not run, such as the one of macOS on a machine
/// without a JDK that macOS knows, is passed over.
Future<String?> _keytool(_Cli cli) async {
  final javaHome = Platform.environment['JAVA_HOME'] ?? '';
  final separator = Platform.pathSeparator;
  for (final keytool in [
    'keytool',
    if (javaHome.isNotEmpty)
      [javaHome, 'bin', Platform.isWindows ? 'keytool.exe' : 'keytool']
          .join(separator),
    _androidStudioKeytool(),
  ]) {
    final onPath = keytool == 'keytool';
    if (!onPath && !File(keytool).existsSync()) continue;
    try {
      final (code, _, _) = await cli.run(keytool, ['-help'], inShell: onPath);
      if (code == 0) return keytool;
    } on ProcessException {
      continue;
    }
  }
  return null;
}

/// Downloads the Firebase files of [files], apps of [app], from the project
/// of [cli], and writes those that have the clients of Google to their
/// paths in the app. Returns the URL schemes that the iOS files among them
/// have, or `null` when a file lacks the clients, which the script then
/// tells.
///
/// When [waitForClients], Google was enabled a moment ago, so the script
/// downloads a file without the clients again, three times at most, five
/// seconds apart, and fails when it still lacks them.
Future<List<String>?> _downloadFiles(
  Directory app,
  _Cli cli,
  List<_App> files, {
  required bool waitForClients,
}) async {
  stdout.writeln(
    'Downloading the Firebase files of the app again, with the clients of '
    'Google: ${_listed([for (final file in files) file.file])}.',
  );
  final contents = <_App, String>{};
  for (var attempt = 1;; attempt++) {
    for (final file in files) {
      if (contents[file] case final text? when _clientsOf(file, text) != null) {
        continue;
      }
      final result = await cli.json(
        ['apps:sdkconfig', file.platform.toUpperCase(), file.id],
        'download the Firebase file of the app ${file.id}',
      );
      contents[file] = switch (result) {
        {'fileContents': final String text} => text,
        _ => throw _Failed(
            'The Firebase CLI gave no Firebase file of the app ${file.id}.',
          ),
      };
    }
    final lacking = [
      for (final file in files)
        if (_clientsOf(file, contents[file]!) == null) file,
    ];
    if (lacking.isEmpty || !waitForClients || attempt > 3) {
      final written = <String>[];
      for (final file in files) {
        if (lacking.contains(file)) continue;
        if (_write(app, file.file, contents[file]!)) written.add(file.file);
      }
      stdout.writeln(
        written.isEmpty
            ? 'The files of the app are as Firebase has them already.'
            : 'Wrote ${_listed(written)}.',
      );
      if (lacking.isEmpty) {
        return [
          for (final file in files)
            if (file.platform == 'ios') ...?_clientsOf(file, contents[file]!),
        ];
      }
      final names = _listed([for (final file in lacking) file.file]);
      if (waitForClients) {
        throw _Failed(
          'Firebase has not added the clients of Google yet, so this script '
          'has not written $names.',
        );
      }
      stdout.writeln(
        'Firebase has no clients of Google, as in a project in which Google '
        'is not enabled, so this script has not written $names, and writes '
        'no URL scheme. Enable Google, and run this script again.',
      );
      return null;
    }
    await Future<void>.delayed(const Duration(seconds: 5));
  }
}

/// The URL schemes of the clients of Google in [text], the Firebase file of
/// [file], or `null` if it lacks a client that the app needs: for an iOS
/// app, `REVERSED_CLIENT_ID`, its client of Google reversed, and for an
/// Android app none, with the client of the server, an OAuth client of the
/// type 3.
List<String>? _clientsOf(_App file, String text) {
  if (file.platform == 'ios') {
    final scheme = RegExp(
      r'<key>REVERSED_CLIENT_ID</key>\s*<string>([A-Za-z0-9.-]+)</string>',
    ).firstMatch(text)?[1];
    return scheme == null ? null : [scheme];
  }
  bool hasServer(Object? node) => switch (node) {
        {'client_type': 3} => true,
        Map() => node.values.any(hasServer),
        List() => node.any(hasServer),
        _ => false,
      };
  try {
    return hasServer(jsonDecode(text)) ? const [] : null;
  } on FormatException {
    return null;
  }
}

/// Writes [text] to [path] of [app], unless the file has it already, and
/// returns whether it wrote it.
///
/// Throws a [_Failed] when [path] is outside the app, and when the file
/// cannot be read or written.
bool _write(Directory app, String path, String text) {
  final segments = path.split(RegExp(r'[/\\]'));
  if (path.isEmpty ||
      path.startsWith('/') ||
      path.startsWith(r'\') ||
      path.contains(':') ||
      segments.contains('..')) {
    throw _Failed(
      'firebase.json of the app names "$path" as a Firebase file of the app, '
      'which is outside the app.',
    );
  }
  final file = File('${app.path}/$path');
  try {
    if (file.existsSync() && file.readAsStringSync() == text) return false;
    file
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
  } on FileSystemException catch (error) {
    throw _Failed('$path could not be written (${error.message}).');
  }
  return true;
}

/// Writes [schemes] into the URL schemes of [_infoPlist] of [app], those
/// that it does not have, as a URL type of their own, and leaves the file
/// as it is when it has them all.
///
/// Throws a [_Failed] with what to add by hand when the file is not in a
/// form that the script knows, and when it cannot be read or written.
void _writeUrlSchemes(Directory app, List<String> schemes) {
  final file = File('${app.path}/$_infoPlist');
  if (!file.existsSync()) {
    throw _Failed(
      '$_infoPlist is missing, so this script cannot write the URL scheme '
      'of Google, ${_listed(schemes)}, into it.',
    );
  }
  final String text;
  try {
    text = file.readAsStringSync();
  } on FileSystemException catch (error) {
    throw _Failed('$_infoPlist could not be read (${error.message}).');
  }
  final missing = [
    for (final scheme in {...schemes})
      if (!text.contains('<string>$scheme</string>')) scheme,
  ];
  if (missing.isEmpty) {
    stdout.writeln('$_infoPlist has the URL scheme of Google already.');
    return;
  }
  stdout.writeln(
    'Writing the URL scheme of Google, ${_listed(missing)}, into '
    '$_infoPlist.',
  );
  final changed = _withUrlSchemes(text, missing);
  final newline = text.contains('\r\n') ? '\r\n' : '\n';
  if (changed == null) {
    throw _Failed(
      '$_infoPlist is not in a form in which this script can add the URL '
      'scheme. Add this to CFBundleURLTypes there by hand:\n'
      '${_urlTypesOf(missing, '', newline).trimRight()}',
    );
  }
  try {
    file.writeAsStringSync(changed);
  } on FileSystemException catch (error) {
    throw _Failed(
      '$_infoPlist could not be written (${error.message}). Add this to '
      'CFBundleURLTypes there by hand:\n'
      '${_urlTypesOf(missing, '', newline).trimRight()}',
    );
  }
}

/// The URL types of [schemes] as the items of `CFBundleURLTypes`, each line
/// after [indent], one tab further in for each level, and ending with
/// [newline].
String _urlTypesOf(List<String> schemes, String indent, String newline) => [
      for (final scheme in schemes) ...[
        '$indent<dict>',
        '$indent\t<key>CFBundleTypeRole</key>',
        '$indent\t<string>Editor</string>',
        '$indent\t<key>CFBundleURLSchemes</key>',
        '$indent\t<array>',
        '$indent\t\t<string>$scheme</string>',
        '$indent\t</array>',
        '$indent</dict>',
      ],
    ].map((line) => '$line$newline').join();

/// [text], an Info.plist in XML, with the URL types of [schemes] added: at
/// the end of `CFBundleURLTypes`, or in a `CFBundleURLTypes` of their own
/// at the end of the dictionary of the file. Returns `null` when [text] is
/// not in a form that the script knows.
String? _withUrlSchemes(String text, List<String> schemes) {
  final newline = text.contains('\r\n') ? '\r\n' : '\n';
  // The start of the line of the tag at [index], when only spaces and tabs
  // come before it there.
  int? lineOf(int index) {
    final start = text.lastIndexOf('\n', index - 1) + 1;
    return text.substring(start, index).trim().isEmpty ? start : null;
  }

  String insert(int at, String lines) =>
      '${text.substring(0, at)}$lines${text.substring(at)}';
  final key = RegExp(r'<key>CFBundleURLTypes</key>\s*');
  final keys = key.allMatches(text).toList();
  if (keys.length > 1) return null;
  if (keys case [final found]) {
    if (text.startsWith('<array/>', found.end)) {
      final line = lineOf(found.start);
      if (line == null) return null;
      final indent = text.substring(line, found.start);
      return text.replaceRange(
        found.end,
        found.end + '<array/>'.length,
        '<array>$newline${_urlTypesOf(schemes, '$indent\t', newline)}'
        '$indent</array>',
      );
    }
    if (!text.startsWith('<array>', found.end)) return null;
    // The end of that array, after the arrays within it.
    var depth = 0;
    for (final tag in RegExp(r'<(/?)array>').allMatches(text, found.end)) {
      depth += tag[1]!.isEmpty ? 1 : -1;
      if (depth > 0) continue;
      final line = lineOf(tag.start);
      if (line == null) return null;
      final indent = text.substring(line, tag.start);
      return insert(line, _urlTypesOf(schemes, '$indent\t', newline));
    }
    return null;
  }
  // The dictionary of the file ends with its last `</dict>`, right before
  // `</plist>`.
  final end = RegExp(r'</dict>\s*</plist>\s*$').firstMatch(text);
  final line = end == null ? null : lineOf(end.start);
  if (end == null || line == null) return null;
  final indent = '${text.substring(line, end.start)}\t';
  return insert(
    line,
    '$indent<key>CFBundleURLTypes</key>$newline'
    '$indent<array>$newline'
    '${_urlTypesOf(schemes, '$indent\t', newline)}'
    '$indent</array>$newline',
  );
}{{/setup}}
