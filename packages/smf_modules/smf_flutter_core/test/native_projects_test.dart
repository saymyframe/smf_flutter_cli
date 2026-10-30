import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/bundles/flutter_core_bundle.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_flutter_core/src/agents.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:xml/xml.dart';

import 'support.dart';

void main() {
  const pbxproj = 'ios/Runner.xcodeproj/project.pbxproj';
  const manifest = 'android/app/src/main/AndroidManifest.xml';
  const infoPlist = 'ios/Runner/Info.plist';
  const entitlements = 'ios/Runner/Runner.entitlements';
  const appDelegate = 'ios/Runner/AppDelegate.swift';
  const settingsGradle = 'android/settings.gradle.kts';
  const appGradle = 'android/app/build.gradle.kts';

  group('the templates', () {
    late Map<String, String> templates;

    setUpAll(() {
      final brick = const FlutterCoreModule()
          .contribute(ContractHarness.defaultContext)
          .whereType<BrickContribution>()
          .firstWhere((brick) => brick.bundle == flutterCoreBundle);
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
      // Each of the twelve build configurations of the project has it.
      expect(
        placesOf(AppEntryRole.iosDeploymentTarget.tag),
        List.filled(12, pbxproj),
      );
      expect(
        RegExp('IPHONEOS_DEPLOYMENT_TARGET = ${RegExp.escape(tag)};')
            .allMatches(templates[pbxproj]!),
        hasLength(12),
      );
      expect(templates.keys, isNot(contains('ios/Podfile')));
      expect(
        templates['ios/Flutter/AppFrameworkInfo.plist'],
        isNot(contains('MinimumOSVersion')),
      );
    });

    test('have the projects of the platforms of the app only', () {
      // The directories of the platforms of flutter create.
      const flutterPlatforms = {
        'android',
        'ios',
        'linux',
        'macos',
        'web',
        'windows',
      };
      final platforms = {
        for (final path in templates.keys)
          if (path.split('/') case [final top, _, ...]
              when flutterPlatforms.contains(top))
            top,
      };

      // Modules such as firebase_core configure the app for the platforms of
      // its identity: those of the harness, as of every app of the pipeline.
      expect(
        platforms,
        ContractHarness.defaultContext.appIdentity.platforms.toSet(),
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
      // The name of each flavor is in its block of the Gradle file.
      expect(
        app.getElement('application')!.getAttribute('android:label'),
        r'${appName}',
      );
      expect(app.findElements('uses-permission'), isEmpty);
      expect(
        [
          for (final component in app.getElement('application')!.childElements)
            component.name.local,
        ],
        ['activity', 'meta-data'],
      );

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
      // The components of the modules come after the meta-data.
      expect(
        [
          for (final child in application.childElements)
            '${child.name.local} ${child.getAttribute('android:name')}',
        ],
        [
          'activity .MainActivity',
          'meta-data flutterEmbedding',
          'meta-data com.example.every_socket.KEY',
          'receiver com.example.every_socket.Receiver',
        ],
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
      // The name of each flavor is in its build configurations.
      expect(keys['CFBundleDisplayName']!.innerText, r'$(APP_DISPLAY_NAME)');
      expect(keys['CFBundleName']!.innerText, 'ContractApp');
      expect(keys, isNot(contains('UIBackgroundModes')));

      final modes = _plistKeys(every[infoPlist]!)['UIBackgroundModes']!;
      expect(modes.name.local, 'array');
      expect(modes.findElements('string').map((e) => e.innerText), ['fetch']);
    });

    test(
        'sign the app target with entitlements that parse, empty without '
        'the entitlements of the modules', () {
      const path = entitlements;

      expect(alone.keys, contains(path));
      expect(XmlDocument.parse(alone[path]!).rootElement.name.local, 'plist');
      expect(_plistKeys(alone[path]!), isEmpty);
      expect(alone[path], contains('<dict>\n</dict>\n'));
      final domains =
          _plistKeys(every[path]!)['com.apple.developer.associated-domains']!;
      expect(domains.name.local, 'array');
      expect(
        domains.findElements('string').map((e) => e.innerText),
        ['applinks:example.com'],
      );

      // Each build configuration of the app target, which reads Info.plist,
      // signs with the file, which Xcode shows in the group of the target.
      final project = alone[pbxproj]!;
      final settings = RegExp(r'buildSettings = \{([^{}]*)\};')
          .allMatches(project)
          .map((match) => match[1]!)
          .toList();
      final ofApp = settings
          .where((it) => it.contains('INFOPLIST_FILE = Runner/Info.plist;'))
          .toList();
      expect(ofApp, hasLength(12));
      for (final configuration in ofApp) {
        expect(
          'CODE_SIGN_ENTITLEMENTS = Runner/Runner.entitlements;'
              .allMatches(configuration),
          hasLength(1),
        );
      }
      expect('CODE_SIGN_ENTITLEMENTS'.allMatches(project), hasLength(12));
      final reference = RegExp(
        r'(\w{24}) /\* Runner\.entitlements \*/ = \{isa = PBXFileReference; '
        r'lastKnownFileType = text\.plist\.entitlements; '
        r'path = Runner\.entitlements; sourceTree = "<group>"; \};',
      ).firstMatch(project)!;
      final group = RegExp(
        r'/\* Runner \*/ = \{\n\t*isa = PBXGroup;\n\t*children = \(([^)]*)\);',
      ).firstMatch(project)!;
      expect(
        group[1],
        contains('${reference[1]} /* Runner.entitlements */,'),
      );
      // A file of no build phase: Xcode only signs with it.
      expect(
        RegExp(RegExp.escape(reference[1]!)).allMatches(project),
        hasLength(2),
      );
    });

    test(
        'run the code of the modules before the launch of the iOS app '
        'finishes, before Flutter takes the launch', () {
      const launch = '  ) -> Bool {\n'
          '    return super.application(application, '
          'didFinishLaunchingWithOptions: launchOptions)\n'
          '  }\n';

      // As flutter create writes it.
      expect(alone[appDelegate], contains(launch));
      expect(
        every[appDelegate],
        contains(
          launch.replaceFirst(
            '{\n',
            '{\n    UNUserNotificationCenter.current().delegate = self\n',
          ),
        ),
      );
      // Not where Flutter registers the plugins, once the scene connects.
      expect(
        every[appDelegate],
        contains(
          'func didInitializeImplicitFlutterEngine(_ engineBridge: '
          'FlutterImplicitEngineBridge) {\n'
          '    GeneratedPluginRegistrant.register(with: '
          'engineBridge.pluginRegistry)\n'
          '  }\n',
        ),
      );
    });

    test('have the bundle id and the highest minimum iOS version', () {
      String versions(String pbxproj) => RegExp(
            r'IPHONEOS_DEPLOYMENT_TARGET = ([\d.]+);',
          ).allMatches(pbxproj).map((match) => match[1]).join(' ');

      expect(versions(alone[pbxproj]!), List.filled(12, '15.0').join(' '));
      expect(versions(every[pbxproj]!), List.filled(12, '16.0').join(' '));
      // The three plain configurations and the three of prod.
      expect(
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.contract-app;'
            .allMatches(alone[pbxproj]!),
        hasLength(6),
      );
      expect(
        'PRODUCT_BUNDLE_IDENTIFIER = com.example.contract-app.RunnerTests;'
            .allMatches(alone[pbxproj]!),
        hasLength(12),
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
        '\n    implementation("androidx.annotation:annotation:1.9.1")\n'
        '    coreLibraryDesugaring("$_desugaring")\n',
      );
    });

    test(
        'enable core library desugaring only for a module that needs it, '
        'with the switch and the library together', () {
      const java17 = '        sourceCompatibility = JavaVersion.VERSION_17\n'
          '        targetCompatibility = JavaVersion.VERSION_17\n';

      // The compileOptions as flutter create writes them, and the empty
      // dependencies block of the brick.
      expect(_compileOptions(alone[appGradle]!), java17);
      expect(alone[appGradle], isNot(contains('esugaring')));
      expect(_block(alone[appGradle]!, 'dependencies'), '\n');

      expect(
        _compileOptions(every[appGradle]!),
        '$java17        isCoreLibraryDesugaringEnabled = true\n',
      );
      expect(
        _block(every[appGradle]!, 'dependencies'),
        endsWith('    coreLibraryDesugaring("$_desugaring")\n'),
      );
    });
  });

  group('the flavors of an app', () {
    late Map<String, String> texts;

    setUpAll(() async {
      texts = (await renderedApp(const [FlutterCoreModule.id])).app!.texts;
    });

    /// What each flavor of the app has beyond the id of the role: its name
    /// on the device.
    const labels = {
      'dev': 'Contract App Dev',
      'staging': 'Contract App Staging',
      'prod': 'Contract App',
    };

    test('are the flavors of the role, with their ids and names on Android',
        () {
      final gradle = texts[appGradle]!;
      expect(gradle, contains('flavorDimensions += "default"'));
      // The id of the app stays, and each flavor adds its suffix to it.
      expect(gradle, contains('applicationId = "com.example.contract_app"'));

      final flavors = RegExp(
        r'create\("(\w+)"\) \{\n([^{}]*)\}',
      ).allMatches(_block(gradle, 'productFlavors', indent: '    ')).toList();
      expect(
        [for (final flavor in flavors) flavor[1]],
        [for (final flavor in AppEntryRole.flavors) flavor.name],
      );
      for (final (index, flavor) in AppEntryRole.flavors.indexed) {
        final lines = [
          for (final line in flavors[index][2]!.split('\n'))
            if (line.trim().isNotEmpty) line.trim(),
        ];
        expect(lines, [
          'dimension = "default"',
          if (flavor.idSuffix.isNotEmpty)
            'applicationIdSuffix = "${flavor.idSuffix}"',
          'manifestPlaceholders["appName"] = "${labels[flavor.name]}"',
        ]);
      }
    });

    test(
        'have twelve configurations in each list of the Xcode project: the '
        'three plain ones, then three for each flavor', () {
      final project = _XcodeProject(texts[pbxproj]!);

      expect(project.lists, hasLength(3));
      for (final list in project.lists) {
        expect(list.keys, [
          'Debug',
          'Release',
          'Profile',
          for (final flavor in AppEntryRole.flavors)
            ...flavor.xcodeConfigurations,
        ]);
        // What xcodebuild takes when no scheme names a configuration.
        expect(list.defaultConfiguration, 'Release');
      }
    });

    test(
        'are the plain configuration of their mode in the Xcode project, '
        'but for the id and the name of the flavor', () {
      // The comparison of the brick with flutter create takes these copies
      // out, so a setting that a newer Flutter adds would reach only the
      // plain configurations, which no flutter command builds any more.
      const ofFlavor = {'PRODUCT_BUNDLE_IDENTIFIER', 'APP_DISPLAY_NAME'};
      final project = _XcodeProject(texts[pbxproj]!);

      for (final list in project.lists) {
        for (final flavor in AppEntryRole.flavors) {
          for (final name in flavor.xcodeConfigurations) {
            final plain = list.configurations[name.split('-').first]!;
            final flavored = list.configurations[name]!;

            expect(flavored.base, plain.base, reason: name);
            expect(
              {
                for (final MapEntry(:key, :value) in flavored.settings.entries)
                  if (!ofFlavor.contains(key)) key: value,
              },
              {
                for (final MapEntry(:key, :value) in plain.settings.entries)
                  if (!ofFlavor.contains(key)) key: value,
              },
              reason: name,
            );
          }
        }
      }
    });

    test('have their ids and names in the app target of the Xcode project', () {
      final project = _XcodeProject(texts[pbxproj]!);
      final ofApp = project.lists.singleWhere(
        (list) => list.configurations.values.every(
          (configuration) =>
              configuration.settings['INFOPLIST_FILE'] == 'Runner/Info.plist',
        ),
      );
      final identity = ContractHarness.defaultContext.appIdentity;

      for (final mode in const ['Debug', 'Profile', 'Release']) {
        final plain = ofApp.configurations[mode]!;
        expect(
          plain.settings['PRODUCT_BUNDLE_IDENTIFIER'],
          identity.iosBundleId,
        );
        expect(plain.settings['APP_DISPLAY_NAME'], '"Contract App"');
      }
      for (final flavor in AppEntryRole.flavors) {
        for (final name in flavor.xcodeConfigurations) {
          final settings = ofApp.configurations[name]!.settings;
          expect(
            settings['PRODUCT_BUNDLE_IDENTIFIER'],
            flavor.bundleIdIn(identity),
            reason: name,
          );
          expect(
            settings['APP_DISPLAY_NAME'],
            '"${labels[flavor.name]}"',
            reason: name,
          );
        }
      }
      // The tests of the app keep one id, and have no name of the flavor.
      for (final list in project.lists) {
        if (identical(list, ofApp)) continue;
        for (final configuration in list.configurations.values) {
          expect(configuration.settings, isNot(contains('APP_DISPLAY_NAME')));
          expect(
            configuration.settings['PRODUCT_BUNDLE_IDENTIFIER'],
            anyOf(isNull, '${identity.iosBundleId}.RunnerTests'),
          );
        }
      }
    });

    test('are the Runner scheme in their schemes, but for the configurations',
        () {
      // Without the pre-action of the Runner scheme, the first build with
      // Swift Package Manager rewrites a scheme.
      const runner = 'ios/Runner.xcodeproj/xcshareddata/xcschemes/'
          'Runner.xcscheme';
      final plain = texts[runner]!;
      expect(plain, contains('xcode_backend.sh'));

      for (final flavor in AppEntryRole.flavors) {
        final scheme = texts[flavor.xcodeSchemeFile]!;
        var expected = plain;
        for (final name in flavor.xcodeConfigurations) {
          final mode = name.split('-').first;
          expected = expected.replaceAll(
            'buildConfiguration = "$mode"',
            'buildConfiguration = "$name"',
          );
        }
        expect(scheme, expected, reason: flavor.xcodeSchemeFile);

        final actions = {
          for (final action
              in XmlDocument.parse(scheme).rootElement.childElements)
            if (action.getAttribute('buildConfiguration') case final name?)
              action.name.local: name,
        };
        expect(actions, {
          'TestAction': 'Debug-${flavor.name}',
          'LaunchAction': 'Debug-${flavor.name}',
          'ProfileAction': 'Profile-${flavor.name}',
          'AnalyzeAction': 'Debug-${flavor.name}',
          'ArchiveAction': 'Release-${flavor.name}',
        });
      }
    });

    test('tell coding agents where each flavor is, in files that the app has',
        () {
      for (final flavor in AppEntryRole.flavors) {
        expect(texts.keys, contains(flavor.xcodeSchemeFile));
        expect(
          agentNote,
          contains('`${flavor.xcodeSchemeFile.replaceFirst(
            '${flavor.name}.xcscheme',
            '<flavor>.xcscheme',
          )}`'),
        );
      }
      expect(texts.keys, containsAll([appGradle, pbxproj]));
      expect(agentNote, contains('`productFlavors` of `$appGradle`'));
      expect(agentNote, contains('`$pbxproj`'));
      expect(agentNote, contains('`Debug-<flavor>`'));
    });

    test('tell in the README where each flavor is in the native projects', () {
      final readme = texts[AppEntryRole.readmeFile]!;

      expect(
        readme,
        contains('## ${AppEntryRole.flavorProjectsHeading}\n'),
      );
      expect(
        readme,
        allOf(
          contains('`productFlavors` in `$appGradle`'),
          contains('`ios/Runner.xcodeproj/xcshareddata/xcschemes/<flavor>'
              '.xcscheme`'),
          contains('`$pbxproj`'),
          contains('select the scheme of a flavor, not `Runner`'),
        ),
      );
    });
  });
}

