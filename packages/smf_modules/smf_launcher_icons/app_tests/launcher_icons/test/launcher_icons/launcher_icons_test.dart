// A test that continuous integration runs in the apps with the module, for
// what the real tool leaves in the Xcode project and in the app, which the
// tests of the package cannot see since the tool is no dependency of theirs.
// The version of the tool is a caret, so a later one reaches the apps of the
// nightly run first. It reads the files of the app from the directory of the
// app, in which flutter test runs, and starts no app.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// The value of each line of the build setting [setting] of the Xcode project.
List<String> _valuesOf(String setting) => [
      for (final match in RegExp('$setting = ([^;]*);').allMatches(
        File('{{xcode_project_file}}').readAsStringSync(),
      ))
        match[1]!,
    ];

void main() {
  test(
      'the script leaves the setting that the tool writes the name of the '
      'icon into as it was in every build configuration', () {
    final values = _valuesOf(
      'ASSETCATALOG_COMPILER_GENERATE_SWIFT_ASSET_SYMBOL_EXTENSIONS',
    );
    expect(values, isNotEmpty);
    expect(values.toSet(), {'YES'});
  });

  test('every build configuration has one icon, as all flavors share it', () {
    final values = _valuesOf('ASSETCATALOG_COMPILER_APPICON_NAME');
    expect(values, isNotEmpty);
    expect(values.toSet(), {'AppIcon'});
  });

  test('the app has no configuration of the tool for a flavor', () {
    expect(
      [
        for (final entity in Directory('.').listSync())
          if (RegExp(r'flutter_launcher_icons-.*\.yaml$').hasMatch(entity.path))
            entity.path,
      ],
      isEmpty,
    );
  });
}
