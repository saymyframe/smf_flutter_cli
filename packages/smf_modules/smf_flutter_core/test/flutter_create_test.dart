@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

/// The directory of the app that
/// `flutter create --platforms=android,ios --org com.example my_app` wrote
/// with the Flutter that the brick follows. The Flutter job of CI sets it;
/// without it, the test is skipped.
const _createdApp = 'SMF_FLUTTER_CREATE_APP';

/// The files of `flutter create` that the brick leaves out: SMF's own
/// files, which it compares elsewhere, the Gradle wrapper, which Flutter
/// writes when it builds the app, the files of an IDE, and what
/// `flutter pub get` wrote, which belongs to one machine.
bool _leftOut(String path) =>
    const {
      'pubspec.yaml',
      'pubspec.lock',
      'README.md',
      'analysis_options.yaml',
      '.flutter-plugins-dependencies',
      'android/gradlew',
      'android/gradlew.bat',
      'android/gradle/wrapper/gradle-wrapper.jar',
      'android/local.properties',
      'ios/Flutter/Generated.xcconfig',
      'ios/Flutter/flutter_export_environment.sh',
    }.contains(path) ||
    path.endsWith('.iml') ||
    path.contains('GeneratedPluginRegistrant') ||
    [
      'lib/',
      'test/',
      '.dart_tool/',
      '.idea/',
      'build/',
      'ios/Flutter/ephemeral/',
    ].any(path.startsWith);

/// [text] of the file at [path] with what the brick changes on purpose
/// made the same on both sides:
/// - the label of the app is its name in title case, and `CFBundleName` in
///   Pascal case;
/// - the iOS bundle id ends with the name in kebab case;
/// - the minimum iOS version comes from the app entry role;
/// - the project has no development team, which `flutter create` takes
///   from the machine;
/// - the empty `dependencies` block of the app's Gradle file holds a
///   socket.
String _normalized(String path, String text) => switch (path) {
      'android/app/src/main/AndroidManifest.xml' =>
        text.replaceAll('android:label="my_app"', 'android:label="My App"'),
      'ios/Runner/Info.plist' => text.replaceAll(
          '<key>CFBundleName</key>\n\t<string>my_app</string>',
          '<key>CFBundleName</key>\n\t<string>MyApp</string>',
        ),
      'ios/Runner.xcodeproj/project.pbxproj' => text
          .replaceAll('com.example.myApp', 'com.example.my-app')
          .replaceAll(
            RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;'),
            'IPHONEOS_DEPLOYMENT_TARGET = <minimum>;',
          )
          .replaceAll(RegExp(r'\n\t*DEVELOPMENT_TEAM = \w+;'), ''),
      'android/app/build.gradle.kts' =>
        text.replaceAll('\n\ndependencies {\n}\n', '\n'),
      _ => text,
    };

void main() {
  final created = Platform.environment[_createdApp];

  test(
    'the brick has the files of flutter create but for its own changes',
    () async {
      final root = Directory(created!);
      final harness = ContractHarness(
        ModuleRegistry(const [FlutterCoreModule()]),
        context: const ModuleContext(
          appName: 'my_app',
          orgName: 'com.example',
          appIdentity: AppIdentity(
            androidApplicationId: 'com.example.my_app',
            iosBundleId: 'com.example.my-app',
            androidNamespace: 'com.example.my_app',
          ),
        ),
      );
      final result = await harness.check(
        const ContractCase('flutter_core', requested: [FlutterCoreModule.id]),
      );
      expect(result.errors.map((issue) => '$issue'), isEmpty);
      final rendered = {
        for (final file in result.app!.files.values)
          if (!_leftOut(file.path)) file.path: file,
      };

      final problems = <String>[];
      final prefix = root.path.endsWith(Platform.pathSeparator)
          ? root.path
          : '${root.path}${Platform.pathSeparator}';
      for (final entity in root.listSync(recursive: true)) {
        if (entity is! File) continue;
        final path = entity.path
            .substring(prefix.length)
            .replaceAll(Platform.pathSeparator, '/');
        if (_leftOut(path)) continue;
        final brick = rendered.remove(path);
        if (brick == null) {
          problems.add('$path: flutter create writes it, the brick does not');
          continue;
        }
        final bytes = entity.readAsBytesSync();
        if (path == AppEntryRole.xcodeProjectFile) {
          // The brick may ask for a later iOS than Flutter, not an earlier.
          final minimums = _iosVersionsOf(brick.text);
          final above = {
            for (final version in _iosVersionsOf(utf8.decode(bytes)))
              if (minimums.every((minimum) => _compare(version, minimum) > 0))
                version,
          };
          if (above.isNotEmpty) {
            problems.add(
              '$path: flutter create asks for iOS ${above.join(', ')}, more '
              'than the brick',
            );
          }
        }
        final same = brick.isText
            ? _normalized(path, brick.text) ==
                _normalized(path, utf8.decode(bytes, allowMalformed: true))
            : _sameBytes(brick.bytes, bytes);
        if (!same) problems.add('$path: differs from flutter create');
      }
      for (final path in rendered.keys) {
        problems.add('$path: the brick has it, flutter create does not');
      }

      expect(
        problems,
        isEmpty,
        reason: 'Update the brick with the procedure in the README.',
      );
    },
    skip: created == null
        ? 'Needs the app of flutter create in $_createdApp.'
        : false,
  );
}

/// The minimum iOS versions of the build configurations of the Xcode
/// project [text], each as its parts.
List<String> _iosVersionsOf(String text) => [
      for (final match in RegExp(
        r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);',
      ).allMatches(text))
        match[1]!,
    ];

/// Compares the versions [a] and [b], such as `13.0` and `15.0`, part by
/// part.
int _compare(String a, String b) {
  final left = a.split('.').map(int.parse).toList();
  final right = b.split('.').map(int.parse).toList();
  for (var i = 0; i < left.length || i < right.length; i++) {
    final order = (i < left.length ? left[i] : 0)
        .compareTo(i < right.length ? right[i] : 0);
    if (order != 0) return order;
  }
  return 0;
}

bool _sameBytes(List<int> a, List<int> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
