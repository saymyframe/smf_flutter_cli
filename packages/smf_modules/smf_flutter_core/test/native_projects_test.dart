import 'package:smf_contracts/lego.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'support.dart';

void main() {
  const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
  const manifest = 'android/app/src/main/AndroidManifest.xml';
  const infoPlist = 'ios/Runner/Info.plist';
  const settingsGradle = 'android/settings.gradle.kts';
  const appGradle = 'android/app/build.gradle.kts';

  group('the templates', () {
    late Map<String, String> templates;

    setUpAll(() {
      final brick = const FlutterCoreModule()
          .contribute(ContractHarness.defaultContext)
          .whereType<BrickContribution>()
          .single;
      templates = templateFilesOf(brick);
    });

    /// The paths of the templates with [tag], one for each time it appears.
    List<String> placesOf(String tag) => [
          for (final MapEntry(key: path, value: text) in templates.entries)
            for (final _ in '{{{$tag}}}'.allMatches(text)) path,
        ];

    test('set the minimum iOS version only in the Xcode project', () {
      const tag = '{{{smf_app_entry__ios_deployment_target}}}';

      // Flutter takes it from there for the Swift packages of plugins, and
      // CocoaPods for their pods: the Podfile that Flutter writes when a
      // plugin needs one leaves the platform to the Xcode project.
      expect(
        placesOf(AppEntryRole.iosDeploymentTarget.tag),
        [pbxproj, pbxproj, pbxproj],
      );
      expect(
        RegExp('IPHONEOS_DEPLOYMENT_TARGET = ${RegExp.escape(tag)};')
            .allMatches(templates[pbxproj]!),
        hasLength(3),
      );
      expect(templates.keys, isNot(contains('ios/Podfile')));
      expect(
        templates['ios/Flutter/AppFrameworkInfo.plist'],
        isNot(contains('MinimumOSVersion')),
      );
    });

    test('hold nothing of the machine they were made on', () {
      expect(templates[pbxproj], isNot(contains('DEVELOPMENT_TEAM')));
      for (final MapEntry(key: path, value: text) in templates.entries) {
        expect(text, isNot(contains('/Users/')), reason: path);
        expect(text, isNot(contains('flutter.sdk=')), reason: path);
      }
    });
  });

  group('the native projects of an app', () {
    late Map<String, String> alone;
    late Map<String, String> every;

    setUpAll(() async {
      alone = (await renderedApp(const [FlutterCoreModule.id])).app!.texts;
      every = (await renderedApp(const [
        FlutterCoreModule.id,
        EverySocketModule.id,
      ]))
          .app!
          .texts;
    });

    test('leave no blank line where a socket is empty', () {
      expect(
        alone[manifest],
        startsWith(
          '<manifest xmlns:android="http://schemas.android.com/apk/res/android">\n'
          '    <application\n',
        ),
      );
      expect(alone[appGradle], endsWith('dependencies {\n}\n'));
      expect(alone[infoPlist], endsWith('\t</array>\n</dict>\n</plist>\n'));
      expect(
        alone[settingsGradle],
        contains('apply false\n}\n'),
      );
    });

    test('name the Kotlin package of MainActivity after the app', () {
      const path = 'android/app/src/main/kotlin/com/example/contract_app/'
          'MainActivity.kt';

      expect(alone[path], startsWith('package com.example.contract_app\n'));
      expect(
        alone[appGradle],
        allOf(
          contains('namespace = "com.example.contract_app"'),
          contains('applicationId = "com.example.contract_app"'),
        ),
      );
    });

    test('have a manifest that parses, with the entries of the modules', () {
      final app = XmlDocument.parse(alone[manifest]!).rootElement;
      expect(
        app.getElement('application')!.getAttribute('android:label'),
        'Contract App',
      );
      expect(app.findElements('uses-permission'), isEmpty);

      final root = XmlDocument.parse(every[manifest]!).rootElement;
      final application = root.getElement('application')!;
      final activity = application.getElement('activity')!;
      expect(
        [
          for (final permission in root.findElements('uses-permission'))
            permission.getAttribute('android:name'),
        ],
        ['android.permission.INTERNET'],
      );
      expect(
        [
          for (final meta in application.findElements('meta-data'))
            meta.getAttribute('android:name'),
        ],
        ['flutterEmbedding', 'com.example.every_socket.KEY'],
      );
      expect(
        [
          for (final filter in activity.findElements('intent-filter'))
            filter.getElement('action')!.getAttribute('android:name'),
        ],
        ['android.intent.action.MAIN', 'android.intent.action.VIEW'],
      );
    });

    test('have an Info.plist that parses, with the keys of the modules', () {
      final keys = _plistKeys(alone[infoPlist]!);
      expect(keys['CFBundleDisplayName']!.innerText, 'Contract App');
      expect(keys['CFBundleName']!.innerText, 'ContractApp');
      expect(keys, isNot(contains('UIBackgroundModes')));

      final modes = _plistKeys(every[infoPlist]!)['UIBackgroundModes']!;
      expect(modes.name.local, 'array');
      expect(modes.findElements('string').map((e) => e.innerText), ['fetch']);
    });

    test('have the bundle id and the highest minimum iOS version', () {
      String versions(String pbxproj) => RegExp(
            r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);',
          ).allMatches(pbxproj).map((match) => match[1]).join(' ');

      expect(versions(alone[pbxproj]!), '15.0 15.0 15.0');
      expect(versions(every[pbxproj]!), '16.0 16.0 16.0');
      expect(
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.contract-app;'
            .allMatches(alone[pbxproj]!),
        hasLength(3),
      );
      expect(
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.contract-app.RunnerTests;'
            .allMatches(alone[pbxproj]!),
        hasLength(3),
      );
    });

    test('put the Gradle plugins and dependencies of the modules in place', () {
      expect(
        _block(every[settingsGradle]!, 'plugins'),
        contains(
          '    id("io.github.ben-manes.versions") version("0.64.0") '
          'apply false\n',
        ),
      );
      expect(
        _block(every[appGradle]!, 'plugins'),
        endsWith(
          '    id("dev.flutter.flutter-gradle-plugin")\n'
          '    id("io.github.ben-manes.versions")\n',
        ),
      );
      expect(
        _block(every[appGradle]!, 'dependencies'),
        '\n    implementation("androidx.annotation:annotation:1.9.1")\n',
      );
    });
  });
}

/// The value elements of the top-level dictionary of the property list
/// [text], by key.
Map<String, XmlElement> _plistKeys(String text) {
  final dict = XmlDocument.parse(text).rootElement.getElement('dict')!;
  final children = dict.childElements.toList();
  return {
    for (var i = 0; i + 1 < children.length; i += 2)
      children[i].innerText: children[i + 1],
  };
}

/// The text between the braces of the top-level block [name] of the Gradle
/// script [text], which has no nested braces in these tests.
String _block(String text, String name) {
  final open = RegExp('^$name \\{', multiLine: true).firstMatch(text)!.end;
  return text.substring(open, text.indexOf('\n}', open) + 1);
}
