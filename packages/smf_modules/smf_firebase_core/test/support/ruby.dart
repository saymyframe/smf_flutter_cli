/// The Ruby of the machine and its gem xcodeproj, with which
/// `flutterfire configure` changes the Xcode project of the app on macOS,
/// for the tests that run them.
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';

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

/// Opens the Xcode project in [app] with the gem xcodeproj of [ruby] and
/// saves it, as `flutterfire configure` does when it changes the project;
/// throws a [StateError] with the errors of Ruby if it fails.
void saveXcodeProject(String ruby, String app) {
  final result = Process.runSync(
    ruby,
    [
      '-e',
      "require 'xcodeproj'; Xcodeproj::Project.open(ARGV[0]).save",
      _xcodeProject,
    ],
    workingDirectory: app,
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  if (result.exitCode != 0) {
    throw StateError('Ruby exited with ${result.exitCode}: ${result.stderr}');
  }
}
