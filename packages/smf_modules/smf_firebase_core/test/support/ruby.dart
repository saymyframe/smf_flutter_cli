/// The Ruby of the machine and its gem xcodeproj, with which
/// `flutterfire configure` changes the Xcode project of the app on macOS,
/// for the tests that run them.
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';

import 'flutterfire.dart';

/// The Ruby on the `PATH`, or `null` without one, or without `which` to find
/// it.
String? rubyOnPath() {
  final ProcessResult result;
  try {
    result = Process.runSync('which', ['ruby']);
  } on ProcessException {
    return null;
  }
  final path = result.stdout.toString().trim();
  return result.exitCode == 0 && path.isNotEmpty ? path : null;
}

/// The Rubies that a user of this machine may run a command of SMF with:
/// the one on the `PATH` and, on macOS, the Ruby of macOS in `/usr/bin`,
/// which is the one on the `PATH` unless another Ruby is installed.
List<String> rubiesOfMachine() => {
      if (rubyOnPath() case final ruby?) ruby,
      if (Platform.isMacOS && File('/usr/bin/ruby').existsSync())
        '/usr/bin/ruby',
    }.toList();

/// The version of the gem xcodeproj that [ruby] loads, or `null` if it
/// loads none.
String? xcodeprojVersion(String ruby) {
  final result = Process.runSync(
    ruby,
    ['-e', "require 'xcodeproj'; print Xcodeproj::VERSION"],
  );
  final version = '${result.stdout}'.trim();
  return result.exitCode == 0 && version.isNotEmpty ? version : null;
}

/// The Xcode project of the app, relative to the app.
final String _xcodeProject = File(AppEntryRole.xcodeProjectFile).parent.path;

/// Runs [program] with [ruby] in [app], with [arguments] and the variables
/// of [environment]; returns what it prints, or throws a [StateError] with
/// its errors if it fails.
String _runRuby(
  String ruby,
  String app,
  String program,
  List<String> arguments, {
  Map<String, String> environment = const {},
}) {
  final result = Process.runSync(
    ruby,
    ['-e', program, ...arguments],
    workingDirectory: app,
    environment: environment,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError('Ruby exited with ${result.exitCode}: ${result.stderr}');
  }
  return '${result.stdout}';
}

/// Adds the build phase for Crashlytics of flutterfire_cli [version] to the
/// target Runner of the Xcode project in [app], with the gem xcodeproj of
/// [ruby], as the program of `addFlutterFireDebugSymbolsScript` in
/// `lib/src/firebase/firebase_apple_writes.dart` of flutterfire_cli does in
/// an app without the phase: it creates a phase of shell scripts with the
/// name of the phase, gives it its script and saves the project. The phase
/// comes last in the target, where flutterfire leaves it in an app without
/// its phase for `GoogleService-Info.plist`.
void addCrashlyticsPhase(String ruby, String app, String version) {
  _runRuby(
    ruby,
    app,
    '''
require 'xcodeproj'
project = Xcodeproj::Project.open(ARGV[0])
target = project.targets.find { |target| target.name == 'Runner' }
phase = target.new_shell_script_build_phase(ARGV[1])
phase.shell_script = ENV.fetch('SMF_TEST_SCRIPT')
project.save
''',
    [_xcodeProject, crashlyticsPhaseName],
    environment: {'SMF_TEST_SCRIPT': crashlyticsPhaseScript(version)},
  );
}

/// The script of the build phase for Crashlytics in the Xcode project of
/// [app], as the gem xcodeproj of [ruby] reads it.
String crashlyticsPhaseScriptIn(String ruby, String app) => _runRuby(
      ruby,
      app,
      '''
require 'xcodeproj'
project = Xcodeproj::Project.open(ARGV[0])
target = project.targets.find { |target| target.name == 'Runner' }
phase = target.shell_script_build_phases.find { |phase| phase.name == ARGV[1] }
print phase.shell_script
''',
      [_xcodeProject, crashlyticsPhaseName],
    );
