// Tests tools/native_build.dart, which writes what the apps of a directory
// build their native side with, whose hash keys the caches of what Gradle
// and Swift Package Manager download in the jobs of CI.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

import 'native_build.dart';

/// The Gradle settings of an app, with the lines that flutterfire adds with
/// [flutterfire].
String _settings({bool flutterfire = false}) => '''
pluginManagement {
    includeBuild("\$flutterSdkPath/packages/flutter_tools/gradle")
}

plugins {
    id("com.android.application") version "9.0.1" apply false
${flutterfire ? '    id("com.google.gms.google-services") version("4.4.4") apply false\n' : ''}}
''';

/// The Gradle build script of the app module of an app with the id [id].
String _appScript(String id) => '''
android {
    namespace = "$id"

    defaultConfig {
        applicationId = "$id"
        minSdk = flutter.minSdkVersion
    }
}
''';

/// An Xcode project of an app with the id [id], the remote Swift package
/// [package] with the version [version], if any, and the build phase that
/// flutterfire adds with [flutterfire].
String _project(
  String id, {
  String? package,
  String version = '12.0.0',
  bool flutterfire = false,
}) =>
    '''
// !\$*UTF8*\$!
{
	objects = {
${flutterfire ? '''
/* Begin PBXShellScriptBuildPhase section */
		AB0001 /* [firebase_crashlytics] Crashlytics Upload Symbols */ = {
			isa = PBXShellScriptBuildPhase;
		};
/* End PBXShellScriptBuildPhase section */
''' : ''}
/* Begin XCBuildConfiguration section */
		AB0002 /* Debug */ = {
			buildSettings = {
				PRODUCT_BUNDLE_IDENTIFIER = $id;
			};
		};
/* End XCBuildConfiguration section */
${package == null ? '' : '''
/* Begin XCRemoteSwiftPackageReference section */
		AB0003 /* XCRemoteSwiftPackageReference "$package" */ = {
			isa = XCRemoteSwiftPackageReference;
			repositoryURL = "https://github.com/example/$package";
			requirement = {
				kind = upToNextMajorVersion;
				minimumVersion = $version;
			};
		};
/* End XCRemoteSwiftPackageReference section */
'''}
	};
}
''';

