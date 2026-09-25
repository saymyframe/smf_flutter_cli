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
    scaffold(contributions: [entryBrick()]),
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
        scaffold(contributions: [entryBrick()]),
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
        scaffold(contributions: [entryBrick()]),
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
        scaffold(contributions: [entryBrick()]),
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
}
