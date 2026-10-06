import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import '../support.dart';

String _join(List<MapEntry<String, String>> entries) =>
    [for (final entry in entries) '${entry.key}: ${entry.value}'].join('\n');

/// A role with an interface and rules, which [TestRole] has not.
final class _ShellRole extends Role<NoDsl> {
  const _ShellRole();

  static const shellFile = 'lib/core/shell/shell.dart';

  @override
  String get id => 'shell';

  @override
  String get description => 'Shell';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  RoleInterface get interface => const RoleInterface(
        files: ['lib/core/shell/item.dart'],
        symbols: [
          RequiredClass(
            'Shell',
            path: shellFile,
            namedParameters: ['items'],
            getters: ['count'],
          ),
          RequiredFunction('createShell', path: shellFile),
          RequiredExtension(
            'ShellOf',
            path: shellFile,
            on: 'BuildContext',
            getters: ['shell'],
          ),
        ],
      );

  @override
  List<StructuralRule<NoDsl>> get structuralRules => const [
        StructuralRule(
          id: 'shell.opened',
          description: 'createShell() calls openShell() once.',
          check: _noIssues,
        ),
      ];

  @override
  List<ModuleRule<NoDsl>> get moduleRules => const [
        ModuleRule(
          id: 'shell.tagged',
          description: 'The provider passes tagged: to its Shell.',
          check: _noModuleIssues,
        ),
      ];
}

List<SmfIssue> _noIssues(StructuralRuleInput<NoDsl> input) => const [];

List<SmfIssue> _noModuleIssues(ModuleRuleInput<NoDsl> input) => const [];

