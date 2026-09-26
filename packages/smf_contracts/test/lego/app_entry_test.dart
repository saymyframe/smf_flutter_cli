import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/lego.dart';
import 'package:test/test.dart';

import 'support.dart';

/// Indexes of a minimal app that satisfies the app entry role.
Map<String, DartFileIndex> _app({
  List<IndexedImport> bootstrapImports = const [
    IndexedImport('package:flutter/foundation.dart'),
  ],
  List<IndexedInvocation> mainCalls = const [
    IndexedInvocation(
      'ensureInitialized',
      target: 'WidgetsFlutterBinding',
      enclosingDeclaration: 'main',
      offset: 10,
    ),
    IndexedInvocation(
      'bootstrap',
      enclosingDeclaration: 'main',
      awaited: true,
      offset: 20,
    ),
    IndexedInvocation('runApp', enclosingDeclaration: 'main', offset: 30),
  ],
}) {
  return {
    AppEntryRole.mainFile: DartFileIndex(
      path: AppEntryRole.mainFile,
      declarations: const [
        IndexedDeclaration(
          name: 'main',
          kind: DeclarationKind.function,
          type: 'Future<void>',
          isAsync: true,
        ),
      ],
      invocations: mainCalls,
    ),
    AppEntryRole.bootstrapFile: DartFileIndex(
      path: AppEntryRole.bootstrapFile,
      imports: bootstrapImports,
      declarations: const [
        IndexedDeclaration(
          name: 'bootstrap',
          kind: DeclarationKind.function,
          type: 'Future<void>',
          isAsync: true,
        ),
      ],
    ),
    AppEntryRole.fallbackStartScreenFile: const DartFileIndex(
      path: AppEntryRole.fallbackStartScreenFile,
      declarations: [
        IndexedDeclaration(
          name: 'FallbackStartScreen',
          kind: DeclarationKind.classType,
          constructors: [
            IndexedConstructor(
              isConst: true,
              parameters: [
                IndexedParameter('key', kind: ParameterKind.optionalNamed),
              ],
            ),
          ],
        ),
      ],
    ),
  };
}

List<SmfIssue> _check(Map<String, DartFileIndex> files) {
  final request = StructuralRuleRequest(
    hook: const RoleHookRequest(
      data: [],
      presentRoles: {appEntryRole},
      context: testContext,
    ),
    files: files,
    owners: {
      for (final path in files.keys)
        path: const ModuleOrigin(ModuleId('flutter_core')),
    },
  );
  return [
    ...appEntryRole.interface.checkSymbols(files),
    ...appEntryRole.checkStructure(request),
  ];
}

Map<String, String> _render<V extends Object>(
  SocketRef<KeyedSocket<V>> socket,
  List<(String, V)> entries,
) =>
    socket.render([
      for (final (key, value) in entries) socket.entry(key, value),
    ]);

