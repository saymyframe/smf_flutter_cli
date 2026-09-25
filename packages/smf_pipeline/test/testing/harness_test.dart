import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import '../support.dart';

void main() {
  final state = TestRole<NoDsl>('state');
  final tracking = TestRole<NoDsl>(
    'tracking',
    cardinality: RoleCardinality.many,
  );
  final nav = TestRole<NoDsl>('nav');
  List<Contribution> none(ModuleContext context) => const [];

  final registry = ModuleRegistry([
    scaffold(),
    TestModule(
      'home',
      uses: {tracking, nav},
      variants: Variants(
        role: state,
        byProvider: {
          const ModuleId('bloc'): none,
          const ModuleId('riverpod'): none,
        },
      ),
      contributions: [
        CodegenRequest(when: {tracking}),
      ],
    ),
    TestModule('bloc', providers: [RoleProvider.plain(state)]),
    TestModule('riverpod', providers: [RoleProvider.plain(state)]),
    TestModule('signals', providers: [RoleProvider.plain(state)]),
    TestModule('a1', providers: [RoleProvider.plain(tracking)]),
    TestModule('a2', providers: [RoleProvider.plain(tracking)]),
    TestModule(
      'broken',
      contributions: [
        BrickContribution(bundle('b', files: {'lib/b.dart': '{{{smf_x}}}'})),
      ],
    ),
    TestModule('go', providers: [RoleProvider.plain(nav)]),
    TestModule('auto', providers: [RoleProvider.plain(nav)]),
    TestModule('both', dependsOn: {'go', 'auto'}),
  ]);
  final harness = ContractHarness(registry);

  test('builds a case per variant and subset of used roles', () {
    final cases = harness.casesOfModule(const ModuleId('home'));

    expect(cases.map((c) => '$c'), [
      'home (bloc) with tracking, nav',
      'home (bloc) with tracking',
      'home (bloc) with nav',
      'home (bloc)',
      'home (riverpod) with tracking, nav',
      'home (riverpod) with tracking',
      'home (riverpod) with nav',
      'home (riverpod)',
      'home (signals) with tracking, nav',
      'home (signals) with tracking',
      'home (signals) with nav',
      'home (signals)',
    ]);
    expect(
      cases[0].requested.map((id) => id.value),
      ['home', 'a1', 'go'],
    );
    expect(cases[4].picks[state], const ModuleId('riverpod'));
    expect(cases[4].picks[tracking], const ModuleId('a1'));
    expect(
      () => harness.casesOfModule(const ModuleId('nope')),
      throwsArgumentError,
    );
  });

  test('builds a case per provider of a role', () {
    expect(harness.casesOfRole(nav).map((c) => '$c'), [
      'nav by go',
      'nav by auto',
    ]);
    expect(harness.casesOfRole(appEntryRole).map((c) => '$c'), [
      'app_entry by scaffold',
    ]);
  });

  test('the cases of every module take each provider of a role that takes one',
      () {
    final cases = harness.casesOfAll();

    expect(cases.map((c) => '$c'), [
      'every module (go, bloc)',
      'every module (go, riverpod)',
      'every module (go, signals)',
      'every module (auto, bloc)',
      'every module (auto, riverpod)',
      'every module (auto, signals)',
    ]);
    ContractCase named(String name) =>
        cases.singleWhere((c) => c.name == 'every module ($name)');
    // Without the other providers, and without both, which depends on two
    // providers of the same role.
    final riverpod = named('auto, riverpod');
    expect(
      riverpod.requested.map((id) => id.value),
      ['scaffold', 'home', 'riverpod', 'a1', 'a2', 'broken', 'auto'],
    );
    expect(riverpod.picks[state], const ModuleId('riverpod'));
    expect(riverpod.picks[nav], const ModuleId('auto'));
    expect(riverpod.picks[tracking], const ModuleId('a1'));
    // Home has no variant for signals.
    expect(
      named('go, signals').requested.map((id) => id.value),
      ['scaffold', 'signals', 'a1', 'a2', 'broken', 'go'],
    );
  });

  test('a combination whose provider cannot be in its app has no case', () {
    final x = TestRole<NoDsl>('x');
    final y = TestRole<NoDsl>('y');
    final cases = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule('p1', providers: [RoleProvider.plain(x)]),
        TestModule(
          'p2',
          dependsOn: {'q2'},
          providers: [RoleProvider.plain(x)],
        ),
        TestModule('q1', providers: [RoleProvider.plain(y)]),
        TestModule('q2', providers: [RoleProvider.plain(y)]),
      ]),
    ).casesOfAll();

    expect(cases.map((c) => '$c'), [
      'every module (p1, q1)',
      'every module (p1, q2)',
      'every module (p2, q2)',
    ]);
    expect(
      ContractHarness(ModuleRegistry([scaffold()]))
          .casesOfAll()
          .map((c) => '$c'),
      ['every module'],
    );
  });

  test('a module that follows the rules passes every case', () async {
    for (final contractCase in [
      for (final contractCase in harness.casesOfModule(const ModuleId('home')))
        if (!contractCase.name.contains('signals')) contractCase,
    ]) {
      final result = await harness.check(contractCase);
      expect(result.errors, isEmpty, reason: '$contractCase');
      expect(result.resolution, isNotNull);
    }
  });

  test('reports the problems of a module', () async {
    final result = await harness.check(
      harness.casesOfModule(const ModuleId('broken')).single,
    );

    expect(result.errors.single.message, contains('names no socket'));
  });

  test('reports usage errors and failed resolutions as issues', () async {
    final usage = await harness.check(
      harness.casesOfModule(const ModuleId('both')).single,
    );
    expect(usage.errors.single.message, contains('one provider of the nav'));
    expect(usage.resolution, isNull);

    final unresolved = await harness.check(
      const ContractCase('missing', requested: [ModuleId('home')]),
    );
    expect(unresolved.errors, isNotEmpty);
  });

  test(
    'a provider of the role of the variants without a variant fails',
    () async {
      final result = await harness.check(
        harness.casesOfModule(const ModuleId('home')).firstWhere(
              (c) => c.name == 'home (signals)',
            ),
      );

      expect(result.errors.single.message, contains('no variant for signals'));
    },
  );

  test('checks every module and role, each app once', () async {
    final results = await harness.checkAll();

    expect(
      {
        for (final result in results)
          if (result.errors.isNotEmpty) '${result.contractCase}',
      },
      {
        'broken',
        'both',
        'home (signals)',
        'home (signals) with tracking',
        'home (signals) with nav',
        'home (signals) with tracking, nav',
      },
    );
    final keys = [
      for (final result in results)
        if (result.appKey case final key?) key,
    ];
    expect(keys.toSet(), hasLength(keys.length));
  });

  test('keeps the case that names every role its app has', () async {
    final clock = TestRole<NoDsl>('clock');
    final badge = TestRole<NoDsl>('badge');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule('user', uses: {clock, badge}),
        TestModule(
          'both',
          providers: [RoleProvider.plain(clock), RoleProvider.plain(badge)],
        ),
      ]),
    );

    final results = await harness.checkAll();

    expect(
      [
        for (final result in results)
          if (result.contractCase.name.startsWith('user'))
            '${result.contractCase}',
      ],
      ['user with clock, badge', 'user'],
    );
  });

  test('a role that uses another builds a case per subset', () {
    final tracking = TestRole<NoDsl>(
      'tracking',
      cardinality: RoleCardinality.many,
    );
    final nav = TestRole<NoDsl>('nav', uses: {tracking});
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule('go', providers: [RoleProvider.plain(nav)]),
        TestModule('a1', providers: [RoleProvider.plain(tracking)]),
      ]),
    );

    expect(
      harness.casesOfRole(nav).map((c) => '$c'),
      ['nav by go with tracking', 'nav by go'],
    );
  });

  test('a required role with several providers takes each', () {
    final session = TestRole<NoDsl>('session');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule('auth', requires: {session}),
        TestModule('keys', providers: [RoleProvider.plain(session)]),
        TestModule('vault', providers: [RoleProvider.plain(session)]),
      ]),
    );

    expect(
      harness.casesOfModule(const ModuleId('auth')).map((c) => '$c'),
      ['auth (keys)', 'auth (vault)'],
    );
    expect(
      harness.casesOfRole(session).map((c) => '$c'),
      ['session by keys', 'session by vault'],
    );
  });

  test('checks rendered code with the structural rules of the roles', () async {
    final result = await harness.check(
      const ContractCase('scaffold', requested: [ModuleId('scaffold')]),
    );
    expect(result.collection, isNotNull);
    expect(result.validation, isNotNull);

    final issues = harness.checkStructure(
      result,
      files: {
        'lib/main.dart': 'Future<void> main() async { runApp(App()); }',
        'lib/bootstrap.dart': 'Future<void> bootstrap() async {',
        'README.md': '# not Dart',
      },
      owners: const {'lib/main.dart': ModuleOrigin(ModuleId('scaffold'))},
    );
    expect(
      () => harness.checkStructure(
        const ContractResult(ContractCase('x', requested: []), []),
        files: const {},
        owners: const {},
      ),
      throwsArgumentError,
    );

    expect(
      [for (final issue in issues) issue.message],
      containsAll([
        startsWith('lib/bootstrap.dart does not parse'),
        'main() does not call WidgetsFlutterBinding.ensureInitialized().',
        'main() does not call bootstrap().',
        contains('lib/core/app/fallback_start_screen.dart is missing'),
      ]),
    );
  });

  group('rendering', () {
    test('renders the app of a case with its role options', () async {
      final pick = TestRole<String>(
        'pick',
        options: const [RoleOption(name: 'pick', help: 'What to pick.')],
        template: _PickTemplate(),
      );
      final harness = ContractHarness(
        ModuleRegistry([
          scaffold(),
          TestModule('picker', providers: [RoleProvider.plain(pick)]),
        ]),
      );

      final result = await harness.check(
        const ContractCase(
          'picker',
          requested: [ModuleId('picker')],
          roleOptions: {'pick': 'blue'},
        ),
      );

      expect(result.errors, isEmpty);
      expect(result.choices, {pick: 'blue'});
      expect(result.app!.files['lib/pick.dart']!.text, '// blue\n');
      expect(result.app!.files['lib/main.dart'], isNotNull);

      final unchosen = await harness.check(
        const ContractCase('picker', requested: [ModuleId('picker')]),
      );
      expect(unchosen.errors.single.message, 'Give --pick.');
      expect(unchosen.app, isNull);
      expect(unchosen.collection, isNotNull);

      // The options of the harness apply to every case, unless the case
      // sets its own.
      final defaults = ContractHarness(
        harness.registry,
        roleOptions: const {'pick': 'red'},
      );
      final byDefault = await defaults.check(
        const ContractCase('picker', requested: [ModuleId('picker')]),
      );
      expect(byDefault.choices, {pick: 'red'});
      final overridden = await defaults.check(
        const ContractCase(
          'picker',
          requested: [ModuleId('picker')],
          roleOptions: {'pick': 'blue'},
        ),
      );
      expect(overridden.choices, {pick: 'blue'});
    });

    test('a harness that does not render leaves the app out', () async {
      final harness = ContractHarness(registry, render: false);
      final result = await harness.check(
        const ContractCase('scaffold', requested: [ModuleId('scaffold')]),
      );

      expect(result.errors, isEmpty);
      expect(result.app, isNull);
      expect(result.choices, isNull);
    });

    test('problems of rendering become issues', () async {
      final harness = ContractHarness(
        ModuleRegistry([
          scaffold(),
          TestModule(
            'broken',
            contributions: [
              BrickContribution(bundle('b', files: {'lib/b.dart': '{{x}}'})),
            ],
          ),
        ]),
      );

      final result = await harness.check(
        const ContractCase('broken', requested: [ModuleId('broken')]),
      );

      expect(result.app, isNull);
      expect(
        result.errors.single.message,
        startsWith('The template lib/b.dart in the brick b of broken reads '
            'x, which neither the brick nor a render hook of broken sets'),
      );
    });

    group('checkRendered', () {
      final nav = TestRole<NoDsl>('nav');
      BrickContribution dart(String path, String text) =>
          BrickContribution(bundle(path, files: {path: text}));
      final modules = <SmfModule>[
        scaffold(),
        TestModule(
          'lib_a',
          contributions: [dart('lib/a/a.dart', 'class A {}\n')],
        ),
        TestModule(
          'go',
          providers: [RoleProvider.plain(nav)],
          contributions: [dart('lib/nav/nav.dart', 'class Nav {}\n')],
        ),
        TestModule(
          'user',
          uses: {nav},
          contributions: [
            dart(
              'lib/user/user.dart',
              "import 'package:contract_app/a/a.dart';\n"
                  "import 'package:contract_app/nowhere.dart';\n"
                  "import 'package:zeta/zeta.dart';\n"
                  "import '../nav/nav.dart';\n"
                  "import '../main.dart';\n"
                  '\n'
                  'final a = A();\n',
            ),
            const SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment('A();', imports: [ImportRef.app('a/a.dart')]),
            ),
          ],
        ),
        TestModule(
          'dependent',
          dependsOn: {'lib_a'},
          contributions: [
            dart(
              'lib/dependent/dependent.dart',
              "import '../a/a.dart';\n\nfinal a = A();\n",
            ),
          ],
        ),
      ];

      test('reports imports outside the reach of their user', () async {
        final harness = ContractHarness(ModuleRegistry(modules));
        final result = await harness.check(
          const ContractCase(
            'user',
            requested: [
              ModuleId('user'),
              ModuleId('lib_a'),
              ModuleId('go'),
              ModuleId('dependent'),
            ],
          ),
        );

        expect(
          [for (final issue in result.errors) issue.message],
          [
            equals(
              'lib/bootstrap.dart imports lib/a/a.dart for a fragment of user, '
              'but that file is of lib_a, which user neither depends on nor '
              'knows through a role.',
            ),
            equals(
              'lib/user/user.dart imports lib/a/a.dart in the template of '
              'user, but that file is of lib_a, which user neither depends '
              'on nor knows through a role.',
            ),
            equals(
              'lib/user/user.dart imports package:contract_app/nowhere.dart, '
              'but the app has no lib/nowhere.dart.',
            ),
            equals(
              'lib/user/user.dart imports package:zeta/zeta.dart, but the app '
              'does not depend on zeta.',
            ),
            equals(
              'lib/user/user.dart imports lib/nav/nav.dart in the template of '
              'user, but that file is of go, which user neither depends on '
              'nor knows through a role.',
            ),
          ],
        );
      });

      test('structural rules read every rendered file', () async {
        final notes = TestRole<NoDsl>(
          'notes',
          structuralRules: const [
            StructuralRule(
              id: 'notes.readme',
              description: 'The README names the app.',
              check: _checkReadme,
            ),
          ],
        );
        final harness = ContractHarness(
          ModuleRegistry([
            scaffold(),
            TestModule(
              'writer',
              providers: [RoleProvider.plain(notes)],
              contributions: [
                BrickContribution(
                  bundle('readme', files: {'README.md': '# Another app\n'}),
                ),
              ],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase('writer', requested: [ModuleId('writer')]),
        );

        expect(result.errors.map((issue) => issue.message), [
          'README.md does not name contract_app.',
        ]);
        expect(
          result.errors.single.origin,
          const ModuleOrigin(ModuleId('writer')),
        );
      });

      test('braces that mason copies are reported in the template', () async {
        final harness = ContractHarness(
          ModuleRegistry([
            scaffold(),
            TestModule(
              'texts',
              contributions: [
                dart('lib/copied.dart', "const braces = '{{a,b}}';\n"),
                dart(
                  'lib/escaped.dart',
                  "const braces = '$_brace${_brace}a';\n",
                ),
              ],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase('texts', requested: [ModuleId('texts')]),
        );

        expect(
          [for (final issue in result.errors) issue.message],
          [
            equals(
              'The template lib/copied.dart of texts has "{{" but no tag that '
              'mason renders, one without ",", ";" or "=", so mason copies '
              'it with the braces as they are.',
            ),
          ],
        );
      });

      test('roles and the data of roles open the files of others', () async {
        final shelf = TestRole<String>(
          'shelf',
          template: TestTemplate(
            contributions: [dart('lib/shelf/shelf.dart', 'class Shelf {}\n')],
          ),
        );
        final harness = ContractHarness(
          ModuleRegistry([
            scaffold(),
            TestModule(
              'store',
              providers: [RoleProvider.plain(shelf)],
              contributions: [
                dart(
                  'lib/store/store.dart',
                  "import '../book/book.dart';\n"
                      "import '../other/other.dart';\n"
                      "import '../shelf/shelf.dart';\n",
                ),
              ],
            ),
            TestModule(
              'book',
              requires: {shelf},
              contributions: [
                shelf.data('a book'),
                dart(
                  'lib/book/book.dart',
                  "import '../shelf/shelf.dart';\n\nclass Book {}\n",
                ),
              ],
            ),
            TestModule(
              'other',
              contributions: [dart('lib/other/other.dart', 'class Other {}\n')],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase(
            'store',
            requested: [ModuleId('store'), ModuleId('book'), ModuleId('other')],
          ),
        );

        expect(
          [for (final issue in result.errors) issue.message],
          [
            equals(
              'lib/store/store.dart imports lib/other/other.dart in the template '
              'of store, but that file is of other, which store neither '
              'depends on nor knows through a role.',
            ),
          ],
        );
      });

      test('exports and dev dependencies follow the same rules', () async {
        final harness = ContractHarness(
          ModuleRegistry([
            scaffold(),
            TestModule(
              'lib_a',
              contributions: [dart('lib/a/a.dart', 'class A {}\n')],
            ),
            TestModule(
              'user',
              contributions: [
                const PubspecContribution.hosted('mocks', '^1.0.0', dev: true),
                dart(
                  'lib/user/user.dart',
                  "export '../a/a.dart';\n"
                      "export '../none.dart';\n"
                      "import 'package:mocks/mocks.dart';\n",
                ),
                dart('test/user_test.dart', "import 'package:mocks/m.dart';\n"),
              ],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase(
            'user',
            requested: [ModuleId('user'), ModuleId('lib_a')],
          ),
        );

        expect(
          [for (final issue in result.errors) issue.message],
          [
            equals(
              'lib/user/user.dart imports package:mocks/mocks.dart, but mocks '
              'is only a dev dependency of the app.',
            ),
            equals(
              'lib/user/user.dart exports lib/a/a.dart in the template of '
              'user, but that file is of lib_a, which user neither depends '
              'on nor knows through a role.',
            ),
            equals(
              'lib/user/user.dart exports ../none.dart, but the app has no '
              'lib/none.dart.',
            ),
          ],
        );
      });

      test('the files that code generation or localizations generate count',
          () async {
        final harness = ContractHarness(
          ModuleRegistry([
            scaffold(),
            TestModule(
              'l10n',
              contributions: [
                const PubspecContribution.sdk('flutter_localizations'),
                const PubspecContribution.flutter(generate: true),
                const CodegenRequest(outputs: ['lib/generated/config.dart']),
                BrickContribution(
                  bundle(
                    'l10n',
                    files: {
                      'l10n.yaml': 'arb-dir: lib/translations\n'
                          'output-dir: ./lib/generated/\n'
                          'output-localization-file: strings.dart\n',
                      'lib/l10n_user.dart': "import 'generated/strings.dart';\n"
                          "import 'generated/config.dart';\n"
                          "import 'generated/other.dart';\n",
                    },
                  ),
                ),
              ],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase('l10n', requested: [ModuleId('l10n')]),
        );

        expect(
          [for (final issue in result.errors) issue.message],
          [
            equals(
              'lib/l10n_user.dart imports generated/other.dart, but the app '
              'has no lib/generated/other.dart.',
            ),
          ],
        );
      });
    });
  });
}

/// A template that picks what the option `--pick` says, and renders it
/// into a brick.
final class _PickTemplate extends RoleTemplate<String> {
  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundle('pick', files: {'lib/pick.dart': '// {{picked}}\n'}),
        ),
      ];

  @override
  Future<Object?> choose(RoleChoiceContext<String> context) async =>
      context.option('pick') ?? (throw const SmfUsageException('Give --pick.'));

  @override
  RoleOutput render(RoleHookInput<String> input) =>
      RoleOutput(vars: {'picked': input.choice});
}

/// A `{` in a mason template.
const _brace = '{{__LEFT_CURLY_BRACKET__}}';

List<SmfIssue> _checkReadme(StructuralRuleInput<NoDsl> input) => [
      if (input.texts['README.md'] case final text?
          when !text.contains(input.roleInput.context.appName))
        SmfIssue(
          'README.md does not name ${input.roleInput.context.appName}.',
          origin: input.owners['README.md'],
          path: 'README.md',
        ),
    ];
