import 'dart:convert';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import '../support.dart';

String _join(List<MapEntry<String, String>> entries) =>
    [for (final entry in entries) '${entry.key}: ${entry.value}'].join('\n');

/// A role with an interface and rules, which [TestRole] has not, and with a
/// description of other words than its id.
final class _ShellRole extends Role<NoDsl> {
  const _ShellRole();

  static const shellFile = 'lib/core/shell/shell.dart';

  @override
  String get id => 'shell';

  @override
  String get description => 'Main frame';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;

  @override
  RoleInterface get interface => const RoleInterface(
        symbols: [
          RequiredClass(
            'Shell',
            path: shellFile,
            namedParameters: ['items'],
            getters: ['count'],
          ),
          RequiredFunction(
            'createShell',
            path: shellFile,
            returnType: 'Future<ShellKit>',
          ),
          RequiredFunction('closeShell', path: shellFile),
          RequiredExtension(
            'ShellOf',
            path: shellFile,
            on: 'ShellHost',
            getters: ['area'],
          ),
        ],
      );

  @override
  List<StructuralRule<NoDsl>> get structuralRules => const [
        StructuralRule(
          id: 'shell.opened',
          description: 'Every provider calls open() once, with the '
              'ShellBar that it builds and its shell_key.',
          check: _noIssues,
        ),
      ];

  @override
  List<ModuleRule<NoDsl>> get moduleRules => const [
        ModuleRule(
          id: 'shell.tagged',
          description: 'The provider keeps what it marked in shellMarks.',
          check: _noModuleIssues,
        ),
      ];
}

List<SmfIssue> _noIssues(StructuralRuleInput<NoDsl> input) => const [];

List<SmfIssue> _noModuleIssues(ModuleRuleInput<NoDsl> input) => const [];

