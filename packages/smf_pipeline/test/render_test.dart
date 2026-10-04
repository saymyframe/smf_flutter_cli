import 'dart:convert';

import 'package:mason/mason.dart'
    show
        GeneratedFile,
        GeneratorTarget,
        Logger,
        MasonBundle,
        MasonBundledFile,
        MasonGenerator,
        OverwriteRule,
        TemplateFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/src/render.dart';
import 'package:test/test.dart';

import 'support.dart';

String _asIs(String value) => value;

/// The tag of the member `ios` of the family `home.versions`.
const _iosVersion = '{{{smf_home__versions__ios}}}';

/// Renders an app of [modules], all requested, with the variants for the
/// providers in [variants] by module id, after checking that stage 5 finds
/// no errors.
RenderedApp _render(
  List<SmfModule> modules, {
  Map<Role, Object?> choices = const {},
  Map<String, String> variants = const {},
}) {
  final registry = ModuleRegistry(modules);
  final resolution = Resolution([
    for (final module in modules)
      ResolvedModule(
        module,
        const Requested(),
        variant: switch (variants[module.descriptor.id.value]) {
          final String provider => ModuleId(provider),
          null => null,
        },
      ),
  ]);
  final collection = collect(resolution, testContext);
  final validation = validate(
    registry: registry,
    resolution: resolution,
    collection: collection,
    context: testContext,
  );
  expect(
    [
      for (final issue in validation.issues)
        if (issue.isError) '$issue',
    ],
    isEmpty,
    reason: 'stage 5',
  );
  return renderApp(
    registry: registry,
    resolution: resolution,
    collection: collection,
    context: testContext,
    choices: choices,
    pubspec: validation.pubspec,
  );
}

/// The messages of the issues that stop rendering an app of [modules].
List<String> _failures(
  List<SmfModule> modules, {
  Map<Role, Object?> choices = const {},
}) {
  try {
    _render(modules, choices: choices);
  } on GenerationFailedException catch (error) {
    return [for (final issue in error.issues) '${issue.origin}: $issue'];
  }
  fail('The app rendered.');
}

/// An app whose notes for coding agents are under conditions that put their
/// contributors on a cycle of order edges: the template of the role `nav`
/// has a note for an app with a theme, the provider of the theme has one
/// for an app with a settings screen, and the module of the settings
/// screen requires `nav`.
List<SmfModule> _notesOnACycle() {
  final theme = TestRole<NoDsl>('theme');
  final settingsScreen = TestRole<NoDsl>('settings_screen');
  final nav = TestRole<NoDsl>(
    'nav',
    uses: {theme},
    template: TestTemplate(
      contributions: [
        AppEntryRole.agentSections.entry(
          'Nav',
          AgentNote.ofRole('Navigate with the router.'),
        ),
        AppEntryRole.agentSections.entry(
          'Nav',
          AgentNote.ofRole('A route takes its colors from the theme.'),
          when: {theme},
        ),
      ],
    ),
  );
  return [
    scaffold(),
    TestModule('router', providers: [RoleProvider.plain(nav)]),
    TestModule(
      'material_theme',
      uses: {settingsScreen},
      providers: [RoleProvider.plain(theme)],
      contributions: [
        AppEntryRole.agentSections.entry(
          'Theme',
          AgentNote('Change the colors in the theme.'),
        ),
        AppEntryRole.agentSections.entry(
          'Theme',
          AgentNote('The settings screen has an entry for the theme.'),
          when: {settingsScreen},
        ),
      ],
    ),
    TestModule(
      'settings',
      requires: {nav},
      providers: [RoleProvider.plain(settingsScreen)],
    ),
  ];
}

BrickContribution _brick(
  Map<String, String> files, {
  Map<String, Object?> vars = const {},
  Set<Role> when = const {},
}) =>
    BrickContribution(bundle('b', files: files), vars: vars, when: when);

/// A role with a template and a provider whose render hooks return
/// `templateOutput` and `providerOutput`.
final class _Rendering {
  factory _Rendering({
    RoleOutput templateOutput = const RoleOutput(),
    RoleOutput providerOutput = const RoleOutput(),
    List<Contribution> templateContributions = const [],
  }) {
    final sockets = <SocketRef>[];
    final role = TestRole<String>(
      'shelf',
      sockets: sockets,
      template: _Template(templateOutput, templateContributions),
    );
    final items = SocketRef<CodeSocket>.role(role, 'items', const CodeSocket());
    sockets.add(items);
    return _Rendering._(role, _Provider(role, providerOutput), items);
  }

  _Rendering._(this.role, this.provider, this.items);

  final TestRole<String> role;
  final _Provider provider;
  final SocketRef<CodeSocket> items;
}

final class _Template extends RoleTemplate<String> {
  _Template(this.output, this.contributions);

  final RoleOutput output;
  final List<Contribution> contributions;
  final List<RoleHookInput<String>> inputs = [];

  @override
  List<Contribution> contribute(ModuleContext context) => contributions;

  @override
  RoleOutput render(RoleHookInput<String> input) {
    inputs.add(input);
    return output;
  }
}

final class _Provider extends RoleProvider<String> {
  _Provider(this.role, this.output);

  @override
  final Role<String> role;

  final RoleOutput output;

  @override
  RoleOutput render(RoleHookInput<String> input) => output;
}

final class _Throwing extends RoleProvider<String> {
  _Throwing(this.role);

  @override
  final Role<String> role;

  @override
  RoleOutput render(RoleHookInput<String> input) =>
      throw StateError('hook broke');
}

/// A target of mason that keeps the files it generates in memory.
final class _MemoryTarget extends GeneratorTarget {
  final Map<String, List<int>> files = {};

  @override
  Future<GeneratedFile> createFile(
    String path,
    List<int> contents, {
    Logger? logger,
    OverwriteRule? overwriteRule,
  }) async {
    files[path] = contents;
    return GeneratedFile.created(path: path);
  }
}

