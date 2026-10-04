import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'role_support.dart';
import 'support.dart';

/// The file of the provider with the root widget of the app.
const _appFile = 'lib/app.dart';

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
  List<IndexedInvocation> appCalls = const [
    IndexedInvocation(
      'router',
      target: 'MaterialApp',
      enclosingDeclaration: 'App',
    ),
  ],
}) {
  return {
    _appFile: DartFileIndex(path: _appFile, invocations: appCalls),
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

/// Checks [files] of an app whose app entry flutter_core provides; it owns
/// each file, unless [owners] names another owner.
List<SmfIssue> _check(
  Map<String, DartFileIndex> files, {
  Map<String, ContributionOrigin> owners = const {},
}) {
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
      ...owners,
    },
    modules: const [
      ModuleDescriptor(
        id: ModuleId('flutter_core'),
        description: 'Flutter core',
        kind: ModuleKinds.scaffold,
        providers: [RoleProvider.plain(appEntryRole)],
      ),
      ModuleDescriptor(
        id: ModuleId('home'),
        description: 'Home',
        kind: ModuleKinds.feature,
      ),
    ],
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
      expect(appEntryRole.options, isEmpty);
      expect(appEntryRole.presenceFlag, 'has_app_entry');
    });

    test('is open to every module', () {
      expect(appEntryRole.openToAllModules, isTrue);
    });

    test('has its native files in the projects of Android and iOS', () {
      // The directory of each project has the name of its platform in
      // AppIdentity.platforms, which is that of flutter create --platforms.
      final projects = {
        for (final file in const [
          AppEntryRole.androidManifestFile,
          AppEntryRole.gradleSettingsFile,
          AppEntryRole.gradleAppFile,
          AppEntryRole.infoPlistFile,
          AppEntryRole.xcodeProjectFile,
        ])
          file.split('/').first,
      };

      expect(projects, {'android', 'ios'});
    });

    test('owns all its sockets, with valid and distinct tags', () {
      final sockets = appEntryRole.sockets;
      final tags = [for (final socket in sockets) ...socket.tags];

      expect(sockets, hasLength(18));
      for (final socket in sockets) {
        expect(socket.role, same(appEntryRole), reason: '$socket');
        expect(socket.problems(), isEmpty, reason: '$socket');
      }
      expect(tags.toSet(), hasLength(tags.length));
      expect(tags, contains('smf_app_entry__bootstrap_platform'));
      expect(tags, contains('smf_app_entry__root_wrappers_open'));
      expect(tags, contains('smf_app_entry__agent_sections'));
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
          'app_entry.material_root',
          'app_entry.native_keys',
          'app_entry.agent_guide_paths',
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

    test('require a MaterialApp at the root of the app', () {
      final issues = _check(
        _app(
          appCalls: const [
            IndexedInvocation('CupertinoApp', enclosingDeclaration: 'App'),
          ],
        ),
      );

      expect(issues.map((issue) => issue.message), [
        equals(
          'The root of the app must be a MaterialApp, but the module '
          'flutter_core creates none in lib/.',
        ),
      ]);
      expect(
        issues.single.origin,
        const ModuleOrigin(ModuleId('flutter_core')),
      );
      expect(issues.single.hint, contains('MaterialApp.router'));
    });

    test('accept a MaterialApp or a MaterialApp.router at the root', () {
      expect(
        _check(_app(appCalls: const [IndexedInvocation('MaterialApp')])),
        isEmpty,
      );
      // The index records MaterialApp.router() as router() on MaterialApp.
      expect(
        _check(
          _app(
            appCalls: const [
              IndexedInvocation('router', target: 'MaterialApp'),
            ],
          ),
        ),
        isEmpty,
      );
    });

    test('count only a MaterialApp that the provider creates in lib/', () {
      const material = [IndexedInvocation('MaterialApp')];
      const screen = 'lib/features/home/home_screen.dart';
      final issues = _check(
        {
          ..._app(
            appCalls: const [
              IndexedInvocation('router', target: 'CupertinoApp'),
            ],
          ),
          // A widget test of the provider, outside lib/.
          'test/app_test.dart': const DartFileIndex(
            path: 'test/app_test.dart',
            invocations: material,
          ),
          screen: const DartFileIndex(path: screen, invocations: material),
          RouterRole.appRouterFile: const DartFileIndex(
            path: RouterRole.appRouterFile,
            invocations: material,
          ),
        },
        owners: {
          screen: const ModuleOrigin(ModuleId('home')),
          RouterRole.appRouterFile: const RoleTemplateOrigin(routerRole),
        },
      );

      expect(issues.map((issue) => issue.message), [
        contains('must be a MaterialApp'),
      ]);
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
      // In the order of the contributions, not of the headings.
      expect(
        _render(socket, const [
          ('Signing', 'The keys go into `android/key.properties`.'),
          ('Firebase', 'Run `flutterfire configure`.\n'),
          ('Signing', 'The keys go into `android/key.properties`.'),
        ]),
        {
          socket.tag: '\n## Signing\n\nThe keys go into '
              '`android/key.properties`.\n'
              '\n## Firebase\n\nRun `flutterfire configure`.',
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
      // mason drops the backslash of a line break of Markdown.
      for (final (heading, text) in [
        ('Firebase', 'One line\\\nand another.'),
        (r'Fire\é', 'Text.'),
      ]) {
        expect(
          socket.problemsWith(socket.entry(heading, text)).single,
          'The section "$heading" of the README has a backslash before a line '
          'break or a non-ASCII character, which mason removes; for a line '
          'break in Markdown, end the line with two spaces instead.',
          reason: text,
        );
      }
    });
  });

  group('the guide for coding agents', () {
    const socket = AppEntryRole.agentSections;

    /// The problems of the note [text] under [heading].
    List<String> problemsOf(String text, {String heading = 'Router'}) =>
        socket.problemsWith(socket.entry(heading, AgentNote(text)));

    test('is AGENTS.md, with a CLAUDE.md that reads it', () {
      expect(AppEntryRole.agentsFile, 'AGENTS.md');
      expect(AppEntryRole.claudeFile, 'CLAUDE.md');
      expect(
        appEntryRole.interface.files,
        [AppEntryRole.agentsFile, AppEntryRole.claudeFile],
      );
      expect(socket.tag, 'smf_app_entry__agent_sections');
      expect(socket.kind.carriesImports, isFalse);
    });

    test(
        'comes from the template of the role, whose brick has the tag of '
        'the sections alone on a line', () {
      final brick = appEntryRole.template
          .contribute(testContext)
          .whereType<BrickContribution>()
          .single;
      final templates = {
        for (final file in brick.bundle.files)
          file.path: utf8.decode(base64.decode(file.data)),
      };

      expect(brick.bundle.name, 'app_entry_role');
      expect(
        templates.keys,
        [AppEntryRole.agentsFile, AppEntryRole.claudeFile],
      );
      expect(templates[AppEntryRole.claudeFile], '@AGENTS.md\n');
      final lines = templates[AppEntryRole.agentsFile]!.split('\n');
      expect(lines.first, '# AGENTS.md');
      // The sections render as complete lines after the introduction.
      expect(lines.where((line) => line.contains('{{')), [
        '{{{${socket.tag}}}}',
      ]);
      expect(lines.sublist(lines.length - 2), ['{{{${socket.tag}}}}', '']);
    });

    test('has the section of the role in every app, as what the role says', () {
      final note = appEntryRole.template
          .contribute(testContext)
          .whereType<SocketContribution>()
          .single;

      expect(note.socket, socket);
      expect(note.entryKey, appEntryRole.description);
      expect(note.when, isEmpty);
      expect((note.entryValue! as AgentNote).isOfRole, isTrue);
      expect(socket.problemsWith(note), isEmpty);
    });

    test('renders with the section of the role after its introduction',
        () async {
      final rendered = await renderTemplate(appEntryRole);
      final guide = rendered.files[AppEntryRole.agentsFile]!;
      final note = appEntryRole.template
          .contribute(testContext)
          .whereType<SocketContribution>()
          .single
          .entryValue! as AgentNote;

      expect(rendered.files.keys, [
        AppEntryRole.agentsFile,
        AppEntryRole.claudeFile,
      ]);
      expect(rendered.files[AppEntryRole.claudeFile], '@AGENTS.md\n');
      expect(rendered.elsewhere, isEmpty);
      final [title, empty, introduction, ...sections] = guide.split('\n');
      expect(title, '# AGENTS.md');
      expect(empty, isEmpty);
      expect(introduction, startsWith('Guidance for coding agents'));
      expect(introduction, contains('[README.md](README.md)'));
      expect(
        sections.join('\n'),
        '\n## App entry\n\n${note.text}\n',
      );
    });

    test(
        'has the section of the app entry first, then the others in the '
        'order of their headings', () {
      expect(
        _render(socket, [
          ('Router', AgentNote('Routes.')),
          ('App entry', AgentNote('Start-up.')),
          ('Analytics', AgentNote('\nEvents.\n')),
        ]),
        {
          socket.tag: '\n## App entry\n\nStart-up.\n'
              '\n## Analytics\n\nEvents.\n'
              '\n## Router\n\nRoutes.',
        },
      );
    });

    test(
        'unites the notes of a section: those of roles first, then the '
        'others in the order of the contributions, each once', () {
      expect(
        _render(socket, [
          ('Router', AgentNote('With a package: its routes.')),
          ('Router', AgentNote.ofRole('Navigate through the facade.')),
          ('Router', AgentNote('A listener of the screen.')),
          ('Router', AgentNote('With a package: its routes.')),
          ('Router', AgentNote.ofRole('Navigate through the facade.')),
        ]),
        {
          socket.tag: '\n## Router\n\n'
              'Navigate through the facade.\n\n'
              'With a package: its routes.\n\n'
              'A listener of the screen.',
        },
      );
      // The same text as a note of a role and of a module is two notes.
      final united = socket.kind
          .merge([
            socket.entry('Router', AgentNote('The same.')),
            socket.entry('Router', AgentNote.ofRole('The same.')),
          ])
          .single
          .value;
      expect(united.text, 'The same.\n\nThe same.');
      expect(united.isOfRole, isFalse);
      expect(
        socket.kind
            .merge([
              socket.entry('Router', AgentNote.ofRole('One.')),
              socket.entry('Router', AgentNote.ofRole('Another.')),
            ])
            .single
            .value
            .isOfRole,
        isTrue,
      );
    });

    test('a note compares by its text and by whether a role says it', () {
      final note = AgentNote('Text.');

      expect(note, AgentNote('Text.'));
      expect(note.hashCode, AgentNote('Text.').hashCode);
      expect(note, isNot(AgentNote('Another text.')));
      expect(note, isNot(AgentNote.ofRole('Text.')));
      expect(AgentNote.ofRole('Text.'), AgentNote.ofRole('Text.'));
      expect('Text.', isNot(note));
      expect(note.isOfRole, isFalse);
      expect(AgentNote.ofRole('Text.').isOfRole, isTrue);
      expect(AgentNote('\n Text.\n\n').text, 'Text.');
      expect('$note', 'Text.');
    });

    test('a section has a heading of one line', () {
      expect(problemsOf('Text.'), isEmpty);
      for (final heading in ['', ' Router', 'Rou\nter', 'Rou\rter']) {
        expect(
          problemsOf('Text.', heading: heading).single,
          'The heading "$heading" of a section of the guide for coding '
          'agents is not one line of text without spaces around it.',
          reason: heading,
        );
      }
    });

    test('a note has text that mason keeps as it is', () {
      for (final text in ['', ' \n']) {
        expect(
          problemsOf(text).single,
          'A note of the section "Router" of the guide for coding agents has '
          'no text.',
          reason: text,
        );
      }
      // mason drops the backslash of a line break of Markdown, also the one
      // that ends a note or a heading, before the line break that follows.
      for (final (heading, text) in [
        ('Router', 'One line\\\nand another.'),
        ('Router', r'It ends with a backslash\'),
        (r'Rou\é', 'Text.'),
        (r'Router\', 'Text.'),
      ]) {
        expect(
          problemsOf(text, heading: heading).single,
          'A note of the section "$heading" of the guide for coding agents '
          'has a backslash before a line break or a non-ASCII character, '
          'which mason removes; for a line break in Markdown, end the line '
          'with two spaces instead.',
          reason: '$heading: $text',
        );
      }
      expect(problemsOf(r'A path of Windows, C:\Users, in a line.'), isEmpty);
    });

    test('a note starts neither a title nor another section', () {
      for (final text in [
        '# Title',
        'Text.\n## Section\nMore text.',
        '   ## Indented by three spaces',
        'Text.\n#',
        '#\tTitle after a tab',
        // Not a fenced code block: a code span of three backticks.
        '```dart``` is a language.\n## Section',
      ]) {
        expect(
          problemsOf(text).single,
          'A note of the section "Router" of the guide for coding agents '
          'has a line that starts with "# " or "## " outside a fenced code '
          'block, which starts a title or another section; a note stays in '
          'its section.',
          reason: text,
        );
      }
      for (final text in [
        '### Details\n\nText.',
        '#hashtag',
        'Text with # in a line.',
        'Text.\n\n    ## In a code block by its indentation',
        '```bash\n# A comment of a script\n```',
        '~~~\n## In a block of tildes\n~~~',
        // A block ends with as many of its characters, or more.
        '````\n```\n# In the block still\n`````\nText.',
      ]) {
        expect(problemsOf(text), isEmpty, reason: text);
      }
    });

    test('a note closes its fenced code blocks', () {
      for (final text in [
        '```bash\nflutter test',
        'Text.\n\n~~~\ncode\n```',
        '````\ncode\n```',
        // A line with more than the characters of the block does not close
        // it.
        '```\ncode\n```dart',
      ]) {
        expect(
          problemsOf(text).single,
          'A note of the section "Router" of the guide for coding agents '
          'does not close a fenced code block, which would take in the '
          'sections after it.',
          reason: text,
        );
      }
      for (final text in [
        '```bash\nflutter test\n```',
        '  ```\n  code\n  ```  ',
        '~~~\ncode\n~~~~\nText.',
      ]) {
        expect(problemsOf(text), isEmpty, reason: text);
      }
    });
  });

  group('the paths of the guide for coding agents', () {
    const guide = AppEntryRole.agentsFile;

    /// What the rules of the role find in an app with [files] and the guide
    /// [text].
    List<SmfIssue> check(
      String text, {
      List<String> files = const [
        'README.md',
        'pubspec.yaml',
        'lib/main.dart',
        'lib/core/app/fallback_start_screen.dart',
        'android/app/build.gradle.kts',
        'ios/Runner/Info.plist',
      ],
    }) =>
        appEntryRole.checkStructure(
          StructuralRuleRequest(
            hook: const RoleHookRequest(
              data: [],
              presentRoles: {appEntryRole},
              context: testContext,
            ),
            files: const {},
            texts: {guide: text},
            owners: {
              guide: const RoleTemplateOrigin(appEntryRole),
              for (final path in files)
                path: const ModuleOrigin(ModuleId('flutter_core')),
            },
          ),
        );

    List<String> messages(List<SmfIssue> issues) =>
        [for (final issue in issues) issue.message];

    test('are files and directories of the app', () {
      expect(
        check('''
# AGENTS.md

The introduction names `README.md` and `lib/main.dart`.

## App entry

- `lib/main.dart` has `main()`, and `lib/core/app/` the screens of the app.
- `lib/core` and `android/` are directories, and so is `ios/Runner`.
- `ios/Runner/Info.plist` and `android/app/build.gradle.kts` are native.
'''),
        isEmpty,
      );
    });

    test(
        'that the app does not have are reported under the heading of their '
        'section, on the owner of the guide', () {
      final issues = check('''
# AGENTS.md

## Liar

The screens are in `lib/liar/missing.dart`, next to `lib/core/missing/`.

- A tool writes `android/app/google-services.json` later.
''');

      expect(messages(issues), [
        equals(
          'The section "Liar" of AGENTS.md names `lib/liar/missing.dart`, but '
          'the app has no such file or directory.',
        ),
        equals(
          'The section "Liar" of AGENTS.md names `lib/core/missing/`, but the '
          'app has no such file or directory.',
        ),
        equals(
          'The section "Liar" of AGENTS.md names '
          '`android/app/google-services.json`, but the app has no such file '
          'or directory.',
        ),
      ]);
      for (final issue in issues) {
        expect(issue.isError, isTrue);
        expect(issue.path, guide);
        expect(issue.origin, const RoleTemplateOrigin(appEntryRole));
        expect(
          issue.hint,
          allOf(
            contains('with the role of the file in its when'),
            contains('*'),
          ),
        );
      }
    });

    test('of Dart files start at the root of the app', () {
      final issues = check('''
## Router

The routes are in `core/router/navigation.dart`, and `main()` in `main.dart`
or `./lib/main.dart`.
''');

      expect(messages(issues), [
        for (final path in [
          'core/router/navigation.dart',
          'main.dart',
          './lib/main.dart',
        ])
          equals(
            'The section "Router" of AGENTS.md names the Dart file `$path` '
            'without its path from the root of the app.',
          ),
      ]);
      expect(
        issues.first.hint,
        'Write the path from the root of the app, such as lib/main.dart.',
      );
      expect(issues.first.origin, const RoleTemplateOrigin(appEntryRole));
    });

    test('are told from what is no path of the app', () {
      expect(
        check('''
## Router

- A pattern: `lib/features/<feature>/`, `lib/core/*/`, `test/<path>_test.dart`.
- A route: `/home`, `/home/details/:id`, `home.details`.
- A library: `package:flutter/material.dart`.
- A command: `dart format .`, `flutter build ipa`.
- A file at the root of the app, or a name: `pubspec.yaml`, `Icons.home`.
- Code: `context.nav.home.details(id: 5).go()`, `bootstrap()`.
- What the tools write: `build/ios/SourcePackages`, `.dart_tool/`.
- A path in the text, not in code: lib/missing.dart.
'''),
        isEmpty,
      );
    });

    test('are read in inline code, not in fenced code blocks', () {
      final issues = check('''
## Router

```bash
cat `lib/in_a_block.dart`
```

A span of two backticks, ``lib/two.dart``, and one after a run ``` that
nothing closes: `lib/after.dart`. This paragraph ends with a ` alone.

The next paragraph has `lib/next.dart`, which the one before does not reach.
''');

      expect(messages(issues), [
        for (final path in ['lib/two.dart', 'lib/after.dart', 'lib/next.dart'])
          equals(
            'The section "Router" of AGENTS.md names `$path`, but the app has '
            'no such file or directory.',
          ),
      ]);
    });

    test('are reported once for each section, and for the introduction', () {
      final issues = check('''
# AGENTS.md

See `lib/missing.dart`.

## Router

- `lib/missing.dart` has the routes.
- Put a route into `lib/missing.dart`.

## Layout

- `lib/missing.dart` has the shell.
''');

      expect(messages(issues), [
        for (final where in [
          'The introduction',
          'The section "Router"',
          'The section "Layout"',
        ])
          equals(
            '$where of AGENTS.md names `lib/missing.dart`, but the app has no '
            'such file or directory.',
          ),
      ]);
    });

    test('of the note of the role are those that the role guarantees',
        () async {
      final rendered = await renderTemplate(appEntryRole);
      final interface = appEntryRole.interface;

      // An app with nothing but what the role guarantees: the files of its
      // template and those of the symbols of its providers.
      expect(
        check(
          rendered.files[guide]!,
          files: [
            ...interface.files,
            for (final symbol in interface.symbols) symbol.path,
          ],
        ),
        isEmpty,
      );
      // Without them, the rule finds the paths of the note.
      expect(
        messages(check(rendered.files[guide]!, files: const ['lib/app.dart'])),
        [
          for (final path in [
            AppEntryRole.mainFile,
            AppEntryRole.bootstrapFile,
          ])
            equals(
              'The section "App entry" of AGENTS.md names `$path`, but the '
              'app has no such file or directory.',
            ),
        ],
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

    test('the phases of start-up are in the body of bootstrap()', () {
      final issues = checkModule({
        AppEntryRole.bootstrapFile: '''
Future<void> bootstrap() async {
{{{smf_app_entry__bootstrap_early}}}
{{{smf_app_entry__bootstrap_platform}}}
{{{smf_app_entry__bootstrap_di}}}
}

void later() {
{{{smf_app_entry__bootstrap_late}}}
}
''',
      });

      expect(issues.map((issue) => issue.message), [
        equals(
          'The tag {{{smf_app_entry__bootstrap_late}}} is in '
          'lib/bootstrap.dart, but not in the body of bootstrap(), which '
          'runs the phases of start-up.',
        ),
      ]);
      expect(issues.single.origin, const ModuleOrigin(ModuleId('scaffold')));

      for (final template in [
        'Future<void> bootstrap() async => run();\n',
        // A body that the template does not close.
        'Future<void> bootstrap() async {\n',
      ]) {
        final withoutBody = checkModule({
          AppEntryRole.bootstrapFile:
              '$template{{{smf_app_entry__bootstrap_early}}}\n',
        });
        expect(
          withoutBody.map((issue) => issue.message),
          [
            equals(
              'The tag {{{smf_app_entry__bootstrap_early}}} is in '
              'lib/bootstrap.dart, but not in the body of bootstrap(), which '
              'runs the phases of start-up.',
            ),
          ],
          reason: template,
        );
      }
    });

    test(
        'the body of bootstrap() ends at its own brace, whatever the strings, '
        'comments, tags and closures in it', () {
      expect(
        checkModule({
          AppEntryRole.bootstrapFile: '''
{{{smf_app_entry__top_level}}}

/// Runs the start-up code of {{app_name}}, not a } of a comment.
Future<void> bootstrap() async {
  // A brace in a comment: }
  /* And in another: } */
  print('A brace in a string: }');
  print(""" and in another: } """);
{{{smf_app_entry__bootstrap_early}}}
  await runZoned(() async {
{{{smf_app_entry__bootstrap_platform}}}
  });
{{{smf_app_entry__bootstrap_di}}}
{{{smf_app_entry__bootstrap_late}}}
}

void later() {}
''',
        }),
        isEmpty,
      );
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
            'com.android.application: the provider of the app entry role '
            'declares it.',
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