void main() {
  final nav = TestRole<NoDsl>('nav');
  final logs = TestRole<NoDsl>('logs', cardinality: RoleCardinality.many);
  const shell = _ShellRole();
  final notes = SocketRef<KeyedSocket<String>>.role(
    nav,
    'notes',
    const KeyedSocket(policy: ConflictPolicy(), renderer: _join),
  );

  // The provider of the role `nav`, the module that it depends on, and a
  // module behind no role.
  final goNav = TestModule(
    'go_nav',
    providers: [RoleProvider.plain(nav)],
    dependsOn: {'nav_base'},
  );
  final navBase = TestModule('nav_base');
  final home = TestModule('home');
  const ofNav = ModuleOrigin(ModuleId('go_nav'));
  const ofBase = ModuleOrigin(ModuleId('nav_base'));
  const ofHome = ModuleOrigin(ModuleId('home'));
  final template = RoleTemplateOrigin(nav);

  const providesNav = 'a module that provides the nav role';
  const providesLogs = 'a module that provides the logs role';
  const providesShell = 'a module that provides the main frame role';
  const dependedOn = 'a module that go_nav depends on';

  /// The end of a line about [token], which has the words of [name].
  String withWords(String token, String name, String what) =>
      '$token, which has the words of $name, $what';

  /// The end of a line about [name], which only [path] of [module] declares.
  String declaredIn(String name, String path, String module, String what) =>
      '`$name`, which only $path of $module declares, $what';

  RenderedFile file(
    String path,
    ContributionOrigin owner,
    String text, {
    List<AddedImport> addedImports = const [],
  }) =>
      RenderedFile(
        path: path,
        bytes: utf8.encode(text),
        owner: owner,
        addedImports: addedImports,
      );

  MergedDependency hosted(String package, ContributionOrigin origin) =>
      MergedDependency(
        package,
        source: PubspecSource.hosted,
        origins: [origin],
      );

  /// The result of a case [name] whose app has [modules], [files], the
  /// notes of its contributors, each under a heading, and [dependencies].
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
          for (final module in modules ?? [goNav, navBase, home])
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

  /// The lines of the checker without what every line of the note of the
  /// role `nav` under "Nav" in the app of "the case" has.
  List<String> short(List<String> lines) => [
        for (final line in lines)
          line
              .replaceFirst('The note of the nav role under "Nav" names ', '')
              .replaceFirst(' (in the app of the case).', ''),
      ];

  /// What the checker finds in the note [text] of the role `nav`, in an app
  /// with [files] and [dependencies], and in the [others].
  List<String> problemsOf(
    String text, {
    List<SmfModule>? modules,
    List<RenderedFile> files = const [],
    Map<String, MergedDependency> dependencies = const {},
    Map<String, MergedDependency> devDependencies = const {},
    List<ContractResult> others = const [],
    Map<String, String> allowed = const {},
  }) =>
      short(
        roleNoteProblems(
          [
            app(
              'the case',
              modules: modules,
              files: files,
              entries: [(template, 'Nav', text)],
              dependencies: dependencies,
              devDependencies: devDependencies,
            ),
            ...others,
          ],
          notes,
          textOf: (text) => text,
          allowed: allowed,
        ),
      );

  test('finds nothing in a note of what the roles and other modules have', () {
    expect(
      problemsOf(
        'Navigate with `context.nav`, never with the router itself.\n'
        '\n'
        '- `lib/core/nav/facade.dart` has `NavLink`, whose `go()` shows a '
        'location in a `Navigator`. The home is in `lib/features/home/`, '
        'with its `HomeScreen`.\n',
        files: [
          file(
            'lib/core/nav/facade.dart',
            template,
            'class NavLink { void go() {} }\n'
                'extension Nav on Object { int get nav => 0; }\n',
          ),
          file(
            'lib/features/home/home.dart',
            ofHome,
            'class HomeScreen {}\n',
          ),
          file(
            'lib/core/nav/router.dart',
            ofNav,
            'final router = Navigator();\n',
          ),
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
      'The note of the nav role under "Routes" names go_nav in its text, the '
      'id of a module that provides the nav role (in the app of home with '
      'nav).',
    );
  });

  group('the id of a module behind a role', () {
    const inCode = '`go_nav`, the id of $providesNav';

    test('is found in the text, in inline code and in a fenced block', () {
      expect(
        problemsOf('The routes are those of go_nav.'),
        ['go_nav in its text, the id of $providesNav'],
      );
      for (final text in [
        'Never import `package:go_nav/go_nav.dart`.',
        'Run:\n\n```bash\ndart run go_nav:routes\n```\n',
        'With ~~~ too:\n\n~~~\ngo_nav\n~~~~\nAnd the text goes on.',
        // The other mark does not close a block.
        'Still code:\n\n```\n~~~\ngo_nav\n```\n',
        'And:\n\n~~~\n```\ngo_nav\n~~~\n',
        // The spaces around the code of a span are not of it.
        'The span `  go_nav  `.',
      ]) {
        expect(problemsOf(text), [inCode], reason: text);
      }
    });

    test(
        'is found with a hyphen for its underscore, in camel case, and '
        'inside a longer name', () {
      String has(String token) =>
          '$token, which has the words of go_nav, the id of $providesNav';

      expect(
        problemsOf(
          'The tool `go-nav` writes a `GoNavState` for `goNav` and for '
          '`my_go_nav_routes`. GoNav builds the pages.',
        ),
        [
          has('`go-nav`'),
          has('`GoNavState`'),
          has('`goNav`'),
          has('`my_go_nav_routes`'),
          has('GoNav in its text'),
        ],
      );
    });

    test('is its words next to each other, in their order', () {
      for (final text in [
        'The routes of go_navigator.',
        'A `mango_nav`, a `nav_go` and a `GoToNav`.',
        'Go, nav.',
      ]) {
        expect(problemsOf(text), isEmpty, reason: text);
      }
    });

    test(
        'whose words are words of the ids and of the descriptions of the '
        'roles counts only as it is, in code, since the text cannot tell '
        'it from a role', () {
      // The module `frame` has a word of the description of its role, and
      // the module `shell` the id of the role of that module.
      final frame = TestModule(
        'frame',
        providers: const [RoleProvider.plain(shell)],
      );
      final shellModule = TestModule(
        'shell',
        providers: [RoleProvider.plain(logs)],
      );
      List<String> problems(String text) => problemsOf(
            text,
            modules: [goNav, frame, shellModule],
          );

      expect(
        problems(
          'The frame of the app is its shell: a `ShellFrame`, a '
          '`MainFrame` or a `shell_frame`. Frame and Shell are no modules.',
        ),
        isEmpty,
      );
      expect(problems('Open it with `context.frame.shell()`.'), [
        '`frame`, the id of $providesShell',
        '`shell`, the id of $providesLogs',
      ]);
    });

    test(
        'is the id of a provider of any role, and of a module that a '
        'provider depends on, with what the module is', () {
      final aLog = TestModule('a_log', providers: [RoleProvider.plain(logs)]);

      expect(
        problemsOf(
          'The log of `a_log`, with nav_base. But `home` is behind no role.',
          modules: [goNav, navBase, home, aLog],
        ),
        [
          '`a_log`, the id of $providesLogs',
          'nav_base in its text, the id of $dependedOn',
        ],
      );
    });

    test('is none when a role requires a name like it', () {
      // A getter of a class, a named parameter and a getter of an extension
      // of the shell role.
      final count = TestModule(
        'count',
        providers: const [RoleProvider.plain(shell)],
      );
      final items = TestModule('items', providers: [RoleProvider.plain(logs)]);
      final area = TestModule('area', providers: [RoleProvider.plain(logs)]);

      expect(
        problemsOf(
          'The bar shows the `count` of the `items` of its `area`.',
          modules: [goNav, count, items, area],
        ),
        isEmpty,
      );
    });
  });

  group('a package that a module behind a role adds', () {
    test(
        'is found in the text and in code, in camel case too, also a dev '
        'dependency, in the order of the names', () {
      expect(
        problemsOf(
          'The routes are those of nav_kit, which `nav_lints` checks, as a '
          '`NavKitRouter`. See `base_kit`.',
          dependencies: {
            'nav_kit': hosted('nav_kit', ofNav),
            'base_kit': hosted('base_kit', ofBase),
          },
          devDependencies: {'nav_lints': hosted('nav_lints', ofNav)},
        ),
        [
          '`nav_lints`, a package of go_nav, $providesNav',
          withWords(
            '`NavKitRouter`',
            'nav_kit',
            'a package of go_nav, $providesNav',
          ),
          '`base_kit`, a package of nav_base, $dependedOn',
          'nav_kit in its text, a package of go_nav, $providesNav',
        ],
      );
    });

    test(
        'is not one of an SDK, of a module behind no role or of a '
        'template', () {
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

    test('with the name of the module is reported as its id', () {
      expect(
        problemsOf(
          'With `go_nav`.',
          dependencies: {'go_nav': hosted('go_nav', ofNav)},
        ),
        ['`go_nav`, the id of $providesNav'],
      );
    });

    test('is reported once for a name, as the first module that has it', () {
      final aLog = TestModule('a_log', providers: [RoleProvider.plain(logs)]);

      expect(
        problemsOf(
          'A `LogKit` and a `LogKit`.',
          modules: [goNav, aLog],
          dependencies: {
            'log_kit': const MergedDependency(
              'log_kit',
              source: PubspecSource.hosted,
              origins: [ofNav, ModuleOrigin(ModuleId('a_log'))],
            ),
          },
        ),
        [withWords('`LogKit`', 'log_kit', 'a package of a_log, $providesLogs')],
      );
    });
  });

  group('a name that only the files of the modules behind the roles declare',
      () {
    final files = [
      file(
        'lib/core/nav/router.dart',
        ofNav,
        "import 'dart:async' as screen0;\n"
            'Object createRouter() => _Engine();\n'
            'class _Engine { int spin = 0; void build() {} }\n'
            'class Facade {}\n'
            'void open() {}\n'
            'void show() {}\n',
      ),
      file('lib/core/nav/base.dart', ofBase, 'const baseRoutes = 1;\n'),
      file('lib/core/nav/facade.dart', template, 'class Facade {}\n'),
      file(
        'lib/features/home/home.dart',
        ofHome,
        'class Home { void open() {} }\nvoid show() {}\n',
      ),
    ];
    String declares(String name) =>
        declaredIn(name, 'lib/core/nav/router.dart', 'go_nav', providesNav);

    test('is found at the top level and as the prefix of an import', () {
      expect(
        problemsOf(
          '`createRouter()` returns the `_Engine`, with a screen imported '
          'as `screen0`, over `baseRoutes`.',
          files: files,
        ),
        [
          declares('createRouter'),
          declares('_Engine'),
          declares('screen0'),
          declaredIn(
            'baseRoutes',
            'lib/core/nav/base.dart',
            'nav_base',
            dependedOn,
          ),
        ],
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
      expect(
        problemsOf('Or:\n\n~~~\n  createRouter();\n~~~\n', files: files),
        [declares('createRouter')],
      );
    });

    test(
        'is no member of a type, and none that the file of a template or '
        'of another module declares too, in any way', () {
      expect(
        problemsOf(
          'The engine can `spin` and `build()`. The `Facade` can `open()` '
          'and `show()`.',
          files: files,
        ),
        isEmpty,
      );
    });

    test('is named with the first of the modules that declare it', () {
      final aLog = TestModule('a_log', providers: [RoleProvider.plain(logs)]);
      final bLog = TestModule('b_log', providers: [RoleProvider.plain(logs)]);

      expect(
        problemsOf(
          'Call `createLog()`.',
          modules: [goNav, bLog, aLog],
          files: [
            for (final log in ['b', 'a'])
              file(
                'lib/logs/$log.dart',
                ModuleOrigin(ModuleId('${log}_log')),
                'void createLog() {}\n',
              ),
          ],
        ),
        [declaredIn('createLog', 'lib/logs/a.dart', 'a_log', providesLogs)],
      );
    });

    test('is not looked for in the text, in a path or in a placeholder', () {
      expect(
        problemsOf(
          'To createRouter is no code here. `lib/spin/createRouter.dart` is '
          'a path, and `<screen0>.<_engine route>` a pattern.',
          files: files,
        ),
        isEmpty,
      );
    });

    test(
        'is looked for in code with a slash that is no path, and between '
        'angle brackets that hold a type', () {
      expect(
        problemsOf(
          "Call `createRouter('/home')`, `go(createRouter(), to: /home)` or "
          '`List<_Engine>`. And:\n\n'
          '```\n'
          'lib/core/createRouter.dart\n'
          '  lib/core/baseRoutes.dart\n'
          'open lib/core/screen0.dart\n'
          '```\n',
          files: files,
        ),
        [declares('createRouter'), declares('_Engine'), declares('screen0')],
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

  group(
      'a name in upper camel case that only code with one thing from '
      'outside the app has', () {
    final dependencies = {
      'flutter': const MergedDependency(
        'flutter',
        source: PubspecSource.sdk,
        origins: [ofNav],
        sdk: 'flutter',
      ),
      'nav_kit': hosted('nav_kit', ofNav),
      'home_kit': hosted('home_kit', ofHome),
      'role_kit': hosted('role_kit', template),
    };
    final router = file(
      'lib/core/nav/router.dart',
      ofNav,
      "import 'dart:async';\n"
          "import 'package:flutter/widgets.dart';\n"
          "import 'package:nav_kit/nav_kit.dart';\n"
          "import 'package:my_app/core/nav/facade.dart';\n"
          "import 'facade.dart';\n"
          '\n'
          '// The NavGuide tells more.\n'
          'Object createRouter(Object kit) {\n'
          "  const title = 'NavTitle';\n"
          '  final NavState? last = null;\n'
          '  final local = NavKit(depth: 2);\n'
          '  openKit(local);\n'
          "  if (last == null) throw StateError('none');\n"
          '  final FutureOr<Widget>? shown = null;\n'
          '  return [local.stack, kit, title, shown, Shared(), Facade()];\n'
          '}\n',
    );
    final facade = file(
      'lib/core/nav/facade.dart',
      template,
      "import 'package:flutter/widgets.dart';\n"
          'class Facade {}\n'
          'Widget? shown;\n',
    );
    String ofKit(String name) =>
        '`$name`, which only code that imports package:nav_kit uses, a '
        'package of go_nav, $providesNav';

    test('is taken for a name of that package', () {
      expect(
        problemsOf(
          'The router is a `NavKit` that keeps a `NavState`, as in '
          '`NavKit(depth: 2)`.',
          files: [router, facade],
          dependencies: dependencies,
        ),
        [ofKit('NavKit'), ofKit('NavState')],
      );
    });

    test(
        'is no name in lower case, none of a comment or of a string, none '
        'of Dart, none that a file of an app declares, and none that a '
        'file without the package has too', () {
      expect(
        problemsOf(
          'It has a `depth` and a `stack`, which `openKit()` opens. The '
          '`NavGuide` and the `NavTitle` are no code. A `StateError`, a '
          '`FutureOr`, the `Facade` and a `Widget` are not of the package.',
          files: [router, facade],
          dependencies: dependencies,
        ),
        isEmpty,
      );
    });

    test('is named with the first of the things from outside', () {
      expect(
        problemsOf(
          'A `Wide` thing.',
          files: [
            file(
              'lib/core/nav/wide.dart',
              ofNav,
              "import 'package:nav_kit/nav_kit.dart';\n"
                  "import 'package:nav_alpha/nav_alpha.dart';\n"
                  "import 'package:nav_beta/nav_beta.dart';\n"
                  'final wide = Wide();\n',
            ),
          ],
          dependencies: {
            for (final package in ['nav_kit', 'nav_alpha', 'nav_beta'])
              package: hosted(package, ofNav),
          },
        ).single,
        '`Wide`, which only code that imports package:nav_alpha uses, a '
        'package of go_nav, $providesNav',
      );
    });

    test('is free when two files have it with different packages', () {
      expect(
        problemsOf(
          'A `Shared` thing.',
          files: [
            router,
            facade,
            file(
              'lib/features/home/home.dart',
              ofHome,
              "import 'package:home_kit/home_kit.dart';\n"
                  'final home = [Shared(), HomeKit()];\n',
            ),
          ],
          dependencies: dependencies,
        ),
        isEmpty,
      );
    });

    test(
        'is free with a package of a module behind no role, of a '
        'template, or of the app itself', () {
      expect(
        problemsOf(
          'A `HomeKit`, a `RoleKit` and a `Mine`.',
          files: [
            file(
              'lib/features/home/home.dart',
              ofHome,
              "import 'package:home_kit/home_kit.dart';\n"
                  'final home = HomeKit();\n',
            ),
            file(
              'lib/core/nav/facade.dart',
              template,
              "import 'package:role_kit/role_kit.dart';\n"
                  'final kit = RoleKit();\n',
            ),
            file(
              'lib/core/nav/router.dart',
              ofNav,
              "import 'package:my_app/core/nav/facade.dart';\n"
                  'final mine = Mine();\n',
            ),
          ],
          dependencies: dependencies,
        ),
        isEmpty,
      );
    });

    test(
        'is taken for a name of a file that no module generates, which the '
        'owner of the file with the import imports', () {
      String ofFile(String name, String path, String module, String what) =>
          '`$name`, which only code that imports $path uses, a file that no '
          'module generates and $module imports, $what';

      expect(
        problemsOf(
          'The `GeneratedRoutes`, the `BaseRoutes` and the `HomeRoutes`.',
          files: [
            file(
              'lib/core/nav/router.dart',
              ofNav,
              "import 'generated/routes.g.dart';\n"
                  'final routes = GeneratedRoutes();\n',
            ),
            file(
              'lib/core/nav/base.dart',
              ofBase,
              "import 'package:my_app/base/routes.g.dart';\n"
                  'final routes = BaseRoutes();\n',
            ),
            file(
              'lib/features/home/home.dart',
              ofHome,
              "import '../../home.g.dart';\n"
                  'final routes = HomeRoutes();\n',
            ),
          ],
        ),
        [
          ofFile(
            'GeneratedRoutes',
            'lib/core/nav/generated/routes.g.dart',
            'go_nav',
            providesNav,
          ),
          ofFile(
            'BaseRoutes',
            'lib/base/routes.g.dart',
            'nav_base',
            'a module that go_nav depends on',
          ),
        ],
      );
    });

    test(
        'is taken for a name of the module whose fragment the import was '
        'added for, in the file of another owner', () {
      const added = [
        AddedImport(ImportRef('package:my_app/texts.g.dart'), ofNav),
        AddedImport(ImportRef('package:my_app/other.g.dart'), ofHome),
      ];

      expect(
        problemsOf(
          'The `NavTexts` of the root, and its `OtherTexts`.',
          files: [
            file(
              'lib/app.dart',
              template,
              "import 'package:my_app/texts.g.dart';\n"
                  'final texts = NavTexts();\n',
              addedImports: added,
            ),
            file(
              'lib/other.dart',
              ofBase,
              "import 'package:my_app/other.g.dart';\n"
                  'final texts = OtherTexts();\n',
              addedImports: added,
            ),
          ],
        ).single,
        '`NavTexts`, which only code that imports lib/texts.g.dart uses, a '
        'file that no module generates and go_nav imports, $providesNav',
      );
    });
  });

  group('what a role guarantees', () {
    final provider = TestModule(
      'tabs',
      providers: const [RoleProvider.plain(shell)],
    );
    const ofTabs = ModuleOrigin(ModuleId('tabs'));
    final files = [
      file(
        _ShellRole.shellFile,
        ofTabs,
        "import 'package:tab_kit/tab_kit.dart';\n"
        'Future<ShellKit> createShell() async => ShellKit(ShellBar());\n'
        'void closeShell() {}\n'
        'void open() {}\n'
        'const shell_key = 1;\n'
        'const shellMarks = 2;\n'
        'const once = 3;\n'
        'class Shell {\n'
        '  Shell({this.items = const []});\n'
        '  final List<Object> items;\n'
        '  int get count => items.length;\n'
        '}\n'
        'extension ShellOf on ShellHost { Shell get area => Shell(); }\n'
        'final extra = TabKit();\n',
      ),
      file('lib/core/shell/tabs.dart', ofTabs, 'const tabs = 1;\n'),
    ];
    List<String> problems(String text) => problemsOf(
          text,
          modules: [goNav, provider],
          files: files,
          dependencies: {'tab_kit': hosted('tab_kit', ofTabs)},
        );

    test(
        'is free to the note of any role: a symbol of its interface with '
        'its parameters, its getters and the types that it is declared '
        'with, the file of the symbol, and a name that the description of '
        'one of its rules gives as code', () {
      expect(
        problems(
          '`createShell()` returns a `ShellKit` with the `Shell` and its '
          '`items`, whose `count` the bar shows, and `closeShell()` ends '
          'it. `ShellOf` gives a `ShellHost` its `context.area`. The '
          'provider calls `open()` with a `ShellBar` and its '
          '`shell_key`, and keeps `shellMarks`. The file is '
          '`${_ShellRole.shellFile}`, in `lib/core/shell/`.',
        ),
        isEmpty,
      );
    });

    test(
        'is not what a provider has beyond that, nor a plain word of the '
        'description of a rule', () {
      const ofPackage =
          '`TabKit`, which only code that imports package:tab_kit uses, a '
          'package of tabs, $providesShell';

      expect(problems('`once`, an `extra` `TabKit` in `tabs.dart`.'), [
        declaredIn('once', _ShellRole.shellFile, 'tabs', providesShell),
        declaredIn('extra', _ShellRole.shellFile, 'tabs', providesShell),
        ofPackage,
        declaredIn('tabs', 'lib/core/shell/tabs.dart', 'tabs', providesShell),
      ]);
    });
  });

  group('a file or a directory that only modules behind the roles generate',
      () {
    final files = [
      file('lib/core/nav/router.dart', ofNav, ''),
      file('lib/core/nav/engine/gears.dart', ofNav, ''),
      file('lib/core/navigation/facade.dart', template, ''),
      file('lib/core/go_nav/facade.dart', template, ''),
      file('lib/features/home/home.dart', ofHome, ''),
      file('nav.yaml', ofNav, ''),
      file('pubspec.yaml', ofNav, ''),
      file('tool/nav.dart', ofBase, ''),
      file('test/nav_test.dart', ofNav, ''),
    ];
    // An app with only what the provider generates in every app.
    final other = app(
      'another',
      modules: [goNav],
      files: [
        file('pubspec.yaml', ofNav, ''),
        file('test/app_test.dart', ofNav, ''),
      ],
    );
    String generates(String span, [String module = 'go_nav']) =>
        '`$span`, which only $module generates and no role guarantees';

    test('is found in inline code, with or without a slash at its end', () {
      expect(
        problemsOf(
          'The routes are in `lib/core/nav/router.dart`, in `lib/core/nav/`, '
          'in ` lib/core/nav `, below `lib/core/nav/engine`. See `tool/`.',
          files: files,
          others: [other],
        ),
        [
          generates('lib/core/nav/router.dart'),
          generates('lib/core/nav/'),
          generates('lib/core/nav'),
          generates('lib/core/nav/engine'),
          generates('tool/', 'nav_base'),
        ],
      );
    });

    test(
        'is none that another owner has a file in, and is read as a path '
        'only, so the id in the path of a file of a template is none', () {
      expect(
        problemsOf(
          '`lib/core/` and `lib/` have the files of the app, as '
          '`lib/core/navigation/facade.dart` and '
          '`lib/core/go_nav/facade.dart`. `lib/features/home/home.dart` is '
          'a file of the home.',
          files: files,
          others: [other],
        ),
        isEmpty,
      );
    });

    test(
        'is free at the root of the app when every app has it, and not '
        'when only the apps with the module have it', () {
      expect(
        problemsOf(
          'The packages are in `pubspec.yaml`, the tests in `test/` and in '
          '`test`. The routes are in `nav.yaml`. But `test/nav_test.dart` '
          'is not at the root.',
          files: files,
          others: [other],
        ),
        [generates('nav.yaml'), generates('test/nav_test.dart')],
      );
    });

    test(
        'is no path that no app has, which is read for the ids as other '
        'code is', () {
      expect(
        problemsOf(
          '`lib/core/router/` is no directory of an app, nor is '
          '`lib/go_nav/<route>.dart` or `nav.yml`.',
          files: files,
          others: [other],
        ),
        ['`go_nav`, the id of $providesNav'],
      );
    });

    test('is named with every module that generates it', () {
      final aLog = TestModule('a_log', providers: [RoleProvider.plain(logs)]);
      final bLog = TestModule('b_log', providers: [RoleProvider.plain(logs)]);

      expect(
        problemsOf(
          'See `lib/logs/`.',
          modules: [goNav, aLog, bLog],
          files: [
            for (final log in ['a', 'b'])
              file(
                'lib/logs/$log.dart',
                ModuleOrigin(ModuleId('${log}_log')),
                '',
              ),
          ],
        ).single,
        '`lib/logs/`, which only a_log and b_log generate and no role '
        'guarantees',
      );
    });
  });

  group('what the caller allows', () {
    final files = [
      file('lib/core/nav/router.dart', ofNav, 'void createRouter() {}\n'),
    ];
    const text = 'Call `createRouter()` of GoNav in '
        '`lib/core/nav/router.dart`.';

    test('is no problem, as the note gives it: a name, a word or a path', () {
      expect(problemsOf(text, files: files), hasLength(3));
      expect(
        problemsOf(
          text,
          files: files,
          allowed: {
            'createRouter': 'The role is about to require it.',
            'GoNav': 'The name of the pattern, not of the module.',
            'lib/core/nav/router.dart': 'Every provider is to have it.',
          },
        ),
        isEmpty,
      );
    });

    test('is reported when it excuses nothing, with its reason', () {
      expect(
        problemsOf(
          text,
          files: files,
          allowed: {
            'createRouter': 'The role is about to require it.',
            'GoNav': 'The name of the pattern, not of the module.',
            'lib/core/nav/router.dart': 'Every provider is to have it.',
            'NavLink': 'A class of the role.',
          },
        ).single,
        '`allowed` has `NavLink` ("A class of the role."), which no note of '
        'a role names in a way that the check refuses. Remove the entry.',
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
        // The same file again, in an app with a role that has nothing to
        // tell of its provider.
        app(
          'third',
          modules: [
            goNav,
            TestModule('idle_log', providers: [RoleProvider.plain(logs)]),
          ],
          files: [
            file('lib/core/nav/router.dart', ofNav, 'void createRouter() {}\n'),
          ],
          entries: [(RoleTemplateOrigin(logs), 'Logs', 'Nothing to tell.')],
        ),
      ],
      notes,
      textOf: (text) => text,
    );

    expect(
      problems.single,
      'The note of the nav role under "Nav" names `createRouter`, which only '
      'lib/core/nav/router.dart of go_nav declares, a module that provides '
      'the nav role (in the app of first).',
    );
  });
}
