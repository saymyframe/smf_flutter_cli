// Enables the sign-in methods of the app in its Firebase project:
// Email/Password, and Anonymous when the app is in the mode `anonymous`,
// which the script reads from `authMode` of the app.
//
//     dart tool/enable_firebase_sign_in.dart
//
// The project is the one that `flutterfire configure` wrote into
// `firebase.json` of the app, or the one that `--project <id>` names. The
// script says which, and gives the Firebase CLI that project and no other.
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
// The Firebase CLI adds a web app named "Default Web App" to a project that
// has no web app, because it enables the methods through one
// (https://github.com/firebase/firebase-tools/issues/11250). The Firebase
// console enables them without it, under Authentication > Sign-in method.
//
// The other arguments go to the Firebase CLI as they are. An account that
// `firebase login:use` chose for the directory of the app does not apply in
// the temporary directory: `--account <email>` names the account.

import 'dart:async';
import 'dart:convert';
import 'dart:io';

/// The first version of the Firebase CLI that has `deploy --only auth`.
const _firstCli = '{{{minimum_firebase_cli}}}';

/// The file of the app with `authMode`, the sign-in mode of the app.
const _sessionFile = '{{{session_file}}}';

/// The mode in which the app signs in anonymous users.
const _anonymous = '{{{anonymous_mode}}}';

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
/// when the Firebase CLI of the machine cannot enable them.
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
      );
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
    }

    File('${directory.path}/firebase.json').writeAsStringSync(
      jsonEncode({
        'auth': {
          'providers': {
            'emailPassword': true,
            if (anonymous) 'anonymous': true,
          },
        },
      }),
    );
    stdout.writeln(
      'Enabling Email/Password${anonymous ? ' and Anonymous' : ''} in the '
      'Firebase project $project (the mode of the app is $mode).',
    );
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
    if (code != 0) stderr.writeln(_afterFailure(code, project, passedOn));
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
}

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
    'PATH: https://firebase.google.com/docs/cli\n${_inConsole(project)}';

/// What the script tells after the Firebase CLI failed with the exit code
/// [code] for [project], with the arguments [passedOn]: which account it
/// may have run as, where its log was, and the other way to enable the
/// methods.
String _afterFailure(int code, String project, List<String> passedOn) {
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
          'name the account, run: $_command --account <email>',
    if (!options.contains('--debug'))
      '- Its log, firebase-debug.log, was in that temporary directory, '
          'which this script removes. To see what the Firebase CLI did, '
          'run: $_command --debug',
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

/// The id of the Firebase project that `flutterfire configure` wrote into
/// `firebase.json` of [app]: under `flutter`, each platform of the app has
/// the id of its project.
String _configuredProject(Directory app) {
  final file = File('${app.path}/firebase.json');
  const orName = 'or name the project: $_command --project <id>';
  if (!file.existsSync()) {
    throw _Stop(
      '${file.path} is missing, so the app is not configured for Firebase '
      'yet. Run "flutterfire configure" first (see README.md), $orName',
    );
  }
  final Object? json;
  try {
    json = jsonDecode(_textOf(file));
  } on FormatException catch (error) {
    throw _Stop(
      '${file.path} is not JSON (${error.message}). Run "flutterfire '
      'configure" again (see README.md), $orName',
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
      '${file.path} has no Firebase project of "flutterfire configure". Run '
      'it first (see README.md), $orName',
    );
  }
  if (projects.length > 1) {
    throw _Stop(
      '${file.path} has several Firebase projects (${projects.join(', ')}). '
      'Name one: $_command --project <id>',
    );
  }
  final project = projects.single;
  if (!_projectId.hasMatch(project)) {
    throw _Stop(
      '${file.path} has "$project" as its Firebase project, which is no id '
      'of a project. Run "flutterfire configure" again (see README.md), '
      '$orName',
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
}
