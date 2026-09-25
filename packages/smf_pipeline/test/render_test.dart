import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/src/render.dart';
import 'package:test/test.dart';

import 'support.dart';

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

void main() {
  final entry = scaffold(contributions: [entryBrick()]);

  test('renders the bricks with the names, flags, tags and variables', () {
    final nav = TestRole<NoDsl>('nav');
    final absent = TestRole<NoDsl>('absent');
    final app = _render([
      scaffold(
        contributions: [
          entryBrick(),
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
          entryBrick(),
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
  build_runner: "^2.7.0"

flutter:
  uses-material-design: true
  assets:
    - "assets/"
''');
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
  });

  test('render hooks follow the rules of their owners', () {
    final other = TestRole<NoDsl>('other');
    final rendering = _Rendering(
      templateOutput: const RoleOutput(
        vars: {'app_name': 'x', 'has_it': true, 'bad': 'a\\\nb'},
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
          'store puts code into the socket other.code, but does not provide, '
          'require or use the other.',
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

  test('code for a socket without a tag is an error, not lost', () {
    final rendering = _Rendering();
    expect(
      _failures([
        entry,
        TestModule('store', providers: [rendering.provider]),
        TestModule(
          'user',
          requires: {rendering.role},
          contributions: [
            SocketContribution.code(rendering.items, const Fragment('a();')),
          ],
        ),
      ]),
      [
        equals(
          'user: error [user]: user contributes to the socket shelf.items, but '
          'no template of the app has its tag smf_shelf__items, so the code '
          'would be lost.',
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
            entryBrick(),
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
            entryBrick(),
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
                },
                vars: {'up': '..', 'root': '/etc'},
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
          contains('renders to "lib//z.dart", which has an empty segment.'),
          contains('renders to "lib/&#x2F;etc.dart", which has an HTML '
              'entity'),
        ],
      );
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

    test('a template that mason cannot render is an error of its owner', () {
      final failures = _failures([
        entry,
        TestModule(
          'home',
          contributions: [
            _brick({'lib/a.dart': '{{#open}}never closed'}),
          ],
        ),
      ]);

      expect(
        failures.single,
        startsWith(
          'home: error [home] lib/a.dart: The template lib/a.dart in the '
          'brick b of home cannot be rendered:',
        ),
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

  group('imports', () {
    test('go into the file with the tag, among its imports', () {
      final app = _render([
        scaffold(
          contributions: [
            entryBrick(),
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
            entryBrick(),
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
}
