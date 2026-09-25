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

    test('owns all its sockets, with valid and distinct tags', () {
      final sockets = appEntryRole.sockets;
      final tags = [for (final socket in sockets) ...socket.tags];

      expect(sockets, hasLength(16));
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
        ['app_entry.bootstrap_without_material', 'app_entry.main_sequence'],
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
          ('com.google.gms.google-services', '4.3.15'),
          ('com.google.gms.google-services', '4.4.2'),
        ]),
        {
          AppEntryRole.gradleSettingsPlugins.tag:
              '    id("com.google.gms.google-services") version("4.4.2") '
                  'apply false',
        },
      );
      expect(
        AppEntryRole.gradleAppPlugins.render([
          AppEntryRole.gradleAppPlugins.key('com.google.gms.google-services'),
        ]),
        {
          AppEntryRole.gradleAppPlugins.tag:
              '    id("com.google.gms.google-services")',
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

    test('Gradle settings plugins keep the anchor flutterfire looks for', () {
      // `kotlinGoogleServicesPluginPattern` of flutterfire_cli 1.4.0
      // (lib/src/firebase/firebase_android_writes.dart). flutterfire inserts
      // the Crashlytics plugin after the line it matches.
      final anchor = RegExp(
        r'''id\((["']com\.google\.gms\.google-services["'])\) '''
        r'''version\((["']\d+\.\d+\.\d+["'])\) apply false''',
      );
      final rendered = _render(AppEntryRole.gradleSettingsPlugins, const [
        ('com.google.gms.google-services', '4.4.2'),
      ]);

      expect(rendered.values.single, matches(anchor));
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