void main() {
  final nav = TestRole<NoDsl>('nav');
  final many = TestRole<NoDsl>('logs', cardinality: RoleCardinality.many);
  const shell = _ShellRole();
  final notes = SocketRef<KeyedSocket<String>>.role(
    nav,
    'notes',
    const KeyedSocket(policy: ConflictPolicy(), renderer: _join),
  );

  final goNav = TestModule('go_nav', providers: [RoleProvider.plain(nav)]);
  final home = TestModule('home');
  const ofNav = ModuleOrigin(ModuleId('go_nav'));
  const ofHome = ModuleOrigin(ModuleId('home'));
  final template = RoleTemplateOrigin(nav);

  RenderedFile file(String path, ContributionOrigin owner, String text) =>
      RenderedFile(path: path, bytes: utf8.encode(text), owner: owner);

  /// The result of a case [name] whose app has [modules], [files], the
  /// [notes] of its contributors, each under a heading, and [dependencies].
  ContractResult app(
    String name, {
    List<SmfModule>? modules,
    List<RenderedFile> files = const [],
    List<(ContributionOrigin, String, String)> entries = const [],
    Map<String, MergedDependency> dependencies = const {},
    Map<String, MergedDependency> devDependencies = const {},
  }) =>
      ContractResult(
        ContractCase(name, requested: const []),
        const [],
        resolution: Resolution([
          for (final module in modules ?? [goNav, home])
            ResolvedModule(module, const Requested()),
        ]),
        validation: ValidationResult(
          issues: const [],
          socketOrders: const {},
          postGenOrder: const ContributionOrder(contributions: [], edges: []),
          pubspec: MergedPubspec(
            dependencies: dependencies,
            devDependencies: devDependencies,
          ),
        ),
        app: RenderedApp(
          files,
          socketOrders: {
            notes: ContributionOrder(
              contributions: [
                for (final (origin, heading, text) in entries)
                  Collected(
                    notes.entry(heading, text).withOrigin(origin),
                    origin,
                    applies: true,
                  ),
              ],
              edges: const [],
            ),
          },
        ),
      );

  /// What the checker finds in the note [text] of the role `nav`, in an app
  /// with [files] and [dependencies], each without what every line has.
  List<String> problemsOf(
    String text, {
    List<RenderedFile> files = const [],
    Map<String, MergedDependency> dependencies = const {},
    Map<String, MergedDependency> devDependencies = const {},
  }) =>
      [
        for (final problem in roleNoteProblems(
          [
            app(
              'the case',
              files: files,
              entries: [(template, 'Nav', text)],
              dependencies: dependencies,
              devDependencies: devDependencies,
            ),
          ],
          notes,
          textOf: (text) => text,
        ))
          problem
              .replaceFirst('The note of the nav role under "Nav" ', '')
              .replaceFirst(' (in the app of the case).', ''),
      ];

  MergedDependency hosted(String package, ContributionOrigin origin) =>
      MergedDependency(
        package,
        source: PubspecSource.hosted,
        origins: [origin],
      );

  test('finds nothing in a note of what the role and other modules have', () {
    expect(
      problemsOf(
        'Navigate with `context.nav`, never with the router itself.\n'
        '\n'
        '- `lib/core/nav/facade.dart` has `NavLink`, whose `go()` shows a '
        'location. The home is in `lib/features/home/`.\n',
        files: [
          file(
            'lib/core/nav/facade.dart',
            template,
            'class NavLink { void go() {} }\n'
                'extension Nav on Object { int get nav => 0; }\n',
          ),
          file('lib/features/home/home.dart', ofHome, 'class Home {}\n'),
          file('lib/core/nav/router.dart', ofNav, 'final router = 1;\n'),
        ],
      ),
      isEmpty,
    );
  });

  test('names the note, its heading, the role and the case of the app', () {
    expect(
      roleNoteProblems(
        [
          app('home with nav', entries: [(template, 'Routes', 'Use go_nav.')]),
        ],
        notes,
        textOf: (text) => text,
      ).single,
      'The note of the nav role under "Routes" names go_nav, the id of a '
      'module that provides the role (in the app of home with nav).',
    );
  });

  group('the id of a module that provides the role', () {
    const named = 'names go_nav, the id of a module that provides the role';

    test('is found in the text, in inline code and in a fenced block', () {
      for (final text in [
        'The routes are those of go_nav.',
        'Never import `package:go_nav/go_nav.dart`.',
        'Run:\n\n```bash\ndart run go_nav:routes\n```\n',
        'With ~~~ too:\n\n~~~\ngo_nav\n~~~~\nAnd the text goes on.',
        // The name of a tool, with a hyphen for the underscore of the id.
        'The tool `go-nav` writes the routes.',
      ]) {
        expect(problemsOf(text), [named], reason: text);
      }
    });

    test('is a word of its own, in the case of the id', () {
      for (final text in [
        'The routes of go_navigator.',
        'A `mango_nav` and a `Go_Nav`.',
        'Go, nav.',
      ]) {
        expect(problemsOf(text), isEmpty, reason: text);
      }
    });

    test(
        'whose words are words of the role counts only in code, since the '
        'text cannot tell it from the role', () {
      final settingsScreen = TestRole<NoDsl>('settings_screen');
      final settings = TestModule(
        'settings',
        providers: [RoleProvider.plain(settingsScreen)],
      );
      List<String> problems(String text) => roleNoteProblems(
            [
              app(
                'settings',
                modules: [settings],
                entries: [(RoleTemplateOrigin(settingsScreen), 'S', text)],
              ),
            ],
            notes,
            textOf: (text) => text,
          );

      expect(
        problems('An entry of the settings screen opens a page.'),
        isEmpty,
      );
      expect(
        problems('Open it with `context.nav.settings.settings()`.').single,
        contains('names settings, the id of a module that provides the role'),
      );
    });

    test('of a module that provides another role is no matter of the note', () {
      expect(problemsOf('The services come from `home`.'), isEmpty);
    });
  });

  group('a package that a provider adds', () {
    test('is found in the text and in code, a dev dependency too', () {
      expect(
        problemsOf(
          'The routes are those of nav_kit, which `nav_lints` checks.',
          dependencies: {'nav_kit': hosted('nav_kit', ofNav)},
          devDependencies: {'nav_lints': hosted('nav_lints', ofNav)},
        ),
        [
          'names nav_kit, a package that go_nav adds',
          'names nav_lints, a package that go_nav adds',
        ],
      );
    });

    test('is not one of an SDK, of another module or of a template', () {
      expect(
        problemsOf(
          'With `flutter_nav`, `home_kit` and `role_kit`.',
          dependencies: {
            'flutter_nav': const MergedDependency(
              'flutter_nav',
              source: PubspecSource.sdk,
              origins: [ofNav],
              sdk: 'flutter',
            ),
            'home_kit': hosted('home_kit', ofHome),
            'role_kit': hosted('role_kit', template),
          },
        ),
        isEmpty,
      );
    });

    test('with the name of the provider is reported as its id', () {
      expect(
        problemsOf(
          'With `go_nav`.',
          dependencies: {'go_nav': hosted('go_nav', ofNav)},
        ),
        ['names go_nav, the id of a module that provides the role'],
      );
    });
  });

  group('a name that only the files of the providers declare', () {
    final files = [
      file(
        'lib/core/nav/router.dart',
        ofNav,
        "import 'dart:async' as screen0;\n"
            'Object createRouter() => _Engine();\n'
            'class _Engine { int spin = 0; void build() {} }\n',
      ),
      file(
        'lib/features/home/home.dart',
        ofHome,
        'class Home { void build() {} }\n',
      ),
    ];

    String declares(String name) =>
        'names `$name`, which only lib/core/nav/router.dart of go_nav '
        'declares';

    test('is found at the top level, as a member and as an import prefix', () {
      expect(
        problemsOf(
          '`createRouter()` returns the `_Engine`, whose `spin` counts. A '
          'screen is imported as `screen0`.',
          files: files,
        ),
        ['createRouter', '_Engine', 'spin', 'screen0'].map(declares),
      );
    });

    test('is found in a fenced code block too, once', () {
      expect(
        problemsOf(
          'As in:\n\n```dart\ncreateRouter();\ncreateRouter();\n```\n',
          files: files,
        ),
        [declares('createRouter')],
      );
    });

    test('is none that another file declares too', () {
      expect(problemsOf('Every screen has `build()`.', files: files), isEmpty);
    });

    test('is not looked for in the text, in a path or in a placeholder', () {
      expect(
        problemsOf(
          'To spin is no name of code. `lib/spin/createRouter.dart` is a '
          'path, and `<spin>.<route>` a pattern.',
          files: files,
        ),
        isEmpty,
      );
    });

    test('is not one of a file that is no Dart code', () {
      expect(
        problemsOf(
          'The `Guide` and the `Icon`.',
          files: [
            file('docs/nav.md', ofNav, 'class Guide {}\n'),
            RenderedFile(
              path: 'lib/core/nav/icon.dart',
              bytes: utf8.encode('class Icon {}\n'),
              owner: ofNav,
              isText: false,
            ),
          ],
        ),
        isEmpty,
      );
    });
  });

  group('a name that only the files of the providers use', () {
    final files = [
      file(
        'lib/core/nav/router.dart',
        ofNav,
        '// The NavGuide tells more.\n'
            'Object createRouter(Object kit) {\n'
            "  const title = 'NavTitle';\n"
            '  final NavState? last = null;\n'
            '  final local = NavKit(depth: 2);\n'
            '  openKit(local);\n'
            '  return [local.stack, kit, last, title, Shared(), Home()];\n'
            '}\n',
      ),
      file(
        'lib/features/home/home.dart',
        ofHome,
        'class Home { Object build() => Shared(); }\n',
      ),
    ];

    test(
        'is a name in upper camel case, as of a type, a function, a named '
        'argument or a member that no file of the app declares', () {
      expect(
        problemsOf(
          'The router is a `NavKit` with a `depth`, which `openKit()` '
          'opens. Its pages are its `stack`, and it keeps a `NavState`.',
          files: files,
        ),
        ['NavKit', 'depth', 'openKit', 'stack', 'NavState'].map(
          (name) =>
              'names `$name`, which only lib/core/nav/router.dart of go_nav '
              'uses',
        ),
      );
    });

    test(
        'is none that another file uses too, that a file of the app '
        'declares, that may be a local variable, or that stands in a comment '
        'or in a string', () {
      expect(
        problemsOf(
          'A `Shared` thing, the `Home`, a `local` or a `kit`, the '
          '`NavGuide` of a comment and the `NavTitle` of a string.',
          files: files,
        ),
        isEmpty,
      );
    });
  });

  group('a name that a role guarantees', () {
    final provider = TestModule(
      'tabs',
      providers: const [RoleProvider.plain(shell)],
    );
    const ofTabs = ModuleOrigin(ModuleId('tabs'));
    const shellTemplate = RoleTemplateOrigin(shell);
    final files = [
      file(
        _ShellRole.shellFile,
        ofTabs,
        'Shell createShell() { openShell(); return Shell(tagged: true); }\n'
        'class Shell {\n'
        '  Shell({this.items = const [], this.tagged = false});\n'
        '  final List<Object> items;\n'
        '  final bool tagged;\n'
        '  int get count => items.length;\n'
        '  int get _hidden => 0;\n'
        '}\n'
        'extension ShellOf on Object { Shell get shell => Shell(); }\n',
      ),
    ];
    List<String> problems(String text) => roleNoteProblems(
          [
            app(
              'tabs',
              modules: [provider],
              files: files,
              entries: [(shellTemplate, 'Shell', text)],
            ),
          ],
          notes,
          textOf: (text) => text,
        );

    test(
        'is a symbol of its interface with its parameters and getters, or a '
        'name in the description of one of its rules', () {
      expect(
        problems(
          '`createShell()` creates the `Shell` with its `items`, whose '
          '`count` the bar shows, and `ShellOf` gives it as `context.shell`. '
          'It calls `openShell()` and passes `tagged:`. The file is '
          '`${_ShellRole.shellFile}`, next to `lib/core/shell/`.',
        ),
        isEmpty,
      );
    });

    test('is not what the provider has beyond that', () {
      expect(
        problems('The `Shell` has a `_hidden` count.').single,
        contains(
          'names `_hidden`, which only ${_ShellRole.shellFile} of tabs '
          'declares',
        ),
      );
    });
  });

  group('a file or a directory that only the providers generate', () {
    final files = [
      file('lib/core/nav/router.dart', ofNav, ''),
      file('lib/core/nav/engine/gears.dart', ofNav, ''),
      file('lib/core/facade/facade.dart', template, ''),
      file('lib/features/home/home.dart', ofHome, ''),
    ];

    test('is found in inline code, with or without a slash at its end', () {
      expect(
        problemsOf(
          'The routes are in `lib/core/nav/router.dart`, in `lib/core/nav/`, '
          'below `lib/core/nav/engine`.',
          files: files,
        ),
        ['lib/core/nav/router.dart', 'lib/core/nav/', 'lib/core/nav/engine']
            .map(
          (span) => 'names `$span`, which only go_nav generates and no role '
              'guarantees',
        ),
      );
    });

    test('is none that another owner has a file in, or that no app has', () {
      expect(
        problemsOf(
          '`lib/core/` and `lib/` have the files of the app, as '
          '`lib/core/facade/facade.dart`. `lib/core/navigation/` is another '
          'directory, and `lib/features/home/home.dart` a file of the home.',
          files: files,
        ),
        isEmpty,
      );
    });

    test('is named with every provider that generates it', () {
      final first = TestModule('a_log', providers: [RoleProvider.plain(many)]);
      final second = TestModule('b_log', providers: [RoleProvider.plain(many)]);
      expect(
        roleNoteProblems(
          [
            app(
              'logs',
              modules: [first, second],
              files: [
                for (final log in ['a', 'b'])
                  file(
                    'lib/logs/$log.dart',
                    ModuleOrigin(ModuleId('${log}_log')),
                    '',
                  ),
              ],
              entries: [
                (RoleTemplateOrigin(many), 'Logs', 'See `lib/logs/`.'),
              ],
            ),
          ],
          notes,
          textOf: (text) => text,
        ).single,
        contains(
          'names `lib/logs/`, which only a_log and b_log generate and no '
          'role guarantees',
        ),
      );
    });
  });

  test(
      'reads the notes of the templates of roles only, each note once, in '
      'the apps that rendered, with the files of every app', () {
    const withoutApp = ContractResult(
      ContractCase('failed', requested: []),
      [SmfIssue('The case does not resolve.')],
    );
    final problems = roleNoteProblems(
      [
        withoutApp,
        app(
          'first',
          entries: [
            // A module may name itself and what it has.
            (ofNav, 'Nav', 'With go_nav: `createRouter()`.'),
            (ofHome, 'Home', 'After go_nav.'),
            (template, 'Nav', 'Call `createRouter()`.'),
          ],
        ),
        app(
          'second',
          files: [
            file('lib/core/nav/router.dart', ofNav, 'void createRouter() {}\n'),
          ],
          entries: [(template, 'Nav', 'Call `createRouter()`.')],
        ),
        // The same file again, and a provider without files.
        app(
          'third',
          modules: [
            goNav,
            TestModule('idle_nav', providers: [RoleProvider.plain(many)]),
          ],
          files: [
            file('lib/core/nav/router.dart', ofNav, 'void createRouter() {}\n'),
          ],
          entries: [(RoleTemplateOrigin(many), 'Logs', 'Nothing to tell.')],
        ),
      ],
      notes,
      textOf: (text) => text,
    );

    expect(
      problems.single,
      'The note of the nav role under "Nav" names `createRouter`, which only '
      'lib/core/nav/router.dart of go_nav declares (in the app of first).',
    );
  });
}