void main() {
  final entry = scaffold();

  test('renders the bricks with the names, flags, tags and variables', () {
    final nav = TestRole<NoDsl>('nav');
    final absent = TestRole<NoDsl>('absent');
    final app = _render([
      scaffold(
        contributions: [
          const SocketContribution.code(
            AppEntryRole.bootstrapEarly,
            Fragment('early();'),
          ),
        ],
      ),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
      TestModule(
        'home',
        uses: {nav, absent},
        contributions: [
          _brick(
            {
              'lib/home/{{name}}.dart': '// {{app_name}} of {{org_name}}\n'
                  '{{#has_nav}}nav{{/has_nav}}'
                  '{{^has_absent}} no absent{{/has_absent}}\n'
                  '{{{greeting}}}\n',
            },
            vars: {'name': 'home_screen', 'greeting': "'hi' & <b>"},
          ),
          BrickContribution(
            MasonBundle(
              name: 'binary',
              description: 'binary',
              version: '0.1.0',
              files: [
                MasonBundledFile(
                  'assets/logo.bin',
                  base64.encode([0, 255, 123, 123]),
                  'binary',
                ),
              ],
            ),
          ),
        ],
      ),
    ]);

    expect(
      app.files['lib/home/home_screen.dart']!.text,
      "// my_app of com.example\nnav no absent\n'hi' & <b>\n",
    );
    expect(app.files['lib/home/home_screen.dart']!.owner, isA<ModuleOrigin>());
    expect(app.files['assets/logo.bin']!.bytes, [0, 255, 123, 123]);
    expect(app.files['assets/logo.bin']!.isText, isFalse);
    expect(app.texts.keys, isNot(contains('assets/logo.bin')));
    expect(app.files['lib/bootstrap.dart']!.text, contains('early();'));
    expect(app.files.keys, orderedEquals([...app.files.keys]..sort()));
    expect(
      app.owners['lib/main.dart'],
      const ModuleOrigin(ModuleId('scaffold')),
    );
  });

  test('renders the sockets of the pipeline from the merged pubspec', () {
    final app = _render([
      scaffold(
        contributions: [
          const PubspecContribution.hosted('b_lib', '^1.0.0'),
          const PubspecContribution.hosted('a_lib', '>=1.0.0 <3.0.0'),
          const PubspecContribution.sdk('flutter_test', dev: true),
          const CodegenRequest(),
          const PubspecContribution.flutter(
            usesMaterialDesign: true,
            assets: ['assets/'],
          ),
        ],
      ),
    ]);

    expect(app.files['pubspec.yaml']!.text, '''
name: my_app
publish_to: none

environment:
  sdk: "^3.8.1"

dependencies:
  flutter:
    sdk: flutter
  a_lib: ">=1.0.0 <3.0.0"
  b_lib: "^1.0.0"

dev_dependencies:
  flutter_test:
    sdk: flutter
  build_runner: "^2.10.0"

flutter:
  uses-material-design: true
  assets:
    - "assets/"
''');
  });

  test('a line with nothing but the tag of an empty socket goes away', () {
    const setup = SocketRef<CodeSocket>.module(
      ModuleId('parent'),
      'setup',
      CodeSocket(),
    );
    final app = _render([
      scaffold(
        contributions: [
          AppEntryRole.androidManifestPermissions
              .key('android.permission.CAMERA'),
        ],
      ),
      TestModule(
        'parent',
        sockets: [setup],
        contributions: [
          _brick({
            'lib/parent.dart': 'void setUp() {\n'
                '  {{{smf_parent__setup}}}\n'
                '}\n',
          }),
        ],
      ),
    ]);

    expect(app.files['android/app/src/main/AndroidManifest.xml']!.text, '''
<manifest xmlns:android="http://schemas.android.com/apk/res/android">
    <uses-permission android:name="android.permission.CAMERA"/>
    <application>
        <activity android:name=".MainActivity">
        </activity>
    </application>
</manifest>
''');
    expect(app.files['lib/parent.dart']!.text, 'void setUp() {\n}\n');
    // A tag with other text on its line renders to nothing, and the line
    // stays.
    expect(app.files['lib/main.dart']!.text, contains('    const App(),\n'));
  });

  test('the fragments of render hooks join the contributions in order', () {
    final rendering = _Rendering(
      templateOutput: const RoleOutput(
        fragments: [
          SocketContribution.code(
            AppEntryRole.bootstrapLate,
            Fragment('fromTemplate();'),
          ),
        ],
        vars: {'title': 'Shelf'},
      ),
      templateContributions: [
        _brick({'lib/shelf.dart': '// {{title}}\n{{{smf_shelf__items}}}\n'}),
      ],
    );
    final itemsOfProvider = SocketContribution.code(
      rendering.items,
      const Fragment('fromProvider();'),
    );
    final app = _render(
      [
        entry,
        TestModule(
          'store',
          providers: [
            _Provider(rendering.role, RoleOutput(fragments: [itemsOfProvider])),
          ],
          contributions: [
            _brick({'lib/store.dart': '// store'}),
          ],
        ),
        TestModule(
          'user',
          requires: {rendering.role},
          contributions: [
            rendering.role.data('user data'),
            SocketContribution.code(
              rendering.items,
              const Fragment('fromUser();'),
            ),
            const SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment('fromUser();'),
            ),
          ],
        ),
      ],
      choices: {rendering.role: 'chosen'},
    );

    expect(
      app.files['lib/shelf.dart']!.text,
      '// Shelf\nfromProvider();\nfromUser();\n',
    );
    // The module that requires the role comes after its template.
    expect(
      app.files['lib/bootstrap.dart']!.text,
      contains('fromTemplate();\nfromUser();'),
    );
    final input = (rendering.role.template! as _Template).inputs.single;
    expect(input.choice, 'chosen');
    expect(input.data.single.value, 'user data');

    // The app keeps the contributions of each socket that got any, the
    // fragments of the render hooks among them, in the order they were
    // rendered in.
    List<String> contributionsTo(SocketRef socket) => [
          for (final collected in app.socketOrders[socket]!.contributions)
            [
              '${collected.origin}:',
              (collected.contribution as SocketContribution).fragment!.code,
            ].join(' '),
        ];
    expect(contributionsTo(rendering.items), [
      'store: fromProvider();',
      'user: fromUser();',
    ]);
    expect(contributionsTo(AppEntryRole.bootstrapLate), [
      'role:shelf: fromTemplate();',
      'user: fromUser();',
    ]);
    // A socket that got nothing has no order.
    expect(app.socketOrders, isNot(contains(AppEntryRole.bootstrapEarly)));
  });

  test('render hooks follow the rules of their owners', () {
    final other = TestRole<NoDsl>('other');
    final rendering = _Rendering(
      templateOutput: const RoleOutput(
        vars: {
          'app_name': 'x',
          'has_it': true,
          'bad': 'a\\\nb',
          'keys': {1: 'not a string key'},
        },
      ),
    );
    final otherSocket =
        SocketRef<CodeSocket>.role(other, 'code', const CodeSocket());

    expect(
      _failures([
        entry,
        TestModule(
          'store',
          providers: [
            _Provider(
              rendering.role,
              RoleOutput(
                fragments: [
                  SocketContribution.code(otherSocket, const Fragment('x();')),
                ],
              ),
            ),
          ],
        ),
        TestModule('elsewhere', providers: [RoleProvider.plain(other)]),
      ]),
      [
        contains(
          'role:shelf: error [role:shelf]: The render hook of role:shelf sets '
          'the brick variable app_name, which the pipeline sets itself.',
        ),
        contains('sets the brick variable has_it'),
        contains(
          'The brick variable bad of the render hook of role:shelf has a '
          'backslash',
        ),
        contains(
          'The brick variable keys of the render hook of role:shelf is not '
          'plain data',
        ),
        contains(
          'store puts code into the socket other.code, but does not provide, '
          'require or use the other role.',
        ),
      ],
    );
  });

  test(
      'a render hook that throws, or two hooks of a module that set one '
      'variable, stop rendering', () {
    final first = _Rendering();
    final second = TestRole<String>('second');
    expect(
      _failures([
        entry,
        TestModule(
          'store',
          providers: [
            _Provider(first.role, const RoleOutput(vars: {'x': 1})),
            _Provider(second, const RoleOutput(vars: {'x': 2})),
          ],
        ),
        TestModule('broken', providers: [_Throwing(TestRole<String>('t'))]),
      ]),
      [
        equals(
          'store: error [store]: Two render hooks of store set the brick '
          'variable x.',
        ),
        startsWith(
          'broken: error [broken]: The render hook of broken failed: '
          'Bad state: hook broke',
        ),
      ],
    );
  });

  test('a fragment for an absent role does not apply', () {
    final absent = TestRole<NoDsl>('absent');
    final rendering = _Rendering(
      templateOutput: const RoleOutput(
        fragments: [
          SocketContribution.code(
            AppEntryRole.bootstrapLate,
            Fragment('onlyWithAbsent();'),
          ),
        ],
      ),
    );
    final app = _render([
      entry,
      TestModule(
        'store',
        uses: {absent},
        providers: [
          _Provider(
            rendering.role,
            RoleOutput(
              fragments: [
                SocketContribution.code(
                  AppEntryRole.bootstrapLate,
                  const Fragment('whenAbsent();'),
                  when: {absent},
                ),
              ],
            ),
          ),
        ],
      ),
    ]);

    expect(
      app.files['lib/bootstrap.dart']!.text,
      allOf(contains('onlyWithAbsent();'), isNot(contains('whenAbsent();'))),
    );
  });

  test('a required value of a family member needs a contribution', () {
    final versions = SocketFamily<String, ValueSocket<String>>.module(
      const ModuleId('home'),
      'versions',
      const ValueSocket(policy: MaxPolicy(), renderer: _asIs, required: true),
      keyOf: (key) => [key],
    );

    expect(
      _failures([
        entry,
        TestModule(
          'home',
          socketFamilies: [versions],
          contributions: [
            _brick({'lib/v.dart': "const v = '$_iosVersion';"}),
          ],
        ),
      ]),
      [
        equals(
          'home: error [home]: The socket home.versions.ios needs a value, but '
          'nothing contributes one.',
        ),
      ],
    );
  });

  test('code of a render hook for a socket without a tag is an error', () {
    // Stage 5 reports the contributions of modules to such a socket; the
    // fragments of render hooks come later.
    final sockets = <SocketRef>[];
    final shelf = TestRole<String>('shelf', sockets: sockets);
    final items =
        SocketRef<CodeSocket>.role(shelf, 'items', const CodeSocket());
    sockets.add(items);

    expect(
      _failures([
        entry,
        TestModule(
          'store',
          providers: [
            _Provider(
              shelf,
              RoleOutput(
                fragments: [
                  SocketContribution.code(items, const Fragment('a();')),
                ],
              ),
            ),
          ],
        ),
      ]),
      [
        equals(
          'store: error [store]: store contributes to the socket shelf.items, '
          'but no template of the app has its tag smf_shelf__items, so what '
          'they contribute would be lost.',
        ),
      ],
    );
  });

  test('merge conflicts of render hooks name their contributors', () {
    final rendering = _Rendering(
      providerOutput: RoleOutput(
        fragments: [AppEntryRole.iosDeploymentTarget.value('15.0')],
      ),
    );
    final app = _render([
      entry,
      TestModule('store', providers: [rendering.provider]),
    ]);
    expect(app.files['ios/Podfile']!.text, "platform :ios, '15.0'\n");

    final conflicting = _Rendering(
      providerOutput: const RoleOutput(
        fragments: [
          SocketContribution.arg(
            AppEntryRole.appArgs,
            'theme',
            Fragment('ThemeData.dark()'),
          ),
        ],
      ),
    );
    expect(
      _failures([
        scaffold(
          contributions: [
            const SocketContribution.arg(
              AppEntryRole.appArgs,
              'theme',
              Fragment('ThemeData.light()'),
            ),
          ],
        ),
        TestModule('store', providers: [conflicting.provider]),
      ]),
      [contains('The contributions to the socket app_entry.app_args conflict')],
    );
  });

  test('text that mason would change once joined is an error', () {
    final rendering = _Rendering(
      providerOutput: const RoleOutput(
        fragments: [
          SocketContribution.code(
            AppEntryRole.bootstrapLate,
            Fragment('after();'),
          ),
        ],
      ),
    );
    expect(
      _failures([
        scaffold(
          contributions: [
            // A backslash at the end of a fragment stays, unless another
            // fragment follows it on the next line.
            const SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment(r'// ends with \'),
            ),
          ],
        ),
        TestModule('store', providers: [rendering.provider]),
      ]),
      [
        contains(
          'The socket app_entry.bootstrap_late cannot be rendered: Invalid '
          'argument',
        ),
      ],
    );
  });

  test(
      'a cycle among the contributors of a socket that does not follow the '
      'order edges renders: a note under a condition cannot stop an app', () {
    final app = _render(_notesOnACycle());

    expect(
      app.files[AppEntryRole.agentsFile]!.text,
      endsWith(
        '\n'
        '## Nav\n'
        '\n'
        'Navigate with the router.\n'
        '\n'
        'A route takes its colors from the theme.\n'
        '\n'
        '## Theme\n'
        '\n'
        'Change the colors in the theme.\n'
        '\n'
        'The settings screen has an entry for the theme.\n',
      ),
    );
  });

  test('a cycle that only a fragment of a render hook meets stops rendering',
      () {
    final y = TestRole<NoDsl>('y');
    final z = TestRole<NoDsl>('z');
    final rendering = _Rendering(
      providerOutput: const RoleOutput(
        fragments: [
          SocketContribution.code(
            AppEntryRole.bootstrapLate,
            Fragment('late();'),
          ),
        ],
      ),
    );

    // p comes after q, which comes after m, which comes after p; stage 5
    // sees no socket that more than one of them contributes to.
    expect(
      _failures([
        entry,
        TestModule('p', providers: [rendering.provider], requires: {z}),
        TestModule(
          'm',
          requires: {rendering.role},
          providers: [RoleProvider.plain(y)],
        ),
        TestModule('q', requires: {y}, providers: [RoleProvider.plain(z)]),
      ]),
      [
        endsWith(
          'The contributors to the socket app_entry.bootstrap_late cannot be '
          'ordered, because their order edges form a cycle: m, p, q. (Run '
          'with --explain to see the edges.)',
        ),
      ],
    );
  });

  test('renders bricks the way mason generate does', () async {
    const templates = {
      'android/app/src/main/kotlin/{{android_package.pathCase()}}/Main.kt':
          'package {{android_package}}\n',
      'lib/list.dart': '{{#items}}{{name}}, {{/items}}{{{code}}} {{code}}\n'
          '{{title.snakeCase()}} {{#flag}}yes{{/flag}}{{^flag}}no{{/flag}}\n'
          '// café {{__LEFT_CURLY_BRACKET__}}\n',
      'lib/crlf.dart': '// {{title}}\r\nconst a = 1;\r\n',
      'lib/bom.dart': '\uFEFF// {{title}}\n',
      'lib/copied.dart': "const braces = '{{a,b}}';\n",
    };
    final vars = <String, Object?>{
      'android_package': 'com.example.my_app',
      'items': [
        {'name': 'a'},
        {'name': 'b'},
      ],
      'code': "<b> & 'c'",
      'title': 'My Title',
      'flag': false,
    };
    final bundle = MasonBundle(
      name: 'tricky',
      description: 'tricky',
      version: '0.1.0',
      files: [
        for (final MapEntry(key: path, value: text) in templates.entries)
          MasonBundledFile(path, base64.encode(utf8.encode(text)), 'text'),
        MasonBundledFile(
          'assets/dot.png',
          base64.encode([137, 80, 78, 71]),
          'binary',
        ),
      ],
    );

    final app = _render([
      entry,
      TestModule(
        'home',
        contributions: [BrickContribution(bundle, vars: vars)],
      ),
    ]);
    final target = _MemoryTarget();
    await MasonGenerator(
      bundle.name,
      bundle.description,
      files: [
        for (final file in bundle.files)
          TemplateFile.fromBytes(file.path, base64.decode(file.data)),
      ],
    ).generate(
      target,
      vars: {'app_name': 'my_app', 'org_name': 'com.example', ...vars},
    );

    expect(target.files, hasLength(templates.length + 1));
    for (final MapEntry(key: path, value: bytes) in target.files.entries) {
      expect(app.files[path]?.bytes, bytes, reason: path);
    }
    // mason's pathCase splits snake_case words too.
    expect(
      app.files['android/app/src/main/kotlin/com/example/my/app/Main.kt']!.text,
      'package com.example.my_app\n',
    );
  });

  group('files', () {
    test('a path that leaves the app, is empty or is absolute is an error', () {
      expect(
        _failures([
          entry,
          TestModule(
            'home',
            contributions: [
              _brick(
                {
                  '{{up}}/x.dart': '',
                  '{{nothing}}': '',
                  '{{{root}}}/y.dart': '',
                  'lib//{{nothing}}z.dart': '',
                  'lib/{{root}}.dart': '',
                  '{{{tool}}}/Generated.xcconfig': '',
                  '{{{tool}}}/Pods/x.h': '',
                },
                vars: {
                  'up': '..',
                  'nothing': '',
                  'root': '/etc',
                  'tool': 'ios/Flutter',
                },
              ),
            ],
          ),
        ]),
        [
          contains('The path {{up}}/x.dart in the brick b of home renders to '
              '"../x.dart", which leaves the directory of the app.'),
          contains('The path {{nothing}} in the brick b of home renders to '
              '"", which is empty.'),
          contains('renders to "/etc/y.dart", which is not a relative path'),
          contains('renders to "lib//z.dart", which has an empty or "." '
              'segment.'),
          contains('renders to "lib/&#x2F;etc.dart", which has an HTML '
              'entity'),
          contains('renders to "ios/Flutter/Generated.xcconfig", which is '
              "written by Flutter's tools"),
          contains('renders to "ios/Flutter/Pods/x.h", which is written when '
              'the pods of the app are installed.'),
        ],
      );
    });

    test('a text file that is not UTF-8 is copied as it is', () {
      // Invalid UTF-8 around what looks like a tag.
      final bytes = [0xff, ...'{{x}}'.codeUnits, 0xfe];
      final app = _render([
        entry,
        TestModule(
          'home',
          contributions: [
            BrickContribution(
              MasonBundle(
                name: 'keys',
                description: 'keys',
                version: '0.1.0',
                files: [
                  MasonBundledFile(
                    'assets/fixture.bin',
                    base64.encode(bytes),
                    'text',
                  ),
                ],
              ),
              vars: const {'x': 'rendered'},
            ),
          ],
        ),
      ]);

      final file = app.files['assets/fixture.bin']!;
      expect(file.bytes, bytes);
      expect(file.isText, isFalse);
    });

    test('a path that mason cannot render is an error', () {
      expect(
        _failures([
          entry,
          TestModule(
            'home',
            contributions: [
              _brick({'lib/{{name.dart': ''}),
            ],
          ),
        ]),
        [
          startsWith(
            'home: error [home] lib/{{name.dart: The path lib/{{name.dart in '
            'the brick b of home cannot be rendered:',
          ),
        ],
      );
    });

    test('the kind of a module limits the rendered paths', () {
      const infrastructure = ModuleKind(
        id: 'infrastructure',
        label: 'Infrastructure',
        forbiddenFileRoots: ['lib/features/'],
      );
      expect(
        _failures([
          entry,
          TestModule(
            'db',
            kind: infrastructure,
            contributions: [
              _brick(
                {'lib/{{{dir}}}/db.dart': ''},
                vars: {'dir': 'features/db'},
              ),
            ],
          ),
        ]),
        [
          contains('The module db generates lib/features/db/db.dart, where '
              'modules of the infrastructure kind may not.'),
        ],
      );
    });

    test('paths that differ only in case are one file', () {
      expect(
        _failures([
          entry,
          TestModule(
            'home',
            contributions: [
              _brick({'lib/App.dart': ''}),
            ],
          ),
        ]),
        [
          equals(
            'home: error [home] lib/App.dart: Both scaffold and home generate '
            'lib/app.dart and lib/App.dart, one file where case does not '
            'matter; every file has one brick.',
          ),
        ],
      );
    });

    test('two bricks that render the same path are an error', () {
      expect(
        _failures([
          entry,
          TestModule(
            'home',
            contributions: [
              _brick({'lib/{{name}}.dart': ''}, vars: {'name': 'app'}),
            ],
          ),
        ]),
        [
          equals(
            'home: error [home] lib/app.dart: Both scaffold and home generate '
            'lib/app.dart; every file has one brick.',
          ),
        ],
      );
    });

    test('a variable that nothing sets is an error of the brick', () {
      expect(
        _failures([
          entry,
          TestModule(
            'home',
            contributions: [
              _brick(
                {
                  'lib/a.dart': '{{title}} {{#items}}{{name}}{{/items}} '
                      '{{name.snakeCase()}} {{#flag}}{{/flag}} '
                      '{{#loud}}{{.}}{{/loud}} {{__LEFT_CURLY_BRACKET__}} '
                      // A section over a flag gives no items with fields.
                      '{{#shown}}{{label}}{{/shown}}',
                },
                vars: {
                  'items': [
                    {'name': 'a'},
                  ],
                  'loud': ['x'],
                  'shown': true,
                },
              ),
            ],
          ),
        ]),
        [
          equals(
            'home: error [home] lib/a.dart: The template lib/a.dart in the '
            'brick b of home reads title, name, label, flag, which neither the '
            'brick nor a render hook of home sets, so mustache would render '
            'nothing. (Set every variable a template reads, to "" or false '
            'when there is nothing.)',
          ),
        ],
      );
    });

    test('a variable of a path that nothing sets is an error', () {
      expect(
        _failures([
          entry,
          TestModule(
            'home',
            contributions: [
              _brick(
                {'lib/{{prefix}}screen.dart': '', 'lib/{{a}}{{b}}.dart': ''},
                vars: {'b': 'x'},
              ),
            ],
          ),
        ]),
        [
          equals(
            'home: error [home] lib/{{prefix}}screen.dart: The path '
            'lib/{{prefix}}screen.dart in the brick b of home reads prefix, '
            'which neither the brick nor a render hook of home sets, so '
            'mustache would render nothing. (Set every variable a path reads, '
            'to "" when there is nothing.)',
          ),
          startsWith(
            'home: error [home] lib/{{a}}{{b}}.dart: The path '
            'lib/{{a}}{{b}}.dart in the brick b of home reads a, which',
          ),
        ],
      );
    });

    test('a fragment variable in a path is an error', () {
      final rendering = _Rendering(
        providerOutput: const RoleOutput(vars: {'name': Fragment('code')}),
      );
      expect(
        _failures([
          entry,
          TestModule(
            'home',
            providers: [rendering.provider],
            contributions: [
              _brick({'lib/{{{name}}}.dart': ''}),
            ],
          ),
        ]),
        [
          equals(
            'home: error [home] lib/{{{name}}}.dart: The path '
            'lib/{{{name}}}.dart in the brick b of home reads the fragment '
            'variable name, but a path takes plain values only. (Set every '
            'variable a path reads, to "" when there is nothing.)',
          ),
        ],
      );
    });

    test('a brick variable that a render hook sets too is an error', () {
      final rendering = _Rendering(
        providerOutput: const RoleOutput(vars: {'title': 'hook'}),
      );
      expect(
        _failures([
          entry,
          TestModule(
            'store',
            providers: [rendering.provider],
            contributions: [
              _brick({'lib/s.dart': '{{title}}'}, vars: {'title': 'brick'}),
            ],
          ),
        ]),
        [
          equals(
            'store: error [store]: The brick b of store sets the variable '
            'title, which a render hook of store sets too.',
          ),
        ],
      );
    });

    test("a variant's bricks get the variables of its module's hooks", () {
      final state = TestRole<NoDsl>('state');
      final rendering = _Rendering(
        providerOutput: const RoleOutput(vars: {'label': 'from the hook'}),
      );
      final app = _render(variants: {
        'store': 'bloc',
      }, [
        entry,
        TestModule('bloc', providers: [RoleProvider.plain(state)]),
        TestModule(
          'store',
          providers: [rendering.provider],
          variants: Variants(
            role: state,
            byProvider: {
              const ModuleId('bloc'): (context) => [
                    _brick({'lib/v.dart': '{{label}}'}),
                  ],
            },
          ),
        ),
      ]);
      expect(app.files['lib/v.dart']!.text, 'from the hook');
      expect(
        app.owners['lib/v.dart'],
        const ModuleOrigin(ModuleId('store'), variant: ModuleId('bloc')),
      );
    });
  });

  group('files of render hooks', () {
    test('are files of the app, written as they are, each with its owner', () {
      // What mason renders or removes in a template stays in such a file:
      // tags, a backslash before a line break or a non-ASCII character,
      // and the line endings.
      const text = '{{app_name}} {{{smf_app_entry__bootstrap_late}}}\r\n'
          'a\\\nb caf\\é {{#items}}\n';
      final rendering = _Rendering(
        templateOutput: const RoleOutput(
          files: {'notes/of_template.txt': text},
        ),
        providerOutput: const RoleOutput(
          files: {
            'lib/store/item_1.dart': 'const item1 = 1;\n',
            'assets/store/empty.txt': '',
          },
        ),
      );
      final app = _render([
        entry,
        TestModule(
          'store',
          providers: [rendering.provider],
          contributions: [
            _brick({'lib/store/store.dart': "import 'item_1.dart';\n"}),
          ],
        ),
      ]);

      final ofTemplate = app.files['notes/of_template.txt']!;
      expect(ofTemplate.text, text);
      expect(ofTemplate.bytes, utf8.encode(text));
      expect(ofTemplate.owner, RoleTemplateOrigin(rendering.role));
      expect(ofTemplate.isText, isTrue);
      expect(ofTemplate.fromHook, isTrue);
      expect(ofTemplate.addedImports, isEmpty);

      final ofProvider = app.files['lib/store/item_1.dart']!;
      expect(ofProvider.text, 'const item1 = 1;\n');
      expect(ofProvider.owner, const ModuleOrigin(ModuleId('store')));
      expect(ofProvider.fromHook, isTrue);
      expect(app.texts['assets/store/empty.txt'], '');
      expect(
        app.owners['assets/store/empty.txt'],
        const ModuleOrigin(ModuleId('store')),
      );

      // They are among the files of the bricks, which no hook generated.
      expect(app.files['lib/store/store.dart']!.fromHook, isFalse);
      expect(app.files.keys, orderedEquals([...app.files.keys]..sort()));
    });

    test(
        'a path that leaves the app, is empty, is absolute or belongs to one '
        'machine is an error', () {
      final rendering = _Rendering(
        templateOutput: const RoleOutput(
          files: {'../x.txt': '', '': '', 'lib/fine.txt': ''},
        ),
        providerOutput: const RoleOutput(
          files: {
            '/etc/y.txt': '',
            r'lib\y.txt': '',
            'C:/y.txt': '',
            'lib//y.txt': '',
            './lib/y.txt': '',
            'ios/Flutter/Generated.xcconfig': '',
            'lib/.DS_Store': '',
          },
        ),
      );

      expect(
        _failures([
          entry,
          TestModule('store', providers: [rendering.provider]),
        ]),
        [
          equals(
            'role:shelf: error [role:shelf]: The render hook of role:shelf '
            'generates a file at "../x.txt", which leaves the directory of '
            'the app.',
          ),
          equals(
            'role:shelf: error [role:shelf]: The render hook of role:shelf '
            'generates a file at "", which is empty.',
          ),
          equals(
            'store: error [store]: The render hook of store generates a file '
            'at "/etc/y.txt", which is not a relative path with forward '
            'slashes.',
          ),
          contains(r'at "lib\y.txt", which is not a relative path with'),
          contains('at "C:/y.txt", which is not a relative path with'),
          contains('at "lib//y.txt", which has an empty or "." segment.'),
          contains('at "./lib/y.txt", which has an empty or "." segment.'),
          equals(
            'store: error [store]: The render hook of store generates a file '
            'at "ios/Flutter/Generated.xcconfig", which is written by '
            "Flutter's tools, which the pipeline does not move with the app.",
          ),
          contains(
            'at "lib/.DS_Store", which is left behind by the operating '
            'system.',
          ),
        ],
      );
    });

    test('a path that some machine cannot write is an error', () {
      final rendering = _Rendering(
        providerOutput: const RoleOutput(
          files: {
            'lib/a:b.txt': '',
            'lib/a*b.txt': '',
            'lib/a?.txt': '',
            'lib/"a".txt': '',
            'lib/<a>.txt': '',
            'lib/a|b.txt': '',
            'lib/a\nb.txt': '',
            'lib/a\tb\x7f.txt': '',
            'lib/a b.txt': '',
            'lib/a./b.txt': '',
            'lib/a /b.txt': '',
            'lib/a.txt.': '',
            'lib/a.txt ': '',
            // What every machine writes: spaces and dots inside a name, a
            // name that starts with dots, and letters beyond ASCII.
            "lib/.a b/..it's (1) é.txt": '',
          },
        ),
      );

      String failure(String path, String problem) =>
          'store: error [store]: The render hook of store generates a file at '
          '"$path", which $problem.';
      const character = 'has a character that Windows allows in no name of a '
          'file: < > : " | ? or *';
      const control = 'has a control character or a line break';
      const ending = 'has a segment that ends with a dot or a space, which '
          'Windows removes';
      expect(
        _failures([
          entry,
          TestModule('store', providers: [rendering.provider]),
        ]),
        [
          failure('lib/a:b.txt', character),
          failure('lib/a*b.txt', character),
          failure('lib/a?.txt', character),
          failure('lib/"a".txt', character),
          failure('lib/<a>.txt', character),
          failure('lib/a|b.txt', character),
          // The message shows such a character as its escape.
          failure(r'lib/a\u{a}b.txt', control),
          failure(r'lib/a\u{9}b\u{7f}.txt', control),
          failure(r'lib/a\u{2028}b.txt', control),
          failure('lib/a./b.txt', ending),
          failure('lib/a /b.txt', ending),
          failure('lib/a.txt.', ending),
          failure('lib/a.txt ', ending),
        ],
      );
    });

    test('a path of the app is a file or a directory, not both', () {
      final rendering = _Rendering(
        templateOutput: const RoleOutput(
          files: {
            // The directory of a file of a brick.
            'lib/store': '',
            // The same, where case does not matter.
            'ANDROID': '',
            // In what is a file of a brick, where case does not matter.
            'lib/App.dart/notes.txt': '',
            'notes/first': '',
          },
        ),
        providerOutput: const RoleOutput(
          files: {
            // In what is a file of another hook.
            'notes/first/second.txt': '',
            // Next to a file and to a directory whose names start alike.
            'lib/store_notes.txt': '',
            'notes/first.txt': '',
          },
        ),
      );

      const either = 'a path of the app is a file or a directory, not both.';
      expect(
        _failures([
          entry,
          TestModule(
            'store',
            providers: [rendering.provider],
            contributions: [
              _brick({'lib/store/store.dart': ''}),
            ],
          ),
        ]),
        [
          equals(
            'role:shelf: error [role:shelf] lib/store: The render hook of '
            'role:shelf generates lib/store, but lib/store is a directory of '
            'the app, in which a brick of store generates '
            'lib/store/store.dart; $either',
          ),
          equals(
            'role:shelf: error [role:shelf] ANDROID: The render hook of '
            'role:shelf generates ANDROID, but android, one path with ANDROID '
            'where case does not matter, is a directory of the app, in which '
            'a brick of scaffold generates '
            'android/app/src/main/AndroidManifest.xml; $either',
          ),
          equals(
            'role:shelf: error [role:shelf] lib/App.dart/notes.txt: The '
            'render hook of role:shelf generates lib/App.dart/notes.txt, but '
            'lib/app.dart, one path with lib/App.dart where case does not '
            'matter, is a file of the app, which a brick of scaffold '
            'generates; $either',
          ),
          equals(
            'store: error [store] notes/first/second.txt: The render hook of '
            'store generates notes/first/second.txt, but notes/first is a '
            'file of the app, which a render hook of role:shelf generates; '
            '$either',
          ),
        ],
      );
    });

    test('the kind of the module of a provider limits their paths', () {
      const infrastructure = ModuleKind(
        id: 'infrastructure',
        label: 'Infrastructure',
        forbiddenFileRoots: ['lib/features/'],
      );
      final rendering = _Rendering(
        // The template of a role has no kind.
        templateOutput: const RoleOutput(
          files: {'lib/features/shelf/a.txt': ''},
        ),
        providerOutput: const RoleOutput(
          files: {'lib/features/store/a.txt': '', 'lib/store/b.txt': ''},
        ),
      );

      expect(
        _failures([
          entry,
          TestModule(
            'store',
            kind: infrastructure,
            providers: [rendering.provider],
          ),
        ]),
        [
          equals(
            'store: error [store] lib/features/store/a.txt: The module store '
            'generates lib/features/store/a.txt, where modules of the '
            'infrastructure kind may not.',
          ),
        ],
      );
    });

    test('every file of the app is generated once', () {
      final rendering = _Rendering(
        templateOutput: const RoleOutput(
          files: {
            // A file of the brick of another owner.
            'lib/app.dart': '',
            'lib/shelf.txt': '',
            // One file with the one before where case does not matter.
            'lib/Shelf.txt': '',
          },
        ),
        providerOutput: const RoleOutput(
          files: {
            // A file of the hook of the template.
            'lib/shelf.txt': '',
            // A file of the brick of the same module.
            'lib/store.dart': '',
            'lib/of_store.txt': '',
          },
        ),
      );

      expect(
        _failures([
          entry,
          TestModule(
            'store',
            providers: [rendering.provider],
            contributions: [
              _brick({'lib/store.dart': ''}),
            ],
          ),
        ]),
        [
          equals(
            'role:shelf: error [role:shelf] lib/app.dart: The render hook of '
            'role:shelf generates lib/app.dart, which a brick of scaffold '
            'generates too; every file of the app is generated once.',
          ),
          equals(
            'role:shelf: error [role:shelf] lib/Shelf.txt: The render hook '
            'of role:shelf generates lib/Shelf.txt, one file with '
            'lib/shelf.txt where case does not matter, which a render hook '
            'of role:shelf generates too; every file of the app is generated '
            'once.',
          ),
          equals(
            'store: error [store] lib/shelf.txt: The render hook of store '
            'generates lib/shelf.txt, which a render hook of role:shelf '
            'generates too; every file of the app is generated once.',
          ),
          equals(
            'store: error [store] lib/store.dart: The render hook of store '
            'generates lib/store.dart, which a brick of store generates too; '
            'every file of the app is generated once.',
          ),
        ],
      );
    });
  });

  group('imports', () {
    test('go into the file with the tag, among its imports', () {
      final app = _render([
        scaffold(
          contributions: [
            const SocketContribution.code(
              AppEntryRole.bootstrapEarly,
              Fragment(
                'a();',
                imports: [
                  ImportRef('package:zeta/zeta.dart'),
                  ImportRef('dart:async'),
                  ImportRef.app('core/a.dart', prefix: 'a'),
                ],
              ),
            ),
          ],
        ),
        TestModule(
          'other',
          contributions: [
            const SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment(
                'b();',
                imports: [
                  ImportRef('package:zeta/zeta.dart', show: ['Z']),
                ],
              ),
            ),
          ],
        ),
      ]);

      final bootstrap = app.files['lib/bootstrap.dart']!;
      expect(
        bootstrap.text,
        startsWith(
          "import 'dart:async';\n"
          '\n'
          "import 'package:my_app/core/a.dart' as a;\n"
          "import 'package:zeta/zeta.dart';\n"
          '\n',
        ),
      );
      expect(
        [
          for (final added in bootstrap.addedImports)
            '${added.import.uri} ${added.contributor}',
        ],
        [
          'package:zeta/zeta.dart scaffold',
          'dart:async scaffold',
          'package:my_app/core/a.dart scaffold',
          'package:zeta/zeta.dart other',
        ],
      );
    });

    test('an import the file has is not added again', () {
      final app = _render([
        scaffold(
          contributions: [
            const SocketContribution.wrap(
              AppEntryRole.rootWrappers,
              Fragment.wrap(
                'Wrap(child: ',
                ')',
                imports: [
                  ImportRef('package:flutter/widgets.dart'),
                  ImportRef.app('app.dart'),
                ],
              ),
            ),
          ],
        ),
      ]);

      final main = app.files['lib/main.dart']!;
      expect(
        "import 'package:flutter/widgets.dart';".allMatches(main.text),
        hasLength(1),
      );
      expect("import '".allMatches(main.text), hasLength(3));
      expect(main.addedImports, isEmpty);
    });

    test('cannot go into a part file', () {
      const part = SocketRef<CodeSocket>.module(
        ModuleId('home'),
        'code',
        CodeSocket(),
      );
      expect(
        _failures([
          entry,
          TestModule(
            'home',
            sockets: const [part],
            contributions: [
              _brick({
                'lib/home.dart': "part 'home_part.dart';\n",
                'lib/home_part.dart':
                    "part of 'home.dart';\n\n{{{smf_home__code}}}\n",
              }),
            ],
          ),
          TestModule(
            'child',
            dependsOn: {'home'},
            contributions: [
              const SocketContribution.code(
                part,
                Fragment('void f() {}', imports: [ImportRef('dart:async')]),
              ),
            ],
          ),
        ]),
        [
          equals(
            'home: error [home] lib/home_part.dart: The imports of the socket '
            'home.code cannot go into lib/home_part.dart, which holds its '
            'tag: it is a part of another library. (Put the tag into the '
            'library file.)',
          ),
        ],
      );
    });
  });

  group('variables that depend on a role', () {
    const zeta = ImportRef('package:zeta/zeta.dart', prefix: 'z');
    final nav = TestRole<NoDsl>('nav');
    final go = TestModule('go', providers: [RoleProvider.plain(nav)]);

    /// A module that uses the nav role, with a brick of [files] and [vars].
    TestModule homeWith(Map<String, Object?> vars, Map<String, String> files) =>
        TestModule(
          'home',
          uses: {nav},
          contributions: [_brick(files, vars: vars)],
        );

    test('take their code for an app with the role, or for one without it', () {
      final home = homeWith(
        {
          'start': RoleVar(
            nav,
            present: const Fragment('z.Zeta().start', imports: [zeta]),
            absent: "'/'",
          ),
          'run': RoleVar(
            nav,
            present: const Fragment(
              'Timer.run(go);',
              imports: [ImportRef('dart:async')],
            ),
            absent: const Fragment('print(1);'),
          ),
          'note': RoleVar(nav, present: 'routed & <b>', absent: 'plain'),
        },
        {
          'lib/home/home.dart': 'final start = {{{start}}};\n'
              'void run() {\n'
              '  {{{run}}}\n'
              '}\n',
          // A file that is not Dart reads code without imports.
          'NOTES.md': 'Note: "{{{note}}}"\n',
        },
      );

      final withRole = _render([entry, go, home]);
      final routed = withRole.files['lib/home/home.dart']!;
      expect(
        routed.text,
        "import 'dart:async';\n"
        '\n'
        "import 'package:zeta/zeta.dart' as z;\n"
        '\n'
        'final start = z.Zeta().start;\n'
        'void run() {\n'
        '  Timer.run(go);\n'
        '}\n',
      );
      expect(
        [
          for (final added in routed.addedImports)
            '${added.import.uri} ${added.contributor}',
        ],
        ['package:zeta/zeta.dart home', 'dart:async home'],
      );
      expect(withRole.files['NOTES.md']!.text, 'Note: "routed & <b>"\n');

      final without = _render([entry, home]);
      final plain = without.files['lib/home/home.dart']!;
      expect(
        plain.text,
        "final start = '/';\n"
        'void run() {\n'
        '  print(1);\n'
        '}\n',
      );
      expect(plain.addedImports, isEmpty);
      expect(without.files['NOTES.md']!.text, 'Note: "plain"\n');
    });

    test(
        'are read as fragment variables, in an app with the role and in one '
        'without it', () {
      final home = homeWith(
        {
          'code': RoleVar(
            nav,
            present: const Fragment('z.Zeta()', imports: [zeta]),
            absent: "'none'",
          ),
          // Two strings are code too.
          'text': RoleVar(nav, present: "'a'", absent: "'b'"),
          'flag': true,
        },
        {
          'lib/two.dart': '{{code}}\n',
          'lib/lambda.dart': '{{{code.upperCase()}}}\n',
          'lib/section.dart': '{{#flag}}\n{{{code}}}\n{{/flag}}\n',
          'lib/over.dart': '{{#code}}x{{/code}}\n',
          'lib/{{{code}}}.dart': '',
          'NOTES.md': '{{{code}}}\n',
          'lib/text.dart': '{{text}}\n',
          'lib/{{{text}}}.dart': '',
        },
      );
      final expected = [
        equals(
          'home: error [home] lib/two.dart: The template lib/two.dart in the '
          'brick b of home reads the fragment variable code without three '
          'braces at line 1; read a fragment of code as it is, {{{code}}}.',
        ),
        equals(
          'home: error [home] lib/lambda.dart: The template lib/lambda.dart '
          'in the brick b of home reads the fragment variable code as '
          'code.upperCase() at line 1; read a fragment of code as it is, '
          '{{{code}}}.',
        ),
        equals(
          'home: error [home] lib/section.dart: The template '
          'lib/section.dart in the brick b of home reads the fragment '
          'variable code inside the mustache section flag at line 2; the '
          'presence of the nav role alone decides what the variable holds, '
          'so code that needs another role too goes into a brick of its '
          'own, contributed with when.',
        ),
        equals(
          'home: error [home] lib/over.dart: The template lib/over.dart in '
          'the brick b of home opens a section over the fragment variable '
          'code at line 1; read a fragment of code as it is, {{{code}}}.',
        ),
        equals(
          'home: error [home] lib/{{{code}}}.dart: The path '
          'lib/{{{code}}}.dart in the brick b of home reads the fragment '
          'variable code, but a path takes plain values only. (Set every '
          'variable a path reads, to "" when there is nothing.)',
        ),
        equals(
          'home: error [home] NOTES.md: The template NOTES.md in the brick b '
          'of home is not Dart, but it reads the fragment variable code, '
          'whose imports can only go into a Dart file.',
        ),
        equals(
          'home: error [home] lib/text.dart: The template lib/text.dart in '
          'the brick b of home reads the fragment variable text without '
          'three braces at line 1; read a fragment of code as it is, '
          '{{{text}}}.',
        ),
        equals(
          'home: error [home] lib/{{{text}}}.dart: The path '
          'lib/{{{text}}}.dart in the brick b of home reads the fragment '
          'variable text, but a path takes plain values only. (Set every '
          'variable a path reads, to "" when there is nothing.)',
        ),
      ];

      // A template reads the variable rightly in every app or in none.
      expect(_failures([entry, go, home]), expected);
      expect(_failures([entry, home]), expected);
    });

    test(
        'are read outside the section of the presence flag of another role: '
        'code that needs two roles has a brick of its own', () {
      final texts = TestRole<NoDsl>('texts');
      final translator =
          TestModule('translator', providers: [RoleProvider.plain(texts)]);
      final label = RoleVar(
        texts,
        present: const Fragment('z.label', imports: [zeta]),
        absent: "'Label'",
      );
      TestModule homeOf(BrickContribution brick) => TestModule(
            'home',
            uses: {nav, texts},
            contributions: [brick],
          );
      final apps = <List<SmfModule>>[
        [go, translator],
        [go],
        [translator],
        [],
      ];

      final inSection = homeOf(
        _brick(
          {
            'lib/home.dart': '{{#has_nav}}\n'
                'final label = {{{label}}};\n'
                '{{/has_nav}}\n',
          },
          vars: {'label': label},
        ),
      );
      for (final others in apps) {
        expect(
          _failures([entry, ...others, inSection]),
          [
            equals(
              'home: error [home] lib/home.dart: The template lib/home.dart '
              'in the brick b of home reads the fragment variable label '
              'inside the mustache section has_nav at line 2; the presence '
              'of the texts role alone decides what the variable holds, so '
              'code that needs another role too goes into a brick of its '
              'own, contributed with when.',
            ),
          ],
        );
      }

      final ownBrick = homeOf(
        _brick(
          {'lib/home_nav.dart': 'final label = {{{label}}};\n'},
          vars: {'label': label},
          when: {nav},
        ),
      );
      expect(
        _render([entry, go, translator, ownBrick])
            .files['lib/home_nav.dart']!
            .text,
        "import 'package:zeta/zeta.dart' as z;\n"
        '\n'
        'final label = z.label;\n',
      );
      expect(
        _render([entry, go, ownBrick]).files['lib/home_nav.dart']!.text,
        "final label = 'Label';\n",
      );
      for (final others in apps.skip(2)) {
        expect(
          _render([entry, ...others, ownBrick]).files.keys,
          isNot(contains('lib/home_nav.dart')),
        );
      }
    });

    test(
        'with imports are read by a library, not by a part file, in an app '
        'with the role and in one without it', () {
      final home = homeWith(
        {
          'code': RoleVar(
            nav,
            present: const Fragment('final a = z.Zeta();', imports: [zeta]),
            absent: 'final a = null;',
          ),
        },
        {
          'lib/home.dart': "part 'home_part.dart';\n",
          'lib/home_part.dart': "part of 'home.dart';\n\n{{{code}}}\n",
        },
      );
      final expected = [
        equals(
          'home: error [home] lib/home_part.dart: The imports of the '
          'fragment variable code of home cannot go into '
          'lib/home_part.dart, which reads it: it is a part of another '
          'library. (Read the variable in the library file.)',
        ),
      ];

      expect(_failures([entry, go, home]), expected);
      // The app gets no import, but the app with the role would.
      expect(_failures([entry, home]), expected);
    });

    test('leave no line behind in an app that has no code for them', () {
      final home = homeWith(
        {
          'call': RoleVar(nav, present: const Fragment('go();'), absent: ''),
          'other': RoleVar(nav, present: '', absent: const Fragment('stay();')),
        },
        {
          'lib/home.dart': 'void run() {\n'
              '  {{{call}}}\n'
              '  {{{other}}}\n'
              '}\n',
        },
      );

      expect(
        _render([entry, go, home]).files['lib/home.dart']!.text,
        'void run() {\n  go();\n}\n',
      );
      expect(
        _render([entry, home]).files['lib/home.dart']!.text,
        'void run() {\n  stay();\n}\n',
      );
    });

    test('need no template that reads them, like any variable of a brick', () {
      final home = homeWith(
        {
          'code': RoleVar(
            nav,
            present: const Fragment('z.Zeta()', imports: [zeta]),
            absent: "'none'",
          ),
        },
        {'lib/home.dart': '// nothing\n'},
      );

      for (final app in [
        _render([entry, go, home]),
        _render([entry, home]),
      ]) {
        expect(app.files['lib/home.dart']!.text, '// nothing\n');
        expect(app.files['lib/home.dart']!.addedImports, isEmpty);
      }
    });

    test('that a render hook of their owner sets too are an error', () {
      final rendering = _Rendering(
        providerOutput: const RoleOutput(vars: {'title': 'hook'}),
      );
      expect(
        _failures([
          entry,
          TestModule(
            'store',
            uses: {nav},
            providers: [rendering.provider],
            contributions: [
              _brick(
                {'lib/s.dart': '{{{title}}}'},
                vars: {
                  'title': RoleVar(
                    nav,
                    present: const Fragment('a'),
                    absent: 'b',
                  ),
                },
              ),
            ],
          ),
        ]),
        [
          equals(
            'store: error [store]: The brick b of store sets the variable '
            'title, which a render hook of store sets too.',
          ),
        ],
      );
    });

    test('of the brick of a variant bring their imports for the variant', () {
      final state = TestRole<NoDsl>('state');
      final app = _render(variants: {
        'home': 'bloc',
      }, [
        entry,
        go,
        TestModule('bloc', providers: [RoleProvider.plain(state)]),
        TestModule(
          'home',
          uses: {nav},
          variants: Variants(
            role: state,
            byProvider: {
              const ModuleId('bloc'): (context) => [
                    _brick(
                      {'lib/v.dart': '{{{code}}}\n'},
                      vars: {
                        'code': RoleVar(
                          nav,
                          present: const Fragment(
                            'final zeta = z.Zeta();',
                            imports: [zeta],
                          ),
                          absent: '',
                        ),
                      },
                    ),
                  ],
            },
          ),
        ),
      ]);

      final variant = app.files['lib/v.dart']!;
      expect(
        variant.text,
        "import 'package:zeta/zeta.dart' as z;\n"
        '\n'
        'final zeta = z.Zeta();\n',
      );
      expect(
        variant.addedImports.single.contributor,
        const ModuleOrigin(ModuleId('home'), variant: ModuleId('bloc')),
      );
    });

    test(
        'are no variables of a render hook, which asks for the roles of its '
        'role itself', () {
      final rendering = _Rendering(
        providerOutput: RoleOutput(
          vars: {'title': RoleVar(nav, present: 'a', absent: 'b')},
        ),
      );
      expect(
        _failures([
          entry,
          TestModule(
            'store',
            uses: {nav},
            providers: [rendering.provider],
            contributions: [
              _brick({'lib/s.dart': '{{title}}'}),
            ],
          ),
        ]),
        [
          equals(
            'store: error [store]: The brick variable title of the render '
            'hook of store is not plain data: strings, numbers, booleans, '
            'and lists and maps of them, or a fragment of code.',
          ),
        ],
      );
    });
  });

  group('fragment variables', () {
    const zeta = ImportRef('package:zeta/zeta.dart', prefix: 'z');

    /// A module whose provider's render hook returns [vars], with the
    /// brick of [files].
    List<SmfModule> withVars(
      Map<String, Object?> vars,
      Map<String, String> files,
    ) {
      final rendering = _Rendering(providerOutput: RoleOutput(vars: vars));
      return [
        entry,
        TestModule(
          'store',
          providers: [rendering.provider],
          contributions: [_brick(files)],
        ),
      ];
    }

    test(
        'render as their code and bring their imports into the Dart files '
        'that read them', () {
      final app = _render(
        withVars(
          {
            'routes': const Fragment(
              'final routes = [z.Zeta(), Timer];',
              imports: [zeta, ImportRef('dart:async')],
            ),
            'title': 'Shelf',
            'empty': const Fragment(''),
          },
          {
            'lib/store.dart': "import 'dart:async';\n"
                '\n'
                '// {{title}}\n'
                '{{{routes}}}\n'
                '{{{empty}}}\n'
                '  {{{ empty }}}  \n'
                '// end\n',
            'lib/again.dart': '{{{routes}}}\n',
            // A Dart file of the owner that does not read the variable.
            'lib/other.dart': '// {{title}}\n',
            'NOTES.md': 'Empty: "{{{empty}}}"\n',
          },
        ),
      );

      final store = app.files['lib/store.dart']!;
      expect(
        store.text,
        "import 'dart:async';\n"
        '\n'
        "import 'package:zeta/zeta.dart' as z;\n"
        '\n'
        '// Shelf\n'
        'final routes = [z.Zeta(), Timer];\n'
        '// end\n',
      );
      expect(
        [
          for (final added in store.addedImports)
            (added.import.uri, added.import.prefix, '${added.contributor}'),
        ],
        [('package:zeta/zeta.dart', 'z', 'store')],
      );
      expect(
        app.files['lib/again.dart']!.text,
        "import 'dart:async';\n"
        '\n'
        "import 'package:zeta/zeta.dart' as z;\n"
        '\n'
        'final routes = [z.Zeta(), Timer];\n',
      );
      expect(app.files['lib/other.dart']!.text, '// Shelf\n');
      expect(app.files['lib/other.dart']!.addedImports, isEmpty);
      expect(app.files['NOTES.md']!.text, 'Empty: ""\n');
    });

    test(
        'share an import with a socket in a file, which names both '
        'contributors', () {
      final rendering = _Rendering(
        providerOutput: const RoleOutput(
          vars: {
            'code': Fragment('final zeta = z.Zeta();', imports: [zeta]),
          },
        ),
      );
      final app = _render([
        entry,
        TestModule(
          'store',
          providers: [rendering.provider],
          contributions: [
            _brick({'lib/store.dart': '{{{code}}}\n{{{smf_shelf__items}}}\n'}),
          ],
        ),
        TestModule(
          'user',
          requires: {rendering.role},
          contributions: [
            SocketContribution.code(
              rendering.items,
              const Fragment('final other = z.Zeta();', imports: [zeta]),
            ),
          ],
        ),
      ]);

      final store = app.files['lib/store.dart']!;
      const directive = "import 'package:zeta/zeta.dart' as z;";
      expect(directive.allMatches(store.text), hasLength(1));
      expect(
        [for (final added in store.addedImports) '${added.contributor}'],
        unorderedEquals(['store', 'user']),
      );
    });

    test("go into the bricks of the owner's variant", () {
      final state = TestRole<NoDsl>('state');
      final rendering = _Rendering(
        providerOutput: const RoleOutput(
          vars: {
            'code': Fragment('final zeta = z.Zeta();', imports: [zeta]),
          },
        ),
      );
      final app = _render(variants: {
        'store': 'bloc',
      }, [
        entry,
        TestModule('bloc', providers: [RoleProvider.plain(state)]),
        TestModule(
          'store',
          providers: [rendering.provider],
          variants: Variants(
            role: state,
            byProvider: {
              const ModuleId('bloc'): (context) => [
                    _brick({'lib/v.dart': '{{{code}}}\n'}),
                  ],
            },
          ),
        ),
      ]);

      final variant = app.files['lib/v.dart']!;
      expect(
        variant.text,
        "import 'package:zeta/zeta.dart' as z;\n"
        '\n'
        'final zeta = z.Zeta();\n',
      );
      expect(
        variant.addedImports.single.contributor,
        const ModuleOrigin(ModuleId('store')),
      );
    });

    test('are fragments of code with valid imports', () {
      expect(
        _failures(
          withVars(
            {
              'wrapper': const Fragment.wrap('Wrap(child: ', ')'),
              'bad': const Fragment('x', imports: [ImportRef('zeta.dart')]),
              'nested': const [Fragment('x')],
            },
            {'lib/a.dart': '{{{wrapper}}} {{{bad}}} {{#nested}}{{/nested}}'},
          ),
        ),
        [
          equals(
            'store: error [store]: The fragment variable wrapper of the '
            'render hook of store is a Fragment.wrap, but a variable takes a '
            'Fragment of code.',
          ),
          startsWith(
            'store: error [store]: The fragment variable bad of the render '
            'hook of store has an invalid import. The import "zeta.dart" '
            'must be a dart: or package: URI',
          ),
          equals(
            'store: error [store]: The brick variable nested of the render '
            'hook of store is not plain data: strings, numbers, booleans, '
            'and lists and maps of them, or a fragment of code.',
          ),
        ],
      );
    });

    test('are read as they are, outside sections, and by Dart with imports',
        () {
      const code = Fragment('z.Zeta()', imports: [zeta]);
      expect(
        _failures(
          withVars(
            {
              'code': code,
              'items': const ['a'],
              'flag': true,
            },
            {
              'lib/two.dart': '{{code}}\n',
              'lib/lambda.dart': '{{{code.upperCase()}}}\n',
              'lib/section.dart': '{{#flag}}\n{{{code}}}\n{{/flag}}\n',
              'lib/over.dart': '{{#code}}x{{/code}}\n',
              'NOTES.md': '{{{code}}}\n',
            },
          ),
        ),
        [
          equals(
            'store: error [store] lib/two.dart: The template lib/two.dart in '
            'the brick b of store reads the fragment variable code without '
            'three braces at line 1; read a fragment of code as it is, '
            '{{{code}}}.',
          ),
          equals(
            'store: error [store] lib/lambda.dart: The template '
            'lib/lambda.dart in the brick b of store reads the fragment '
            'variable code as code.upperCase() at line 1; read a fragment of '
            'code as it is, {{{code}}}.',
          ),
          equals(
            'store: error [store] lib/section.dart: The template '
            'lib/section.dart in the brick b of store reads the fragment '
            'variable code inside the mustache section flag at line 2; the '
            'render hook decides what the variable holds instead.',
          ),
          equals(
            'store: error [store] lib/over.dart: The template lib/over.dart '
            'in the brick b of store opens a section over the fragment '
            'variable code at line 1; read a fragment of code as it is, '
            '{{{code}}}.',
          ),
          equals(
            'store: error [store] NOTES.md: The template NOTES.md in the '
            'brick b of store is not Dart, but it reads the fragment '
            'variable code, whose imports can only go into a Dart file.',
          ),
        ],
      );
    });

    test('read by a template with another problem are read', () {
      expect(
        _failures(
          withVars(
            {
              'code': const Fragment('z.Zeta()', imports: [zeta]),
            },
            {'lib/a.dart': '{{{code}}}\n// {{missing}}\n'},
          ),
        ),
        [
          startsWith(
            'store: error [store] lib/a.dart: The template lib/a.dart in the '
            'brick b of store reads missing, which neither',
          ),
        ],
      );
    });

    test('with a backslash that mason would remove are an error', () {
      expect(
        _failures(
          withVars(
            {'code': const Fragment('a\\\nb')},
            {'lib/a.dart': '{{{code}}}\n'},
          ),
        ),
        [
          equals(
            'store: error [store]: The brick variable code of the render '
            'hook of store has a backslash before a line break or a '
            'non-ASCII character, which mason removes.',
          ),
        ],
      );
    });

    test('read wrongly are reported once', () {
      expect(
        _failures(
          withVars(
            {
              'code': const Fragment('z.Zeta()', imports: [zeta]),
            },
            {'lib/a.dart': '{{code}}\n'},
          ),
        ),
        [
          equals(
            'store: error [store] lib/a.dart: The template lib/a.dart in the '
            'brick b of store reads the fragment variable code without three '
            'braces at line 1; read a fragment of code as it is, {{{code}}}.',
          ),
        ],
      );
    });

    test('that only a brick left out of the app reads are left out', () {
      final layout = TestRole<NoDsl>('layout');
      final rendering = _Rendering(
        providerOutput: const RoleOutput(
          vars: {
            'branches': Fragment('final b = z.Zeta();', imports: [zeta]),
          },
        ),
      );
      final app = _render([
        entry,
        TestModule(
          'store',
          uses: {layout},
          providers: [rendering.provider],
          contributions: [
            _brick({'lib/branches.dart': '{{{branches}}}\n'}, when: {layout}),
          ],
        ),
      ]);

      expect(app.files.keys, isNot(contains('lib/branches.dart')));
    });

    test('that no template reads are an error', () {
      expect(
        _failures(
          withVars(
            {
              'code': const Fragment('z.Zeta()', imports: [zeta]),
            },
            {'lib/a.dart': '// nothing\n'},
          ),
        ),
        [
          equals(
            'store: error [store]: The render hook of store sets the fragment '
            'variable code, which no template of store reads, so its code '
            'would be lost.',
          ),
        ],
      );
    });

    test('cannot bring imports into a part file', () {
      expect(
        _failures(
          withVars(
            {
              'code': const Fragment('final a = z.Zeta();', imports: [zeta]),
            },
            {
              'lib/store.dart': "part 'store_part.dart';\n",
              'lib/store_part.dart': "part of 'store.dart';\n\n{{{code}}}\n",
            },
          ),
        ),
        [
          equals(
            'store: error [store] lib/store_part.dart: The imports of the '
            'fragment variable code of store cannot go into '
            'lib/store_part.dart, which reads it: it is a part of another '
            'library. (Read the variable in the library file.)',
          ),
        ],
      );
    });
  });
}
