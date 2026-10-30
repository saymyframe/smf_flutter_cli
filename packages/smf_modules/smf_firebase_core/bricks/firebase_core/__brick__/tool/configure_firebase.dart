// Configures Firebase for one flavor of the app, with the FlutterFire CLI:
//
//     dart tool/configure_firebase.dart <flavor> --project=<id>
//
// In a terminal, without --project, flutterfire asks for the project. The
// other arguments go to flutterfire as they are, such as --account=<email>.
//
// flutterfire writes one iOS build configuration in a run, and the build of
// each needs its entry in firebase.json, so on macOS this script runs it once
// for each. Run it again at any time: it changes nothing but the ids of two
// build phases, or moves the flavor to another project.
//
// Then it formats the options that flutterfire wrote, and runs each Dart file
// of tool/firebase_configured by the order of their names, for what has to
// follow every run of flutterfire.

import 'dart:convert';
import 'dart:io';

/// The Android application id and the iOS bundle id of a flavor, each `null`
/// for a platform that the app does not have, and its Xcode build
/// configurations.
typedef _Flavor = ({String? android, String? ios, List<String> configurations});

/// The flavors of the app. SMF wrote their ids from the ids of the app: if you
/// change them in the Android and Xcode projects, change them here too.
const Map<String, _Flavor> _flavors = {{{flavor_ids}}};

/// The platforms of the app.
const _platforms = '{{{platforms}}}';

/// The directory of what has to follow every run of flutterfire.
const _hooks = '{{{hooks_directory}}}';

/// What flutterfire_cli 1.4.1 takes with `--android-package-name`, as
/// `validateAndroidPackageName` of its `lib/src/common/utils.dart` checks it.
final _packageName =
    RegExp(r'^[a-zA-Z][a-zA-Z0-9]*(\.[a-zA-Z_][a-zA-Z0-9_]*)+$');

/// What flutterfire_cli 1.4.1 takes with `--ios-bundle-id`, as
/// `validateAppBundleId` of the same file checks it.
final _bundleId = RegExp(
  r'^([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?|([a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?(\.[a-zA-Z0-9]([a-zA-Z0-9\-]{0,61}[a-zA-Z0-9])?)+))$',
);

Future<void> main(List<String> arguments) async {
  final script = File.fromUri(Platform.script).resolveSymbolicLinksSync();
  try {
    exitCode = await _configure(File(script).parent.parent, arguments);
  } on _Stop catch (stop) {
    stderr.writeln(stop.why);
    exitCode = 1;
  }
}

/// Why the script stops before flutterfire.
final class _Stop implements Exception {
  const _Stop(this.why);

  final String why;
}

