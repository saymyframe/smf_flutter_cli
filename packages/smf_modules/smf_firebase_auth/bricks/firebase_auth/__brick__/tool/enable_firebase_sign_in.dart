// Enables the sign-in methods of the app in its Firebase project:
// Email/Password, and Anonymous when the app is in the mode `anonymous`,
// which the script reads from `authMode` of the app.
//
//     dart tool/enable_firebase_sign_in.dart
//
// The project is the one that `flutterfire configure` wrote into
// `firebase.json` of the app. For another one, add `--project <id>`.
//
// The script enables the methods with `firebase deploy --only auth` of the
// Firebase CLI, which enables what its configuration names and disables
// nothing. It gives the Firebase CLI a configuration of its own in a
// temporary directory, so `firebase.json` of the app stays as it is, and a
// `firebase deploy` of the app does not touch the sign-in methods.
//
// The Firebase CLI adds a web app named "Default Web App" to a project that
// has no web app, because it enables the methods through one
// (https://github.com/firebase/firebase-tools/issues/11250). The Firebase
// console enables them without it, under Authentication > Sign-in method.
//
// Every argument goes to the Firebase CLI as it is. The Firebase CLI runs in
// the temporary directory, where an account that `firebase login:use` chose
// for the directory of the app does not apply: add `--account <email>` to
// run it as another account than the default one.

import 'dart:convert';
import 'dart:io';

/// The first version of the Firebase CLI that has `deploy --only auth`.
const _firstCli = '{{{minimum_firebase_cli}}}';

/// The file of the app with `authMode`, the sign-in mode of the app.
const _sessionFile = '{{{session_file}}}';

/// This script, as the user runs it in the directory of the app.
const _command = 'dart tool/enable_firebase_sign_in.dart';

Future<void> main(List<String> arguments) async {
  // The app is the directory above `tool`, wherever the script is run from.
  final app = File.fromUri(Platform.script).parent.parent;
  try {
    exitCode = await _enable(app, arguments);
  } on _Stop catch (stop) {
    stderr.writeln(stop.why);
    exitCode = 1;
  }
}

/// Enables the sign-in methods that [app] needs in its Firebase project, or
/// in the one that [arguments] name, and returns the exit code of the
/// Firebase CLI.
///
/// Throws a [_Stop] when it cannot tell the methods or the project, and
/// when the Firebase CLI of the machine cannot enable them.
Future<int> _enable(Directory app, List<String> arguments) async {
  final mode = _modeOf(app);
  final anonymous = mode == 'anonymous';
  final named = _projectIn(arguments);
  final project = named ?? _configuredProject(app);
  await _checkCli(project);

  final directory = Directory.systemTemp.createTempSync('firebase_sign_in_');
  try {
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
    final firebase = await Process.start(
      'firebase',
      [
        'deploy',
        '--only',
        'auth',
        if (named == null) ...['--project', project],
        '--non-interactive',
        ...arguments,
      ],
      workingDirectory: directory.path,
      mode: ProcessStartMode.inheritStdio,
      // On Windows, npm installs the Firebase CLI as `firebase.cmd`.
      runInShell: Platform.isWindows,
    );
    final code = await firebase.exitCode;
    if (code != 0) {
      stderr.writeln(
        'The Firebase CLI did not enable the sign-in methods (exit code '
        '$code). It ran as the default account of "firebase login:list": an '
        'account that "firebase login:use" chose for the directory of the '
        'app does not apply in the temporary directory in which this script '
        'runs the Firebase CLI. For another account, run: $_command '
        '--account <email>\n'
        '${_inConsole(project)}',
      );
    }
    return code;
  } finally {
    directory.deleteSync(recursive: true);
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
    'Sign-in method: https://console.firebase.google.com/project/'
    '${_projectId.hasMatch(project) ? project : '_'}/authentication/providers';

/// The sign-in mode of [app], such as `required`, as `authMode` in
/// [_sessionFile] has it.
///
/// That file imports Flutter, so this script cannot import it, and reads
/// the line of the constant instead.
String _modeOf(Directory app) {
  final file = File('${app.path}/$_sessionFile');
  final modes = [
    if (file.existsSync())
      ...RegExp(
        r'^\s*(?:const|final)\s+(?:AuthMode\s+)?authMode\s*=\s*'
        r'AuthMode\.(\w+)\s*;',
        multiLine: true,
      ).allMatches(file.readAsStringSync()).map((match) => match[1]!),
  ];
  if (modes.length != 1) {
    throw _Stop(
      'Cannot tell the sign-in mode of the app, by which this script enables '
      'Anonymous or leaves it out: $_sessionFile does not have one line '
      'such as "const AuthMode authMode = AuthMode.required;".\n'
      '${_inConsole()}',
    );
  }
  return modes.single;
}

/// The project that [arguments] name for the Firebase CLI, with `--project`
/// or `-P`, or `null` if they name none.
String? _projectIn(List<String> arguments) {
  for (final (index, argument) in arguments.indexed) {
    if (argument == '--project' || argument == '-P') {
      return index + 1 < arguments.length ? arguments[index + 1] : '';
    }
    if (argument.startsWith('--project=')) {
      return argument.substring('--project='.length);
    }
    if (argument.startsWith('-P')) return argument.substring(2);
  }
  return null;
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
    json = jsonDecode(file.readAsStringSync());
  } on FormatException catch (error) {
    throw _Stop(
      '${file.path} is not JSON (${error.message}). Run "flutterfire '
      'configure" again (see README.md), $orName',
    );
  }
  final projects = <String>{};
  void collect(Object? node) {
    if (node is List) node.forEach(collect);
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

/// Stops unless the Firebase CLI of the machine runs and is [_firstCli] or
/// later. A version that the script cannot read passes: the Firebase CLI
/// then tells what it cannot do.
Future<void> _checkCli(String project) async {
  String notRunning(String why) =>
      'The Firebase CLI did not run ($why). Install it, or put it on the '
      'PATH: https://firebase.google.com/docs/cli\n${_inConsole(project)}';
  final ProcessResult result;
  try {
    result = await Process.run('firebase', const [
      '--version',
    ], runInShell: Platform.isWindows);
  } on ProcessException catch (error) {
    throw _Stop(notRunning(error.message));
  }
  if (result.exitCode != 0) {
    final said = '${result.stderr}'.trim();
    throw _Stop(
      notRunning(
        'exit code ${result.exitCode}${said.isEmpty ? '' : ': $said'}',
      ),
    );
  }
  // The last line that is a version: the Firebase CLI may print more.
  final version = RegExp(
    r'^(\d{1,9})\.(\d{1,9})\.(\d{1,9})(?:[-+]\S*)?\s*$',
    multiLine: true,
  ).allMatches('${result.stdout}').lastOrNull;
  if (version == null) return;
  final first = _firstCli.split('.').map(int.parse).toList();
  for (final (index, number) in first.indexed) {
    final found = int.parse(version[index + 1]!);
    if (found > number) return;
    if (found < number) {
      throw _Stop(
        'The Firebase CLI of this machine is ${version[0]!.trim()}, and '
        'enabling sign-in methods needs $_firstCli or later. Update it with "npm '
        'install -g firebase-tools" if npm installed it, or see '
        'https://firebase.google.com/docs/cli#update-cli.\n'
        '${_inConsole(project)}',
      );
    }
  }
}