/// The library of core library desugaring that the modules of the app ask
/// for.
const _desugaring = 'com.android.tools:desugar_jdk_libs:2.1.4';

/// The text between the braces of the `compileOptions` of the `android`
/// block of the Gradle script of the app, [text].
String _compileOptions(String text) =>
    RegExp(r'\n    compileOptions \{\n([^{}]*?)    \}\n').firstMatch(text)![1]!;

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

/// The text between the braces of the block [name] of the Gradle script
/// [text] at the level of [indent], whose closing brace is the first at that
/// level.
String _block(String text, String name, {String indent = ''}) {
  final open =
      RegExp('^$indent$name \\{', multiLine: true).firstMatch(text)!.end;
  return text.substring(open, text.indexOf('\n$indent}', open) + 1);
}

/// A build configuration of an Xcode project: its base configuration, as the
/// object it refers to, and its build settings by name, each with its value
/// as the project writes it.
typedef _Configuration = ({String? base, Map<String, String> settings});

/// A configuration list of an Xcode project: its [configurations] by name,
/// in their order, and the name of its default.
final class _ConfigurationList {
  _ConfigurationList(this.configurations, this.defaultConfiguration);

  final Map<String, _Configuration> configurations;

  final String defaultConfiguration;

  Iterable<String> get keys => configurations.keys;
}

