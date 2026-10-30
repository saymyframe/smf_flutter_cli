@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
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
/// `flutter pub get` wrote, which belongs to one machine. The guide for
/// coding agents, which the app entry role adds to every app, is no file of
/// `flutter create` either, and neither are the entitlements of the iOS
/// app, which the brick adds, or the schemes of the flavors, which
/// `test/native_projects_test.dart` compares with the `Runner` scheme.
bool _leftOut(String path) =>
    {
      'pubspec.yaml',
      'pubspec.lock',
      'README.md',
      AppEntryRole.agentsFile,
      AppEntryRole.claudeFile,
      AppEntryRole.iosEntitlementsFile,
      'analysis_options.yaml',
      '.flutter-plugins-dependencies',
      'android/gradlew',
      'android/gradlew.bat',
      'android/gradle/wrapper/gradle-wrapper.jar',
      'android/local.properties',
      'ios/Flutter/Generated.xcconfig',
      'ios/Flutter/flutter_export_environment.sh',
      for (final flavor in AppEntryRole.flavors) flavor.xcodeSchemeFile,
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

/// The line of the setting with which a build configuration of the app
/// target signs the app with its entitlements.
final _signsWithEntitlements = RegExp(
  r'\n\t*CODE_SIGN_ENTITLEMENTS = Runner/Runner\.entitlements;',
);

/// A line of the Xcode project with the reference to the entitlements of
/// the app: the reference itself, and the child of the group of the target.
final _entitlementsReference = RegExp(
  r'\n[^\n]*/\* Runner\.entitlements \*/[^\n]*',
);

/// A build configuration of a flavor in the Xcode project of the brick,
/// which `flutter create` does not write: an object whose id starts with
/// `F1A5`, unlike the ids of `flutter create`. So the comparison leaves the
/// flavors out without knowing the names of their configurations.
final _flavorConfiguration = RegExp(
  r'\t\tF1A5[0-9A-F]{20} /\* [\w-]+ \*/ = \{\n.*?\n\t\t\};\n',
  dotAll: true,
);

/// The item of a configuration list that refers to a build configuration of
/// a flavor.
final _flavorListItem = RegExp(r'\t\t\t\tF1A5[0-9A-F]{20} /\* [\w-]+ \*/,\n');

/// The line of the name of the app on the device in a plain build
/// configuration of the app target.
final _displayNameSetting = RegExp(r'\t\t\t\tAPP_DISPLAY_NAME = "[^"]+";\n');

/// The flavors in the Gradle file of the app, up to the next block.
final _productFlavors = RegExp(
  r'    flavorDimensions \+= "default"\n    productFlavors \{\n.*?\n    \}\n\n',
  dotAll: true,
);

/// What the brick adds for its flavors to the file of `flutter create` at
/// [path], as the list of what comes out of it and how many times.
List<(RegExp, int)> _flavorsIn(String path) => switch (path) {
      AppEntryRole.xcodeProjectFile => [
          (_flavorConfiguration, 27),
          (_flavorListItem, 27),
          (_displayNameSetting, 3),
        ],
      AppEntryRole.gradleAppFile => [(_productFlavors, 1)],
      _ => const [],
    };

/// [text] of the file at [path] of the brick without what the brick adds for
/// its flavors. Each pattern takes as much as it is known to, so a pattern
/// that takes too much or too little fails here, and not as a difference
/// from `flutter create` that says nothing of the cause.
String _withoutFlavors(String path, String text) {
  var stripped = text;
  for (final (pattern, count) in _flavorsIn(path)) {
    expect(
      pattern.allMatches(stripped),
      hasLength(count),
      reason: '$path: what the comparison leaves out of ${pattern.pattern}.',
    );
    stripped = stripped.replaceAll(pattern, '');
  }
  return stripped;
}

/// [text] of the file at [path] with what the brick changes on purpose
/// made the same on both sides:
/// - the label of the app comes from the flavor, as a placeholder in the
///   Android manifest and a build setting in `Info.plist`, and `CFBundleName`
///   is its name in Pascal case;
/// - the iOS bundle id ends with the name in kebab case;
/// - the minimum iOS version comes from the app entry role;
/// - the project has no development team, which `flutter create` takes
///   from the machine;
/// - the app target signs with the entitlements of the app, which the
///   project shows in the group of the target;
/// - the empty `dependencies` block of the app's Gradle file holds a
///   socket.
String _normalized(String path, String text) => switch (path) {
      'android/app/src/main/AndroidManifest.xml' => text.replaceAll(
          'android:label="my_app"',
          r'android:label="${appName}"',
        ),
      'ios/Runner/Info.plist' => text
          .replaceAll(
            '<key>CFBundleName</key>\n\t<string>my_app</string>',
            '<key>CFBundleName</key>\n\t<string>MyApp</string>',
          )
          .replaceAll(
            '<key>CFBundleDisplayName</key>\n\t<string>My App</string>',
            '<key>CFBundleDisplayName</key>\n'
                '\t<string>\$(APP_DISPLAY_NAME)</string>',
          ),
      'ios/Runner.xcodeproj/project.pbxproj' => text
          .replaceAll('com.example.myApp', 'com.example.my-app')
          .replaceAll(
            RegExp(r'IPHONEOS_DEPLOYMENT_TARGET = [\d.]+;'),
            'IPHONEOS_DEPLOYMENT_TARGET = <minimum>;',
          )
          .replaceAll(RegExp(r'\n\t*DEVELOPMENT_TEAM = \w+;'), '')
          .replaceAll(_signsWithEntitlements, '')
          .replaceAll(_entitlementsReference, ''),
      'android/app/build.gradle.kts' =>
        text.replaceAll('\n\ndependencies {\n}\n', '\n'),
      _ => text,
    };

void main() {
  final created = Platform.environment[_createdApp];

  test(
      'takes the flavors out of the brick, and only those, without the app of '
      'flutter create', () async {
    final result = await ContractHarness(
      ModuleRegistry(const [FlutterCoreModule()]),
    ).check(
      const ContractCase('flutter_core', requested: [FlutterCoreModule.id]),
    );
    final texts = result.app!.texts;

    // It is what the project has without flavors: three build configurations
    // in each of the three lists, and an id in each of them.
    final project = _withoutFlavors(
      AppEntryRole.xcodeProjectFile,
      texts[AppEntryRole.xcodeProjectFile]!,
    );
    expect(
      'isa = XCBuildConfiguration;'.allMatches(project),
      hasLength(9),
    );
    for (final left in [
      'F1A5',
      'APP_DISPLAY_NAME',
      for (final flavor in AppEntryRole.flavors) ...[
        flavor.idSuffix,
        ...flavor.xcodeConfigurations,
      ],
    ]) {
      if (left.isNotEmpty) expect(project, isNot(contains(left)));
    }
    final gradle = _withoutFlavors(
      AppEntryRole.gradleAppFile,
      texts[AppEntryRole.gradleAppFile]!,
    );
    expect(gradle, isNot(contains('lavor')));
    expect(
      gradle,
      contains(
        '        versionName = flutter.versionName\n'
        '    }\n'
        '\n'
        '    buildTypes {\n',
      ),
    );
  });

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
            platforms: ['android', 'ios'],
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
            ? _normalized(path, _withoutFlavors(path, brick.text)) ==
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