void main() {
  group('AppEntryRole', () {
    test('is the one entry of every app', () {
      expect(appEntryRole.id, 'app_entry');
      expect(appEntryRole.description, 'App entry');
      expect(appEntryRole.cardinality, RoleCardinality.exactlyOne);
      expect(appEntryRole.requires, isEmpty);
      expect(appEntryRole.uses, isEmpty);
      expect(appEntryRole.template, isNull);
      expect(appEntryRole.options, isEmpty);
      expect(appEntryRole.presenceFlag, 'has_app_entry');
    });

    test('is open to every module', () {
      expect(appEntryRole.openToAllModules, isTrue);
    });

    test('has the projects of Android and iOS', () {
      expect(AppEntryRole.platforms, ['android', 'ios']);
      // Each native file is in the project of one of the platforms.
      for (final file in const [
        AppEntryRole.androidManifestFile,
        AppEntryRole.gradleSettingsFile,
        AppEntryRole.gradleAppFile,
        AppEntryRole.infoPlistFile,
        AppEntryRole.xcodeProjectFile,
      ]) {
        expect(AppEntryRole.platforms, contains(file.split('/').first));
      }
    });

    test('owns all its sockets, with valid and distinct tags', () {
      final sockets = appEntryRole.sockets;
      final tags = [for (final socket in sockets) ...socket.tags];

      expect(sockets, hasLength(17));
      for (final socket in sockets) {
        expect(socket.role, same(appEntryRole), reason: '$socket');
        expect(socket.problems(), isEmpty, reason: '$socket');
      }
      expect(tags.toSet(), hasLength(tags.length));
      expect(tags, contains('smf_app_entry__bootstrap_platform'));
      expect(tags, contains('smf_app_entry__root_wrappers_open'));
    });

    test('bootstrap phases are separate sockets in start-up order', () {
      expect(
        appEntryRole.sockets.take(4).map((socket) => socket.name),
        [
          'bootstrap_early',
          'bootstrap_platform',
          'bootstrap_di',
          'bootstrap_late',
        ],
      );
    });

    test('requires main(), bootstrap() and FallbackStartScreen', () {
      expect(
        appEntryRole.interface.symbols.map((symbol) => '$symbol'),
        [
          'function main()',
          'function bootstrap()',
          'class FallbackStartScreen',
        ],
      );
      expect(
        AppEntryRole.fallbackStartScreen.importRef.resolveUri('my_app'),
        'package:my_app/core/app/fallback_start_screen.dart',
      );
      expect(
        appEntryRole.structuralRules.map((rule) => rule.id),
        [
          'app_entry.bootstrap_without_material',
          'app_entry.main_sequence',
          'app_entry.native_keys',
        ],
      );
      expect(
        appEntryRole.moduleRules.map((rule) => rule.id),
        ['app_entry.bootstrap_phases', 'app_entry.tag_lines'],
      );
    });
  });

  group('AppEntryRole rules', () {
    test('accept a correct app', () {
      expect(_check(_app()), isEmpty);
    });

    test('report missing files through the required symbols only', () {
      final issues = _check(const {});

      expect(issues, hasLength(3));
      expect(
        issues.every((issue) => issue.message.contains('is missing')),
        isTrue,
      );
    });

    test('reject design libraries in bootstrap.dart', () {
      final issues = _check(
        _app(
          bootstrapImports: const [
            IndexedImport('package:flutter/material.dart'),
            IndexedImport('package:flutter/cupertino.dart'),
          ],
        ),
      );

      expect(issues, hasLength(2));
      expect(issues.first.path, AppEntryRole.bootstrapFile);
      expect(issues.first.origin, const ModuleOrigin(ModuleId('flutter_core')));
      expect(issues.first.hint, contains('widgets.dart'));
    });

    test('require the start-up sequence in main()', () {
      final issues = _check(
        _app(
          mainCalls: const [
            IndexedInvocation('bootstrap', enclosingDeclaration: 'main'),
            IndexedInvocation('runApp', enclosingDeclaration: 'other'),
          ],
        ),
      );

      expect(issues.map((issue) => issue.message), [
        'main() does not call WidgetsFlutterBinding.ensureInitialized().',
        'main() does not await bootstrap().',
        'main() does not call runApp().',
      ]);
      expect(issues.first.path, AppEntryRole.mainFile);
    });

    test('require a call of bootstrap() in main()', () {
      final issues = _check(
        _app(
          mainCalls: const [
            IndexedInvocation(
              'ensureInitialized',
              target: 'WidgetsFlutterBinding',
              enclosingDeclaration: 'main',
            ),
            IndexedInvocation('runApp', enclosingDeclaration: 'main'),
          ],
        ),
      );

      expect(issues.single.message, 'main() does not call bootstrap().');
    });

    test('require the calls in order', () {
      final issues = _check(
        _app(
          mainCalls: const [
            IndexedInvocation(
              'bootstrap',
              enclosingDeclaration: 'main',
              awaited: true,
              offset: 10,
            ),
            IndexedInvocation(
              'ensureInitialized',
              target: 'WidgetsFlutterBinding',
              enclosingDeclaration: 'main',
              offset: 20,
            ),
            IndexedInvocation(
              'runApp',
              enclosingDeclaration: 'main',
              offset: 30,
            ),
          ],
        ),
      );

      expect(issues.single.message, contains('in this order'));
    });

    test('ignore an ensureInitialized() of another target', () {
      final issues = _check(
        _app(
          mainCalls: const [
            IndexedInvocation(
              'ensureInitialized',
              target: 'SomethingElse',
              enclosingDeclaration: 'main',
            ),
            IndexedInvocation(
              'bootstrap',
              enclosingDeclaration: 'main',
              awaited: true,
            ),
            IndexedInvocation('runApp', enclosingDeclaration: 'main'),
          ],
        ),
      );

      expect(issues.single.message, contains('ensureInitialized'));
    });
  });

  group('AppEntryRole native sockets', () {
    test('the iOS deployment target is the highest version', () {
      const socket = AppEntryRole.iosDeploymentTarget;
      expect(
        socket.render([
          socket.value('13.0'),
          socket.value('15.0'),
          socket.value('14'),
        ]),
        {socket.tag: '15.0'},
      );
    });

    test('the iOS deployment target always has a value', () {
      const socket = AppEntryRole.iosDeploymentTarget;
      expect(() => socket.render(const []), throwsStateError);
      expect(
        socket.problemsWith(socket.value('fifteen')).single,
        contains('cannot be compared'),
      );
    });

    test('Android permissions are united', () {
      const socket = AppEntryRole.androidManifestPermissions;
      expect(
        socket.render([
          socket.key('android.permission.INTERNET'),
          socket.key('android.permission.CAMERA'),
          socket.key('android.permission.INTERNET'),
        ]),
        {
          socket.tag:
              '    <uses-permission android:name="android.permission.INTERNET"/>\n'
                  '    <uses-permission android:name="android.permission.CAMERA"/>',
        },
      );
    });

    test('Android meta-data must agree and is escaped', () {
      const socket = AppEntryRole.androidManifestApplicationMeta;

      expect(
        _render(socket, const [
          ('a.key', AndroidMetaData.value('x & "y"')),
          ('b.icon', AndroidMetaData.resource('@drawable/ic_notification')),
        ]),
        {
          socket.tag: '        <meta-data android:name="a.key" '
              'android:value="x &amp; &quot;y&quot;"/>\n'
              '        <meta-data android:name="b.icon" '
              'android:resource="@drawable/ic_notification"/>',
        },
      );
      expect(
        _render(socket, const [
          ('a.key', AndroidMetaData.value('x')),
          ('a.key', AndroidMetaData.value('x')),
        ]),
        hasLength(1),
      );
      expect(
        () => _render(socket, const [
          ('a.key', AndroidMetaData.value('x')),
          ('a.key', AndroidMetaData.resource('x')),
        ]),
        throwsA(isA<MergeConflict>()),
      );
    });

    test('intent filters are XML without imports', () {
      const socket = AppEntryRole.mainActivityIntentFilters;
      const filter = '<intent-filter>\n'
          '    <action android:name="android.intent.action.VIEW"/>\n'
          '</intent-filter>';

      expect(socket.kind.carriesImports, isFalse);
      expect(
        socket
            .render(const [SocketContribution.code(socket, Fragment(filter))]),
        {socket.tag: filter},
      );
      expect(
        socket.problemsWith(
          const SocketContribution.code(
            socket,
            Fragment(filter, imports: [ImportRef('dart:io')]),
          ),
        ),
        isNotEmpty,
      );
    });

    test('Info.plist unites string arrays and keeps scalars unique', () {
      const socket = AppEntryRole.infoPlist;

      expect(
        _render(socket, const [
          ('UIBackgroundModes', PlistStringArray(['fetch'])),
          ('NSCameraUsageDescription', PlistString('Scan <codes>')),
          ('UIBackgroundModes', PlistStringArray(['fetch', 'audio'])),
          ('UIStatusBarHidden', PlistBoolean(false)),
          ('Retries', PlistInteger(3)),
          ('Retries', PlistInteger(3)),
        ]),
        {
          socket.tag: [
            '\t<key>UIBackgroundModes</key>',
            '\t<array>',
            '\t\t<string>fetch</string>',
            '\t\t<string>audio</string>',
            '\t</array>',
            '\t<key>NSCameraUsageDescription</key>',
            '\t<string>Scan &lt;codes&gt;</string>',
            '\t<key>UIStatusBarHidden</key>',
            '\t<false/>',
            '\t<key>Retries</key>',
            '\t<integer>3</integer>',
          ].join('\n'),
        },
      );
      expect(
        () => _render(socket, const [
          ('UIStatusBarHidden', PlistBoolean(true)),
          ('UIStatusBarHidden', PlistBoolean(false)),
        ]),
        throwsA(isA<MergeConflict>()),
      );
      expect(
        () => _render(socket, const [
          ('UIBackgroundModes', PlistStringArray(['fetch'])),
          ('UIBackgroundModes', PlistString('fetch')),
        ]),
        throwsA(isA<MergeConflict>()),
      );
    });

    test('Gradle plugins and dependencies take the highest version', () {
      expect(
        _render(AppEntryRole.gradleSettingsPlugins, const [
          ('io.github.ben-manes.versions', '0.63.0'),
          ('io.github.ben-manes.versions', '0.64.0'),
        ]),
        {
          AppEntryRole.gradleSettingsPlugins.tag:
              '    id("io.github.ben-manes.versions") version("0.64.0") '
                  'apply false',
        },
      );
      expect(
        AppEntryRole.gradleAppPlugins.render([
          AppEntryRole.gradleAppPlugins.key('io.github.ben-manes.versions'),
        ]),
        {
          AppEntryRole.gradleAppPlugins.tag:
              '    id("io.github.ben-manes.versions")',
        },
      );
      expect(
        _render(AppEntryRole.gradleAppDependencies, const [
          (r'com.example:lib$x', '1.0'),
          (r'com.example:lib$x', '1.2'),
        ]),
        {
          AppEntryRole.gradleAppDependencies.tag:
              r'    implementation("com.example:lib\$x:1.2")',
        },
      );
    });

    test('README sections follow each other under their headings', () {
      const socket = AppEntryRole.readmeSections;

      expect(socket.kind.carriesImports, isFalse);
      expect(
        _render(socket, const [
          ('Firebase', 'Run `flutterfire configure`.\n'),
          ('Signing', 'The keys go into `android/key.properties`.'),
          ('Firebase', 'Run `flutterfire configure`.\n'),
        ]),
        {
          socket.tag: '\n## Firebase\n\nRun `flutterfire configure`.\n'
              '\n## Signing\n\nThe keys go into `android/key.properties`.',
        },
      );
      expect(
        () => _render(socket, const [
          ('Firebase', 'One text.'),
          ('Firebase', 'Another text.'),
        ]),
        throwsA(isA<MergeConflict>()),
      );
    });

    test('a README section has a heading of one line and text', () {
      const socket = AppEntryRole.readmeSections;

      expect(socket.problemsWith(socket.entry('Firebase', 'Text.')), isEmpty);
      for (final heading in ['', ' Firebase', 'Fire\nbase', 'Fire\rbase']) {
        expect(
          socket.problemsWith(socket.entry(heading, 'Text.')).single,
          'The heading "$heading" of a section of the README is not one line '
          'of text without spaces around it.',
          reason: heading,
        );
      }
      expect(
        socket.problemsWith(socket.entry('Firebase', ' \n')),
        ['The section "Firebase" of the README has no text.'],
      );
    });
  });

  group('AppEntryRole native checks', () {
    List<SmfIssue> checkTexts(Map<String, String> texts) =>
        appEntryRole.checkStructure(
          StructuralRuleRequest(
            hook: const RoleHookRequest(
              data: [],
              presentRoles: {appEntryRole},
              context: testContext,
            ),
            files: const {},
            texts: texts,
            owners: {
              for (final path in texts.keys)
                path: const ModuleOrigin(ModuleId('flutter_core')),
            },
          ),
        );

    List<String> messages(List<SmfIssue> issues) =>
        [for (final issue in issues) issue.message];

    test('accept native files that name every key once', () {
      expect(
        messages(
          checkTexts({
            AppEntryRole.infoPlistFile: _plist,
            AppEntryRole.androidManifestFile: _manifest,
            AppEntryRole.gradleSettingsFile: _settings,
            AppEntryRole.gradleAppFile: _appGradle,
          }),
        ),
        isEmpty,
      );
    });

    test('report a key of Info.plist that the dictionary has twice', () {
      final issues = checkTexts({
        AppEntryRole.infoPlistFile: _plist.replaceFirst(
          '</dict>\n</plist>',
          '\t<key>CFBundleName</key>\n\t<string>Again</string>\n'
              '</dict>\n</plist>',
        ),
      });

      expect(messages(issues), [
        'ios/Runner/Info.plist has the key CFBundleName more than once.',
      ]);
      expect(
        issues.single.origin,
        const ModuleOrigin(ModuleId('flutter_core')),
      );
      expect(issues.single.path, AppEntryRole.infoPlistFile);
    });

    test('report permissions and meta-data of the application twice', () {
      final manifest = _manifest
          .replaceFirst(
            '    <application',
            '    <uses-permission android:name="android.permission.CAMERA"/>\n'
                '    <application',
          )
          .replaceFirst(
            '    </application>',
            '        <meta-data android:name="flutterEmbedding" '
                'android:value="2"/>\n'
                '    </application>',
          );

      expect(
        messages(checkTexts({AppEntryRole.androidManifestFile: manifest})),
        [
          equals(
            'android/app/src/main/AndroidManifest.xml has the permission '
            'android.permission.CAMERA more than once.',
          ),
          equals(
            'android/app/src/main/AndroidManifest.xml has the meta-data '
            'flutterEmbedding more than once.',
          ),
        ],
      );
    });

    test('tell the meta-data of an activity from those of the application', () {
      final manifest = _manifest.replaceFirst(
        '        </activity>',
        '            <meta-data android:name="flutterEmbedding" '
            'android:value="2"/>\n'
            '        </activity>',
      );

      expect(
        messages(checkTexts({AppEntryRole.androidManifestFile: manifest})),
        isEmpty,
      );
    });

    test('report a plugin that a plugins block has twice', () {
      final issues = checkTexts({
        AppEntryRole.gradleSettingsFile: _settings.replaceFirst(
          '2.3.20" apply false\n',
          '2.3.20" apply false\n'
              '    id("org.jetbrains.kotlin.android") version("2.3.21") '
              'apply false\n',
        ),
        AppEntryRole.gradleAppFile:
            '$_appGradle\nplugins {\n    id("com.android.application")\n}\n',
      });

      expect(messages(issues), [
        equals(
          'android/settings.gradle.kts has the plugin '
          'org.jetbrains.kotlin.android more than once.',
        ),
      ]);
    });

    test('read no key out of comments', () {
      expect(
        messages(
          checkTexts({
            AppEntryRole.infoPlistFile: _plist.replaceFirst(
              '</dict>',
              '<!-- <key>CFBundleName</key> -->\n</dict>',
            ),
            AppEntryRole.androidManifestFile: _manifest.replaceFirst(
              '    </application>',
              '        <!-- <meta-data android:name="flutterEmbedding"/> -->\n'
                  '    </application>',
            ),
            AppEntryRole.gradleSettingsFile: _settings.replaceFirst(
              '\n}',
              '\n    // id("com.android.application")\n}',
            ),
          }),
        ),
        isEmpty,
      );
    });

    List<SmfIssue> checkModule(Map<String, String> templates) =>
        appEntryRole.checkModule(
          ModuleRuleRequest(
            hook: const RoleHookRequest(
              data: [],
              presentRoles: {appEntryRole},
              context: testContext,
            ),
            module: const ModuleDescriptor(
              id: ModuleId('scaffold'),
              description: 'Scaffold',
              kind: ModuleKinds.scaffold,
              providers: [RoleProvider.plain(appEntryRole)],
            ),
            contributions: [BrickContribution(_bundle(templates))],
          ),
        );

    const bootstrap = '''
Future<void> bootstrap() async {
{{{smf_app_entry__bootstrap_early}}}
{{{smf_app_entry__bootstrap_platform}}}
{{{smf_app_entry__bootstrap_di}}}
{{{smf_app_entry__bootstrap_late}}}
}
''';

    test('module rules accept the tags of a provider in place', () {
      expect(
        checkModule({
          AppEntryRole.bootstrapFile: bootstrap,
          AppEntryRole.androidManifestFile: _manifestTemplate,
          AppEntryRole.infoPlistFile:
              '<dict>\n{{{smf_app_entry__info_plist}}}\n</dict>\n',
          AppEntryRole.gradleSettingsFile:
              'plugins {\n{{{smf_app_entry__gradle_settings_plugins}}}\n}\n',
          AppEntryRole.gradleAppFile: 'plugins {\n'
              '{{{smf_app_entry__gradle_app_plugins}}}\n}\n\n'
              'dependencies {\n'
              '{{{smf_app_entry__gradle_app_dependencies}}}\n}\n',
          AppEntryRole.readmeFile: '# {{app_name}}\n\nAn app.\n'
              '{{{smf_app_entry__readme_sections}}}\n',
        }),
        isEmpty,
      );
    });

    test('the phases of start-up are in order in bootstrap.dart', () {
      final swapped = bootstrap
          .replaceFirst('bootstrap_early', 'bootstrap_x')
          .replaceFirst('bootstrap_late', 'bootstrap_early')
          .replaceFirst('bootstrap_x', 'bootstrap_late');
      final issues = checkModule({AppEntryRole.bootstrapFile: swapped});

      expect(issues.map((issue) => issue.message), [
        equals(
          'The tags of the phases of start-up in lib/bootstrap.dart are not '
          'in the order early, platform, di, late.',
        ),
      ]);
      expect(issues.single.origin, const ModuleOrigin(ModuleId('scaffold')));

      final moved = checkModule({
        AppEntryRole.bootstrapFile:
            bootstrap.replaceFirst('{{{smf_app_entry__bootstrap_late}}}', ''),
        'lib/late.dart': '{{{smf_app_entry__bootstrap_late}}}\n',
      });
      expect(moved.map((issue) => issue.message), [
        equals(
          'The tag {{{smf_app_entry__bootstrap_late}}} is not in '
          'lib/bootstrap.dart, where bootstrap() runs the phases of '
          'start-up.',
        ),
      ]);
    });

    test('line tags stand alone at the start of a line of their file', () {
      final issues = checkModule({
        AppEntryRole.androidManifestFile: _manifestTemplate.replaceFirst(
          '\n{{{smf_app_entry__android_manifest_permissions}}}',
          '    {{{smf_app_entry__android_manifest_permissions}}}',
        ),
        'ios/Podfile': '{{{smf_app_entry__info_plist}}}\n',
        AppEntryRole.readmeFile:
            '# {{app_name}}\n\nAn app. {{{smf_app_entry__readme_sections}}}\n',
      });

      expect(issues.map((issue) => issue.message), [
        equals(
          'The tag {{{smf_app_entry__android_manifest_permissions}}} must '
          'stand alone at the start of a line of '
          'android/app/src/main/AndroidManifest.xml, because its '
          'contributions render as complete lines.',
        ),
        equals(
          'The tag {{{smf_app_entry__info_plist}}} is in ios/Podfile, but its '
          'lines belong in ios/Runner/Info.plist.',
        ),
        equals(
          'The tag {{{smf_app_entry__readme_sections}}} must stand alone at '
          'the start of a line of README.md, because its contributions render '
          'as complete lines.',
        ),
      ]);
    });

    test('the Gradle sockets refuse the plugins every app declares', () {
      expect(
        AppEntryRole.gradleAppPlugins.problemsWith(
          AppEntryRole.gradleAppPlugins.key('org.jetbrains.kotlin.android'),
        ),
        [
          equals(
            'socket app_entry.gradle_app_plugins does not take '
            'org.jetbrains.kotlin.android: the Flutter Gradle plugin applies '
            'the Kotlin plugin itself.',
          ),
        ],
      );
      expect(
        AppEntryRole.gradleSettingsPlugins.problemsWith(
          AppEntryRole.gradleSettingsPlugins
              .entry('com.android.application', '9.1.0'),
        ),
        [
          equals(
            'socket app_entry.gradle_settings_plugins does not take '
            'com.android.application: the provider of the app entry declares '
            'it.',
          ),
        ],
      );
      expect(
        AppEntryRole.gradleAppPlugins.problemsWith(
          AppEntryRole.gradleAppPlugins.key('io.github.ben-manes.versions'),
        ),
        isEmpty,
      );
    });
  });

  test('AndroidMetaData compares by kind and text', () {
    const value = AndroidMetaData.value('a');

    expect(value, const AndroidMetaData.value('a'));
    expect(value.hashCode, const AndroidMetaData.value('a').hashCode);
    expect(value, isNot(const AndroidMetaData.resource('a')));
    expect(value.isResource, isFalse);
    expect(value.text, 'a');
    expect('$value', 'android:value="a"');
    expect(
      '${const AndroidMetaData.resource('@color/accent')}',
      'android:resource="@color/accent"',
    );
  });

  group('PlistValue', () {
    test('compares by value', () {
      expect(const PlistString('a'), const PlistString('a'));
      expect(const PlistString('a').hashCode, const PlistString('a').hashCode);
      expect(const PlistString('a'), isNot(const PlistString('b')));
      expect(const PlistBoolean(true), const PlistBoolean(true));
      expect(const PlistBoolean(true).hashCode, true.hashCode);
      expect(const PlistInteger(1), const PlistInteger(1));
      expect(const PlistInteger(1).hashCode, 1.hashCode);
      expect(
        const PlistStringArray(['a', 'b']),
        const PlistStringArray(['a', 'b']),
      );
      expect(
        const PlistStringArray(['a']).hashCode,
        const PlistStringArray(['a']).hashCode,
      );
      expect(
        const PlistStringArray(['a', 'b']),
        isNot(const PlistStringArray(['b', 'a'])),
      );
      expect(
        const PlistStringArray(['a']),
        isNot(const PlistStringArray(['a', 'b'])),
      );
      expect(
        const PlistStringArray(['fetch', 'fetch']).toXml(''),
        '<array>\n\t<string>fetch</string>\n</array>',
      );
      expect(const PlistStringArray(['a']), isNot(const PlistString('a')));
    });

    test('describes itself', () {
      expect('${const PlistString('a')}', 'a');
      expect('${const PlistBoolean(true)}', 'true');
      expect('${const PlistInteger(2)}', '2');
      expect('${const PlistStringArray(['a'])}', '[a]');
      expect(const PlistMergePolicy().name, 'plist');
    });
  });

  test('the scaffold kind provides the app entry', () {
    expect(ModuleKinds.scaffold.id, 'scaffold');
    expect(ModuleKinds.scaffold.label, 'App scaffold');
    expect(ModuleKinds.scaffold.mustProvide, {appEntryRole});
  });
}