void main() {
  late Directory temp;

  setUp(() => temp = Directory.systemTemp.createTempSync('native_build_'));
  tearDown(() => temp.deleteSync(recursive: true));

  /// Writes [text] to the file at [path] in the temporary directory, with
  /// the directories on its way.
  void write(String path, String text) => File('${temp.path}/$path')
    ..createSync(recursive: true)
    ..writeAsStringSync(text);

  /// Writes the files of packages of the app in [directory], a directory
  /// of the temporary directory, as `flutter pub get` writes them:
  /// .flutter-plugins-dependencies, with the plugins by platform in
  /// [plugins], pubspec.lock, with the versions of [versions] from pub.dev
  /// and the packages [others] as they are, and
  /// .dart_tool/package_config.json.
  void packages(
    String directory, {
    required Map<String, List<Map<String, Object?>>> plugins,
    Map<String, String> versions = const {},
    String others = '',
  }) {
    write(
      '$directory/.dart_tool/package_config.json',
      jsonEncode({'configVersion': 2, 'packages': <Object?>[]}),
    );
    write(
      '$directory/.flutter-plugins-dependencies',
      jsonEncode({
        'info': 'This is a generated file; do not edit or check into version '
            'control.',
        'plugins': plugins,
        'dependencyGraph': <Object?>[],
        'date_created': '${DateTime.now()}',
        'version': '3.44.2',
      }),
    );
    write('$directory/pubspec.lock', '''
packages:
${[
      for (final MapEntry(key: name, value: version) in versions.entries)
        '''
  $name:
    dependency: "direct main"
    description:
      name: $name
      sha256: "0123"
      url: "https://pub.dev"
    source: hosted
    version: "$version"
''',
    ].join()}$others''');
  }

  /// An app [name] in the directory `apps` of the temporary directory, with
  /// Firebase Core [core] as its plugin for Android and iOS, the id [id],
  /// the lines of Gradle and the build phase of flutterfire with
  /// [flutterfire], and the Swift package [package] in its Xcode project,
  /// if any, with the version [version].
  Directory firebaseApp(
    String name, {
    String id = 'com.example.app',
    String core = '4.1.1',
    bool flutterfire = false,
    String? package,
    String version = '12.0.0',
  }) {
    packages(
      'apps/$name',
      plugins: {
        for (final platform in ['android', 'ios'])
          platform: [
            {'name': 'firebase_core', 'native_build': true},
          ],
      },
      versions: {'firebase_core': core},
    );
    write(
      'apps/$name/android/settings.gradle.kts',
      _settings(flutterfire: flutterfire),
    );
    write('apps/$name/android/app/build.gradle.kts', _appScript(id));
    write(
      'apps/$name/ios/Runner.xcodeproj/project.pbxproj',
      _project(
        id,
        package: package,
        version: version,
        flutterfire: flutterfire,
      ),
    );
    return Directory('${temp.path}/apps/$name');
  }

  group('what an app builds its native side with', () {
    test(
        'has no plugins for an app without .flutter-plugins-dependencies, '
        'which Flutter does not write for an app without plugins of its own, '
        'once pub resolved the app', () {
      // As the app of the start check without Firebase: its only plugin,
      // integration_test, is a dev dependency from the Flutter SDK.
      packages(
        'app',
        plugins: {},
        others: '''
  integration_test:
    dependency: "direct dev"
    description: flutter
    source: sdk
    version: "0.0.0"
''',
      );
      File('${temp.path}/app/.flutter-plugins-dependencies').deleteSync();
      write('app/android/settings.gradle.kts', 'plugins {}\n');
      write(
        'app/ios/Runner.xcodeproj/project.pbxproj',
        _project('com.example.app'),
      );
      final app = Directory('${temp.path}/app');

      expect(
        nativeBuildOf(app, 'android'),
        'file android/settings.gradle.kts\n'
        '  plugins {}',
      );
      expect(nativeBuildOf(app, 'ios'), isEmpty);
    });

    test(
        'has the plugins with native code for the platform, with their '
        'versions, but those of the Flutter SDK', () {
      packages(
        'app',
        plugins: {
          'android': [
            {'name': 'firebase_core', 'native_build': true},
            {'name': 'git_plugin'},
            {'name': 'integration_test', 'native_build': true},
            {'name': 'dart_only', 'native_build': false},
          ],
          'ios': [
            {'name': 'integration_test', 'native_build': true},
            {'name': 'firebase_core', 'native_build': true},
          ],
          'web': [
            {'name': 'firebase_core_web'},
          ],
        },
        versions: {'firebase_core': '4.1.1', 'dart_only': '1.0.0'},
        others: '''
  git_plugin:
    dependency: "direct main"
    description:
      path: "."
      ref: main
      resolved-ref: "0123abcd"
      url: "https://github.com/example/git_plugin.git"
    source: git
    version: "1.2.0"
  integration_test:
    dependency: "direct dev"
    description: flutter
    source: sdk
    version: "0.0.0"
sdks:
  dart: ">=3.12.0 <4.0.0"
''',
      );
      write('app/android/settings.gradle.kts', 'plugins {}\n');
      write('app/ios/Runner.xcodeproj/project.pbxproj', _project('app'));
      final app = Directory('${temp.path}/app');

      expect(
        nativeBuildOf(app, 'android'),
        'plugin firebase_core 4.1.1 (hosted)\n'
        'plugin git_plugin 1.2.0 (git 0123abcd)\n'
        'file android/settings.gradle.kts\n'
        '  plugins {}',
      );
      expect(nativeBuildOf(app, 'ios'), 'plugin firebase_core 4.1.1 (hosted)');
    });

    test(
        'has the Gradle files of the Android project without the lines that '
        'set the ids of the app, but not the other files of the project', () {
      packages('app', plugins: {});
      write('app/android/settings.gradle.kts', 'include(":app")\r\n');
      write('app/android/build.gradle', "apply plugin: 'base'\n");
      write('app/android/app/build.gradle.kts', _appScript('com.example.app'));
      write('app/android/gradle.properties', 'android.useAndroidX=true\n');
      write(
        'app/android/gradle/wrapper/gradle-wrapper.properties',
        'distributionUrl=gradle-9.1.0-all.zip\n',
      );
      write('app/android/gradle/libs.versions.toml', '[versions]\n');
      // The paths of the machine, the sources of the app, and what Gradle
      // and the builds write, which change nothing that Gradle downloads.
      write('app/android/local.properties', 'flutter.sdk=/flutter\n');
      write(
        'app/android/app/src/main/AndroidManifest.xml',
        '<manifest android:label="app"/>\n',
      );
      write('app/android/build/generated.gradle', 'generated\n');
      write('app/android/.gradle/cache.gradle', 'cache\n');
      write('app/android/app/.cxx/native.gradle', 'native\n');

      expect(
        nativeBuildOf(Directory('${temp.path}/app'), 'android'),
        'file android/app/build.gradle.kts\n'
        '  android {\n'
        '  \n'
        '      defaultConfig {\n'
        '          minSdk = flutter.minSdkVersion\n'
        '      }\n'
        '  }\n'
        'file android/build.gradle\n'
        "  apply plugin: 'base'\n"
        'file android/gradle.properties\n'
        '  android.useAndroidX=true\n'
        'file android/gradle/libs.versions.toml\n'
        '  [versions]\n'
        'file android/gradle/wrapper/gradle-wrapper.properties\n'
        '  distributionUrl=gradle-9.1.0-all.zip\n'
        'file android/settings.gradle.kts\n'
        '  include(":app")',
      );
    });

    test(
        'has the Swift packages that the Xcode project refers to itself, but '
        'nothing else of the project', () {
      final app = firebaseApp('app', package: 'swift-package');

      expect(
        nativeBuildOf(app, 'ios'),
        'plugin firebase_core 4.1.1 (hosted)\n'
        'file ios/Runner.xcodeproj/project.pbxproj: remote Swift packages\n'
        '  AB0003 /* XCRemoteSwiftPackageReference "swift-package" */ = {\n'
        '  isa = XCRemoteSwiftPackageReference;\n'
        '  repositoryURL = "https://github.com/example/swift-package";\n'
        '  requirement = {\n'
        '  kind = upToNextMajorVersion;\n'
        '  minimumVersion = 12.0.0;\n'
        '  };\n'
        '  };',
      );
    });

    test(
        'is the same for apps that differ in their names and ids, or in what '
        'changes no download, and differs for apps that build with another '
        'plugin, version or Gradle plugin', () {
      String android(Directory app) => nativeBuildOf(app, 'android');
      String ios(Directory app) => nativeBuildOf(app, 'ios');
      final app = firebaseApp('app', package: 'swift-package');
      final other = firebaseApp(
        'other',
        id: 'com.saymyframe.ci.other',
        package: 'swift-package',
      );
      final newer =
          firebaseApp('newer', core: '4.2.0', package: 'swift-package');
      // flutterfire adds the Gradle plugins of Google services to the
      // Gradle files, and a build phase to the Xcode project.
      final configured = firebaseApp(
        'configured',
        flutterfire: true,
        package: 'swift-package',
      );
      final package = firebaseApp('package', package: 'other-package');
      final version = firebaseApp(
        'version',
        package: 'swift-package',
        version: '13.0.0',
      );

      expect(android(other), android(app));
      expect(ios(other), ios(app));
      expect(ios(configured), ios(app));
      expect(android(newer), isNot(android(app)));
      expect(ios(newer), isNot(ios(app)));
      expect(android(configured), isNot(android(app)));
      expect(ios(package), isNot(ios(app)));
      expect(ios(version), isNot(ios(app)));
    });

    test(
        'fails for an app that pub did not resolve, without the version of a '
        'plugin, or without a project for the platform', () {
      Matcher fails(String message) => throwsA(
            isA<NativeBuildException>()
                .having((error) => error.message, 'message', message),
          );
      final app = Directory('${temp.path}/app');
      write('app/pubspec.yaml', 'name: app\n');
      expect(
        () => nativeBuildOf(app, 'android'),
        fails('${app.path} has no pubspec.lock: run flutter pub get in it.'),
      );
      write('app/pubspec.lock', 'packages: {}\n');
      expect(
        () => nativeBuildOf(app, 'android'),
        fails(
          '${app.path} has no .dart_tool/package_config.json: run flutter '
          'pub get in it.',
        ),
      );

      packages(
        'app',
        plugins: {
          'ios': [
            {'name': 'firebase_core'},
          ],
        },
      );
      expect(
        () => nativeBuildOf(app, 'ios'),
        fails(
          'The pubspec.lock of ${app.path} has no version of firebase_core, a '
          'plugin of its .flutter-plugins-dependencies: run flutter pub get '
          'in it.',
        ),
      );

      packages('app', plugins: {});
      expect(
        () => nativeBuildOf(app, 'android'),
        fails('${app.path} has no Android project, android/.'),
      );
      write('app/ios/Podfile', "platform :ios, '15.0'\n");
      expect(
        () => nativeBuildOf(app, 'ios'),
        fails('${app.path} has no Xcode project, ios/<name>.xcodeproj.'),
      );
      expect(() => nativeBuildOf(app, 'web'), throwsArgumentError);
    });
  });

  group('the file of the apps of a directory', () {
    test(
        'has each build once, whatever the number and the names of the apps '
        'with it', () {
      final app = firebaseApp('app');
      final other = firebaseApp('other', id: 'com.saymyframe.ci.other');
      final newer = firebaseApp('newer', core: '4.2.0');
      final apps = Directory('${temp.path}/apps');
      // Neither a file nor a hidden directory is an app.
      write('apps/notes.txt', 'no app');
      write('apps/.hidden/pubspec.yaml', 'name: hidden\n');

      final builds = nativeBuildsOf(apps, 'android');

      expect(builds.keys, ['app', 'newer', 'other']);
      expect(
        nativeBuildFileOf([builds['app']!, builds['other']!]),
        nativeBuildFileOf([nativeBuildOf(app, 'android')]),
      );
      expect(
        nativeBuildFileOf(builds.values),
        '${nativeBuildOf(app, 'android')}\n\n'
        '${nativeBuildOf(newer, 'android')}\n',
      );
      expect(
        nativeBuildFileOf([nativeBuildOf(other, 'android')]),
        '${nativeBuildOf(app, 'android')}\n',
      );
    });

    test('fails for a directory without apps', () {
      write('apps/notes.txt', 'no app');
      final apps = Directory('${temp.path}/apps');

      expect(
        () => nativeBuildsOf(apps, 'android'),
        throwsA(
          isA<NativeBuildException>().having(
            (error) => error.message,
            'message',
            '${apps.path} has no app.',
          ),
        ),
      );
    });
  });

  group('the tool', () {
    late String root;

    setUpAll(() {
      final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
      expect(top.exitCode, 0, reason: '${top.stderr}');
      root = '${top.stdout}'.trim();
    });

    /// Runs the tool with [arguments] from the root of the repository.
    Future<ProcessResult> run(List<String> arguments) => Process.run(
          Platform.resolvedExecutable,
          ['tools/native_build.dart', ...arguments],
          workingDirectory: root,
        );

    test(
        'writes the file of the apps of a directory and prints what they '
        'build with', () async {
      final app = firebaseApp('app');
      firebaseApp('other', id: 'com.saymyframe.ci.other');
      final file = '${temp.path}/build/native_build/android.txt';

      final result = await run(['android', '${temp.path}/apps', file]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        File(file).readAsStringSync(),
        nativeBuildFileOf([nativeBuildOf(app, 'android')]),
      );
      expect(
        '${result.stdout}',
        startsWith(
          'What app, other build with for android:\n'
          'plugin firebase_core 4.1.1 (hosted)\n'
          'file android/app/build.gradle.kts\n',
        ),
      );
      expect(
        '${result.stdout}',
        endsWith('Wrote what the apps build with to $file.\n'),
      );
    });

    test(
        'writes no file for apps that download nothing for the platform, '
        'such as the app of the start check for iOS, and removes the one '
        'there, so that a key that hashes it is empty', () async {
      // Its only plugin, integration_test, comes with the Flutter SDK.
      packages(
        'apps/start_app',
        plugins: {
          'ios': [
            {'name': 'integration_test', 'native_build': true},
          ],
        },
        others: '''
  integration_test:
    dependency: "direct dev"
    description: flutter
    source: sdk
    version: "0.0.0"
''',
      );
      write(
        'apps/start_app/ios/Runner.xcodeproj/project.pbxproj',
        _project('com.example.start_app'),
      );
      write('build/native_build/ios.txt', 'What an earlier app built with.\n');
      final file = '${temp.path}/build/native_build/ios.txt';

      final result = await run(['ios', '${temp.path}/apps', file]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(File(file).existsSync(), isFalse);
      expect(
        '${result.stdout}',
        'What start_app builds with for ios:\n'
            '  no plugin with native code, and nothing else to download\n'
            'The apps download nothing for ios: no file at $file.\n',
      );
    });

    test(
        'writes the Gradle files of an app without '
        '.flutter-plugins-dependencies, such as the app of the start check '
        'for Android, which Flutter writes for no plugins of the SDK',
        () async {
      packages('apps/start_app', plugins: {});
      File('${temp.path}/apps/start_app/.flutter-plugins-dependencies')
          .deleteSync();
      write('apps/start_app/android/settings.gradle.kts', 'plugins {}\n');
      final file = '${temp.path}/build/native_build/android.txt';

      final result = await run(['android', '${temp.path}/apps', file]);

      expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
      expect(
        File(file).readAsStringSync(),
        'file android/settings.gradle.kts\n'
        '  plugins {}\n',
      );
    });

    test(
        'fails for a directory without apps, and on a platform or arguments '
        'that it does not take', () async {
      write('apps/notes.txt', 'no app');
      final apps = '${temp.path}/apps';
      final file = '${temp.path}/android.txt';

      final empty = await run(['android', apps, file]);
      expect(empty.exitCode, 1, reason: '${empty.stdout}${empty.stderr}');
      expect('${empty.stderr}', '::error::$apps has no app.\n');
      expect(File(file).existsSync(), isFalse);

      for (final arguments in [
        ['web', apps, file],
        ['android', apps],
        ['android', '${temp.path}/none', file],
      ]) {
        final usage = await run(arguments);
        expect(usage.exitCode, 64, reason: '$arguments: ${usage.stderr}');
        expect(
          '${usage.stderr}',
          'Usage: dart tools/native_build.dart <android|ios> <directory of '
              'apps> <file>\n',
        );
      }
    });
  });
}