/// The configuration lists of an Xcode project, read as Xcode writes the
/// objects: each on lines of their own, at their depth of tabs.
final class _XcodeProject {
  _XcodeProject(String text) {
    final objects = <String, _Configuration>{
      for (final match in RegExp(
        r'\t\t(\w{24}) /\* [^*]+ \*/ = \{\n'
        r'\t\t\tisa = XCBuildConfiguration;\n'
        r'(?:\t\t\tbaseConfigurationReference = (\w{24}) /\* [^*]+ \*/;\n)?'
        r'\t\t\tbuildSettings = \{\n(.*?)\n\t\t\t\};\n'
        r'\t\t\tname = [^;]+;\n\t\t\};',
        dotAll: true,
      ).allMatches(text))
        match[1]!: (base: match[2], settings: _settingsOf(match[3]!)),
    };
    lists = [
      for (final match in RegExp(
        r'isa = XCConfigurationList;\n'
        r'\t\t\tbuildConfigurations = \(\n(.*?)\n\t\t\t\);\n'
        r'.*?defaultConfigurationName = (\w+);',
        dotAll: true,
      ).allMatches(text))
        _ConfigurationList(
          {
            for (final item
                in RegExp(r'(\w{24}) /\* ([\w-]+) \*/,').allMatches(match[1]!))
              item[2]!: objects[item[1]!]!,
          },
          match[2]!,
        ),
    ];
  }

  late final List<_ConfigurationList> lists;

  /// The settings of a block of build settings: each is on one line, or on
  /// several when its value is a list.
  static Map<String, String> _settingsOf(String block) => {
        for (final match in RegExp(
          r'^\t\t\t\t("[^"]+"|\w+) = (\(.*?\n\t\t\t\t\)|[^;]*);$',
          multiLine: true,
          dotAll: true,
        ).allMatches(block))
          match[1]!: match[2]!,
      };
}
