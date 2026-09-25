import 'package:smf_pipeline/src/machine_files.dart';
import 'package:smf_pipeline/src/move.dart';
import 'package:test/test.dart';

void main() {
  test('the files of one machine or build are machine files', () {
    const paths = [
      'android/local.properties',
      'android/.gradle/8.0/checksums.bin',
      'android/app/build/outputs/x.apk',
      'ios/build/x.o',
      'ios/Runner.xcodeproj/xcuserdata/me.xcuserdatad/x.plist',
      'ios/Runner.xcworkspace/xcuserdata/me.xcuserdatad/UserInterfaceState',
      'ios/Pods/Manifest.lock',
      'ios/Podfile.lock',
      'ios/.symlinks/plugins/x',
      'ios/Runner/GeneratedPluginRegistrant.m',
      'android/app/src/main/java/GeneratedPluginRegistrant.java',
      'lib/generated_plugin_registrant.dart',
      'lib/.DS_Store',
      'assets/Thumbs.db',
      'pubspec.lock',
      'packages/local/pubspec.lock',
      'tool/.dart_tool/x',
      'macos/DerivedData/x',
    ];

    for (final path in paths) {
      expect(machineFileProblem(path), isNotNull, reason: path);
    }
    for (final path in flutterToolFiles) {
      expect(
        machineFileProblem('$path/x'),
        contains("written by Flutter's tools"),
        reason: path,
      );
      expect(machineFileProblem(path), isNotNull, reason: path);
    }
  });

  test('the files of the app are not', () {
    const paths = [
      'android/build.gradle.kts',
      'android/app/build.gradle.kts',
      'ios/Podfile',
      'ios/Runner/AppDelegate.swift',
      'lib/features/build/build_screen.dart',
      'test/build/build_test.dart',
      'lib/local_properties.dart',
      'pubspec.yaml',
      '.metadata',
    ];

    for (final path in paths) {
      expect(machineFileProblem(path), isNull, reason: path);
    }
  });
}