/// An `Info.plist` like the one of `flutter create`, shortened.
const _plist = '''
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>CFBundleName</key>
	<string>MyApp</string>
	<key>UIApplicationSceneManifest</key>
	<dict>
		<key>UISceneConfigurations</key>
		<dict>
			<key>UIWindowSceneSessionRoleApplication</key>
			<array>
				<dict>
					<key>UISceneClassName</key>
					<string>UIWindowScene</string>
				</dict>
				<dict>
					<key>UISceneClassName</key>
					<string>UIWindowScene</string>
				</dict>
			</array>
		</dict>
	</dict>
	<key>UISupportedInterfaceOrientations</key>
	<array>
		<string>UIInterfaceOrientationPortrait</string>
	</array>
	<key>CADisableMinimumFrameDurationOnPhone</key>
	<true/>
</dict>
</plist>
''';

/// An Android manifest like the one of `flutter create`, shortened.
const _manifest = r'''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA"/>
    <application
        android:label="My App"
        android:name="${applicationName}">
        <activity
            android:name=".MainActivity"
            android:exported="true">
            <meta-data
              android:name="io.flutter.embedding.android.NormalTheme"
              android:resource="@style/NormalTheme"
              />
        </activity>
        <!-- Don't delete the meta-data below. -->
        <meta-data
            android:name="flutterEmbedding"
            android:value="2" />
    </application>
</manifest>
''';

/// The manifest of a provider, with the tags of its sockets.
const _manifestTemplate = '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
{{{smf_app_entry__android_manifest_permissions}}}
    <application>
        <activity android:name=".MainActivity">
{{{smf_app_entry__main_activity_intent_filters}}}
        </activity>
{{{smf_app_entry__android_manifest_application_meta}}}
    </application>
</manifest>
''';

/// The Gradle settings of `flutter create` 3.44, shortened.
const _settings = '''
pluginManagement {
    repositories {
        google()
    }
}

plugins {
    id("dev.flutter.flutter-plugin-loader") version "1.0.0"
    id("com.android.application") version "9.0.1" apply false
    id("org.jetbrains.kotlin.android") version "2.3.20" apply false
}
''';

/// The build script of the app module of `flutter create` 3.44, shortened.
const _appGradle = '''
plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}
''';

MasonBundle _bundle(Map<String, String> files) => MasonBundle(
      name: 'scaffold',
      description: 'scaffold',
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in files.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
      ],
    );