/// Configures the flavor that [arguments] names in [app], and returns the exit
/// code of the script.
Future<int> _configure(Directory app, List<String> arguments) async {
  final flavor = arguments.isEmpty ? null : arguments.first;
  final ofFlavor = _flavors[flavor];
  if (flavor == null || ofFlavor == null) {
    throw _Stop(
      'Name a flavor: dart tool/configure_firebase.dart '
      '<${_flavors.keys.join('|')}> --project=<id>',
    );
  }
  final (named, rest) = _withoutProject(arguments.sublist(1));
  var project = named;
  final terminal = stdin.hasTerminal;
  if (project == null && !terminal) {
    throw _Stop(
      'Name the Firebase project: dart tool/configure_firebase.dart $flavor '
      '--project=<id>. Without a terminal, nobody can answer the question of '
      'flutterfire.',
    );
  }
  final platforms = _platformsIn(rest);
  final android = platforms.contains('android') ? ofFlavor.android : null;
  final ios = platforms.contains('ios') ? ofFlavor.ios : null;
  _checkIds(android, ios);

  // flutterfire changes the Xcode project only on macOS, so the runs differ
  // only there.
  final configurations = Platform.isMacOS && ios != null
      ? ofFlavor.configurations
      : ofFlavor.configurations.take(1);
  for (final configuration in configurations) {
    final process = await Process.start(
      Platform.resolvedExecutable,
      [
        'pub',
        'global',
        'run',
        'flutterfire_cli:flutterfire',
        'configure',
        if (project != null) '--project=$project',
        '--platforms=$_platforms',
        '--overwrite-firebase-options',
        '--out=lib/firebase_options_$flavor.dart',
        if (android != null) ...[
          '--android-package-name=$android',
          '--android-out=android/app/src/$flavor/google-services.json',
        ],
        if (ios != null) ...[
          '--ios-bundle-id=$ios',
          '--ios-out=ios/flavors/$flavor/GoogleService-Info.plist',
          '--ios-build-config=$configuration',
        ],
        ...rest,
      ],
      workingDirectory: app.path,
      // Without a terminal, flutterfire fails rather than wait for an answer.
      environment: terminal ? null : const {'CI': 'true'},
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await process.exitCode;
    if (code != 0) {
      stderr.writeln(
        'flutterfire failed for the flavor $flavor (exit code $code). What it '
        'wrote stays, and running this script again does the rest. It needs '
        'the FlutterFire CLI, a login of the Firebase CLI and, on macOS, the '
        'Ruby gem xcodeproj: see the section Firebase of README.md.',
      );
      return code;
    }
    // The next runs need no answer.
    project ??= _projectOf(app, flavor);
  }

  await _format(app, flavor);
  for (final hook in _hooksOf(app)) {
    final process = await Process.start(
      Platform.resolvedExecutable,
      [hook.path],
      workingDirectory: app.path,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await process.exitCode;
    if (code != 0) {
      stderr.writeln(
        '${hook.path} failed (exit code $code). flutterfire configured the '
        'flavor $flavor, and running this script again runs it again.',
      );
      return code;
    }
  }
  stdout.writeln(
    'Configured the flavor $flavor for the Firebase project $project. Commit '
    'firebase.json and the files it names.',
  );
  return 0;
}

/// The project that [arguments] name, as flutterfire reads it, with the last
/// one counting, and the other arguments.
(String?, List<String>) _withoutProject(List<String> arguments) {
  String? project;
  final rest = <String>[];
  for (var index = 0; index < arguments.length; index++) {
    final argument = arguments[index];
    if (argument == '--project' || argument == '-p') {
      if (++index == arguments.length) {
        throw _Stop('$argument needs the id of a Firebase project.');
      }
      project = arguments[index];
    } else if (argument.startsWith('--project=')) {
      project = argument.substring('--project='.length);
    } else if (argument.startsWith('-p')) {
      project = argument.substring('-p'.length);
    } else {
      rest.add(argument);
    }
  }
  if (project != null && project.isEmpty) {
    throw _Stop('--project needs the id of a Firebase project.');
  }
  return (project, rest);
}

/// The platforms of this run: those of the app, unless [rest] names others.
/// [rest] comes last on the command line of flutterfire, which takes the last
/// value of an option.
List<String> _platformsIn(List<String> rest) {
  var platforms = _platforms;
  for (var index = 0; index < rest.length; index++) {
    if (rest[index].startsWith('--platforms=')) {
      platforms = rest[index].substring('--platforms='.length);
    } else if (rest[index] == '--platforms' && index + 1 < rest.length) {
      platforms = rest[index + 1];
    }
  }
  return platforms.split(',');
}

/// Stops at an id that flutterfire would refuse, with what to do about it.
void _checkIds(String? android, String? ios) {
  if (android != null && !_packageName.hasMatch(android)) {
    throw _Stop(
      'flutterfire takes no application id like $android (it allows no '
      'underscore in its first part): use another org.',
    );
  }
  if (ios != null && !_bundleId.hasMatch(ios)) {
    throw _Stop(
      'flutterfire takes no bundle id like $ios (it allows no hyphen at either '
      'end of a part, and at most 63 characters in one): use another org.',
    );
  }
}

/// The project of the options of [flavor], which flutterfire wrote into
/// `firebase.json` of [app].
///
/// It reads the entry of the options: the keys of the Android apps in that
/// file depend on the path of the app.
String _projectOf(Directory app, String flavor) {
  final file = File('${app.path}/firebase.json');
  final json = file.existsSync() ? jsonDecode(file.readAsStringSync()) : null;
  Object? entry = json;
  for (final key in [
    'flutter',
    'platforms',
    'dart',
    'lib/firebase_options_$flavor.dart',
    'projectId',
  ]) {
    entry = entry is Map ? entry[key] : null;
  }
  if (entry is! String) {
    throw _Stop(
      '${file.path} names no Firebase project for the flavor $flavor, though '
      'flutterfire succeeded. Run this script again with --project=<id>.',
    );
  }
  return entry;
}

/// Formats the options of [flavor], which flutterfire writes in a format of
/// its own, so that the check of the format of the app passes. They work
/// without it, so a failure only warns.
Future<void> _format(Directory app, String flavor) async {
  final options = 'lib/firebase_options_$flavor.dart';
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['format', options],
    workingDirectory: app.path,
  );
  if (result.exitCode != 0) {
    stderr.writeln(
      'Warning: dart format left $options as flutterfire wrote it (exit code '
      '${result.exitCode}): ${result.stderr}',
    );
  }
}

/// The Dart files of the hooks directory of [app], by the order of their
/// names. An app whose modules have nothing to do after flutterfire has no
/// such directory.
List<File> _hooksOf(Directory app) {
  final directory = Directory('${app.path}/$_hooks');
  if (!directory.existsSync()) return const [];
  return [
    for (final entity in directory.listSync())
      if (entity is File && entity.path.endsWith('.dart')) entity,
  ]..sort((a, b) => a.path.compareTo(b.path));
}
