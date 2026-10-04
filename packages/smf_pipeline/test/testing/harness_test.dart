import 'package:smf_contracts/smf_contracts.dart';
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

  test(
      'builds a case per subset of used roles, variant and provider of each '
      'used role', () {
    final cases = harness.casesOfModule(const ModuleId('home'));
    const variants = ['bloc', 'riverpod', 'signals'];

    expect(cases.map((c) => '$c'), [
      for (final variant in variants)
        for (final tracker in ['a1', 'a2'])
          for (final router in ['go', 'auto'])
            'home ($variant, $tracker, $router) with tracking, nav',
      for (final variant in variants)
        for (final tracker in ['a1', 'a2'])
          'home ($variant, $tracker) with tracking',
      for (final variant in variants)
        for (final router in ['go', 'auto'])
          'home ($variant, $router) with nav',
      for (final variant in variants) 'home ($variant)',
    ]);
    ContractCase named(String name) => cases.singleWhere((c) => c.name == name);
    expect(
      named('home (bloc, a1, go) with tracking, nav')
          .requested
          .map((id) => id.value),
      ['home', 'a1', 'go'],
    );
    final withSecond = named('home (riverpod, a2, auto) with tracking, nav');
    expect(withSecond.requested.map((id) => id.value), ['home', 'a2', 'auto']);
    expect(withSecond.picks[state], const ModuleId('riverpod'));
    expect(withSecond.picks[tracking], const ModuleId('a2'));
    expect(withSecond.picks[nav], const ModuleId('auto'));
    // A used role left out of the case is not asked for.
    expect(
      named('home (bloc, auto) with nav').requested.map((id) => id.value),
      ['home', 'auto'],
    );
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
    expect(
      usage.errors.single.message,
      contains('at most one provider of the nav role'),
    );
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

  test('reports a module that takes the package of a provider', () async {
    final state = TestRole<NoDsl>('state');
    const pinned = PubspecContribution.hosted('flutter_bloc', '^9.1.1');
    const taken = PubspecContribution.hosted('flutter_bloc', 'any');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule(
          'bloc',
          providers: [RoleProvider.plain(state)],
          contributions: const [pinned],
        ),
        TestModule('riverpod', providers: [RoleProvider.plain(state)]),
        TestModule(
          'feature',
          variants: Variants(
            role: state,
            byProvider: {
              const ModuleId('bloc'): (_) => const [taken],
              const ModuleId('riverpod'): (_) => const [],
            },
          ),
        ),
        TestModule('helper', dependsOn: {'bloc'}, contributions: [taken]),
        TestModule('rogue', contributions: [taken]),
      ]),
    );

    // The modules that take the package in their variant for bloc or by
    // depending on bloc pass in each of their apps, and rogue in its case
    // with bloc, the provider whose package it contributes, does not.
    const rogueTakes =
        'rogue: rogue contributes flutter_bloc, a package of bloc, which '
        'provides the state role, but rogue neither has a variant for it nor '
        'depends on it.';
    final results = await harness.checkAll();
    expect(
      [
        for (final result in results)
          for (final issue in result.errors)
            '${result.contractCase}: ${issue.origin}: ${issue.message}',
      ],
      ['rogue with bloc: $rogueTakes'],
    );
    expect(
      harness.casesOfModule(const ModuleId('rogue')).map((c) => '$c'),
      ['rogue', 'rogue with bloc'],
    );
    // So does the app with every module, which has bloc.
    final every = await harness.check(
      harness.casesOfAll().singleWhere(
            (c) => c.name == 'every module (bloc)',
          ),
    );
    expect(
      [for (final issue in every.errors) '${issue.origin}: ${issue.message}'],
      [rogueTakes],
    );
    expect(every.app, isNull);
    // Without bloc, flutter_bloc is the package of no provider.
    final withRiverpod = await harness.check(
      harness.casesOfAll().singleWhere(
            (c) => c.name == 'every module (riverpod)',
          ),
    );
    expect(withRiverpod.errors, isEmpty);
    expect(withRiverpod.app, isNotNull);
  });

  test('builds a case with each provider whose package a module contributes',
      () async {
    final state = TestRole<NoDsl>('state');
    final tracking = TestRole<NoDsl>(
      'tracking',
      cardinality: RoleCardinality.many,
    );
    final nav = TestRole<NoDsl>('nav');
    PubspecContribution pinned(String package) =>
        PubspecContribution.hosted(package, '^1.0.0');
    PubspecContribution taken(String package) =>
        PubspecContribution.hosted(package, 'any');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule(
          'bloc',
          providers: [RoleProvider.plain(state)],
          contributions: [pinned('flutter_bloc')],
        ),
        TestModule(
          'riverpod',
          providers: [RoleProvider.plain(state)],
          contributions: [pinned('flutter_riverpod')],
        ),
        // Two providers of other roles that bring the same package both
        // own it.
        TestModule(
          'a1',
          providers: [RoleProvider.plain(tracking)],
          contributions: [pinned('shared')],
        ),
        TestModule('auto', providers: [RoleProvider.plain(nav)]),
        TestModule(
          'go',
          providers: [RoleProvider.plain(nav)],
          contributions: [pinned('shared')],
        ),
        // A provider that leaves the constraint to others, one that repeats
        // the package of a module it depends on, and a module without a
        // role own no package.
        TestModule(
          'a2',
          providers: [RoleProvider.plain(tracking)],
          contributions: [taken('loose'), pinned('base_package')],
          dependsOn: {'base'},
        ),
        TestModule('base', contributions: [pinned('base_package')]),
        TestModule('plain', contributions: [pinned('plain_package')]),
        TestModule(
          'feature',
          variants: Variants(
            role: state,
            byProvider: {
              const ModuleId('bloc'): (_) => [taken('flutter_bloc')],
              const ModuleId('riverpod'): (_) => [taken('flutter_riverpod')],
            },
          ),
          contributions: [
            taken('shared'),
            taken('loose'),
            taken('base_package'),
            taken('plain_package'),
          ],
        ),
        // Only the variant for riverpod takes the package of a1 and go.
        TestModule(
          'picky',
          variants: Variants(
            role: state,
            byProvider: {
              const ModuleId('bloc'): (_) => const [],
              const ModuleId('riverpod'): (_) => [taken('shared')],
            },
          ),
        ),
      ]),
    );

    // A case with a provider of another role has a variant of feature too.
    expect(
      harness.casesOfModule(const ModuleId('feature')).map((c) => '$c'),
      [
        'feature (bloc)',
        'feature (riverpod)',
        'feature with bloc',
        'feature with riverpod',
        'feature (bloc) with a1',
        'feature (bloc) with go',
      ],
    );
    final withGo = harness
        .casesOfModule(const ModuleId('feature'))
        .singleWhere((c) => c.name == 'feature (bloc) with go');
    expect(withGo.requested.map((id) => id.value), ['feature', 'go']);
    expect(withGo.picks[nav], const ModuleId('go'));
    expect(withGo.picks[state], const ModuleId('bloc'));
    // A case with a provider of the role of the variants is the case of the
    // variant, whose package the variant takes.
    final withRiverpod = await harness.check(
      harness
          .casesOfModule(const ModuleId('feature'))
          .singleWhere((c) => c.name == 'feature with riverpod'),
    );
    expect(withRiverpod.errors, isEmpty);
    expect(
      withRiverpod.resolution!.module(const ModuleId('feature'))!.variant,
      const ModuleId('riverpod'),
    );
    // Feature takes the package of a1 and go without a variant for them or
    // a dependency on them.
    final withA1 = await harness.check(
      harness
          .casesOfModule(const ModuleId('feature'))
          .singleWhere((c) => c.name == 'feature (bloc) with a1'),
    );
    const takesShared =
        'feature: feature contributes shared, a package of a1, which '
        'provides the tracking role, but feature neither has a variant for '
        'it nor '
        'depends on it.';
    expect(
      [for (final issue in withA1.errors) '${issue.origin}: ${issue.message}'],
      [takesShared],
    );
    // The case of the variant that takes the package reports it.
    expect(
      harness.casesOfModule(const ModuleId('picky')).map((c) => '$c'),
      [
        'picky (bloc)',
        'picky (riverpod)',
        'picky (riverpod) with a1',
        'picky (riverpod) with go',
      ],
    );
    final pickyWithA1 = await harness.check(
      harness
          .casesOfModule(const ModuleId('picky'))
          .singleWhere((c) => c.name == 'picky (riverpod) with a1'),
    );
    expect(
      [
        for (final issue in pickyWithA1.errors)
          '${issue.origin}: ${issue.message}',
      ],
      [
        equals(
          'picky (riverpod): picky (riverpod) contributes shared, a package '
          'of a1, which provides the tracking role, but picky neither has a '
          'variant for it nor depends on it.',
        ),
      ],
    );
    // The case of feature with bloc builds the app of its case with the
    // variant for bloc, which checkAll checks instead.
    final checked = [
      for (final result in await harness.checkAll()) '${result.contractCase}',
    ];
    expect(checked, containsAll(['feature (bloc)', 'feature (riverpod)']));
    expect(checked, isNot(contains('feature with bloc')));
    expect(checked, isNot(contains('feature with riverpod')));
    // A module that neither contributes a package of another nor has one of
    // its own has no such case.
    expect(
      harness.casesOfModule(const ModuleId('plain')).map((c) => '$c'),
      ['plain'],
    );
    expect(
      harness.casesOfModule(const ModuleId('bloc')).map((c) => '$c'),
      ['bloc'],
    );
  });

  test('a module that contributes the package of a provider passes its case',
      () async {
    final state = TestRole<NoDsl>('state');
    const pinned = PubspecContribution.hosted('flutter_bloc', '^9.1.1');
    const taken = PubspecContribution.hosted('flutter_bloc', 'any');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule(
          'bloc',
          providers: [RoleProvider.plain(state)],
          contributions: const [pinned],
        ),
        TestModule('riverpod', providers: [RoleProvider.plain(state)]),
        TestModule(
          'feature',
          variants: Variants(
            role: state,
            byProvider: {
              const ModuleId('bloc'): (_) => const [taken],
              const ModuleId('riverpod'): (_) => const [],
            },
          ),
        ),
        TestModule('helper', dependsOn: {'bloc'}, contributions: [taken]),
      ]),
    );

    for (final id in ['feature', 'helper']) {
      final cases = harness.casesOfModule(ModuleId(id));
      expect(cases.map((c) => '$c'), contains('$id with bloc'));
      for (final contractCase in cases) {
        final result = await harness.check(contractCase);
        expect(result.errors, isEmpty, reason: '$contractCase');
      }
    }
  });

  test('builds no case with a provider that cannot be in an app with a module',
      () async {
    final state = TestRole<NoDsl>('state');
    const pinned = PubspecContribution.hosted('flutter_bloc', '^9.1.1');
    const taken = PubspecContribution.hosted('flutter_bloc', 'any');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        // Two providers of the state that bring the same package both own
        // it, but an app has one of them.
        TestModule(
          'bloc',
          providers: [RoleProvider.plain(state)],
          contributions: const [pinned],
        ),
        TestModule(
          'hydrated',
          providers: [RoleProvider.plain(state)],
          contributions: const [pinned],
        ),
        TestModule('helper', dependsOn: {'bloc'}, contributions: const [taken]),
        TestModule(
          'feature',
          variants: Variants(
            role: state,
            byProvider: {
              const ModuleId('bloc'): (_) => const [taken],
            },
          ),
        ),
      ]),
    );

    expect(
      {
        for (final id in ['bloc', 'hydrated', 'helper', 'feature'])
          id: [
            for (final contractCase in harness.casesOfModule(ModuleId(id)))
              '$contractCase',
          ],
      },
      {
        'bloc': ['bloc'],
        'hydrated': ['hydrated'],
        'helper': ['helper', 'helper with bloc'],
        // Its case without a variant for hydrated reports that already.
        'feature': [
          'feature (bloc)',
          'feature (hydrated)',
          'feature with bloc',
        ],
      },
    );
    for (final id in ['bloc', 'hydrated', 'helper']) {
      for (final contractCase in harness.casesOfModule(ModuleId(id))) {
        final result = await harness.check(contractCase);
        expect(result.errors, isEmpty, reason: '$contractCase');
      }
    }
  });

  test('a module whose contributions fail has no case with a provider',
      () async {
    final state = TestRole<NoDsl>('state');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule(
          'bloc',
          providers: [RoleProvider.plain(state)],
          contributions: const [
            PubspecContribution.hosted('flutter_bloc', '^9.1.1'),
          ],
        ),
        _FailingModule('broken'),
      ]),
    );

    expect(
      harness.casesOfModule(const ModuleId('broken')).map((c) => '$c'),
      ['broken'],
    );
    final result = await harness.check(
      harness.casesOfModule(const ModuleId('broken')).single,
    );
    expect(result.errors.single.message, contains('failed to contribute'));
  });

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
        for (final tracker in ['a1', 'a2']) ...[
          'home (signals, $tracker) with tracking',
          for (final router in ['go', 'auto'])
            'home (signals, $tracker, $router) with tracking, nav',
        ],
        for (final router in ['go', 'auto']) 'home (signals, $router) with nav',
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

  test(
      'a role that uses another builds a case per subset and provider of each '
      'role it uses', () {
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
        TestModule('a2', providers: [RoleProvider.plain(tracking)]),
      ]),
    );

    final cases = harness.casesOfRole(nav);
    expect(cases.map((c) => '$c'), [
      'nav by go (a1) with tracking',
      'nav by go (a2) with tracking',
      'nav by go',
    ]);
    expect(cases[1].requested.map((id) => id.value), ['go', 'a2']);
    expect(cases[1].picks[nav], const ModuleId('go'));
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

  /// The errors of [results], each with its case.
  List<String> errorsOf(List<ContractResult> results) => [
        for (final result in results)
          for (final issue in result.errors) '${result.contractCase}: $issue',
      ];

  test(
      'builds no case with another provider of a role that a module gets '
      'from a module it depends on', () async {
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule('go', providers: [RoleProvider.plain(nav)]),
        TestModule('auto', providers: [RoleProvider.plain(nav)]),
        // Add-ons of go: one uses the role that go provides, the other
        // requires it.
        TestModule('addon', dependsOn: {'go'}, uses: {nav}),
        TestModule('plugin', dependsOn: {'go'}, requires: {nav}),
      ]),
    );

    expect(
      harness.casesOfModule(const ModuleId('addon')).map((c) => '$c'),
      ['addon (go) with nav', 'addon'],
    );
    expect(
      harness.casesOfModule(const ModuleId('plugin')).map((c) => '$c'),
      ['plugin (go)'],
    );
    expect(errorsOf(await harness.checkAll()), isEmpty);
  });

  test(
      'builds no case of a role with another provider of a role that the '
      'provider of the role provides too', () async {
    final shell = TestRole<NoDsl>('shell', uses: {nav});
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule(
          'frame',
          providers: [RoleProvider.plain(shell), RoleProvider.plain(nav)],
        ),
        TestModule('auto', providers: [RoleProvider.plain(nav)]),
      ]),
    );

    expect(harness.casesOfRole(shell).map((c) => '$c'), [
      'shell by frame (frame) with nav',
      'shell by frame',
    ]);
    expect(errorsOf(await harness.checkAll()), isEmpty);
  });

  test('builds no case whose picked providers cannot be in one app', () async {
    final store = TestRole<NoDsl>('store');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule('feature', requires: {store}, uses: {nav}),
        TestModule('disk', providers: [RoleProvider.plain(store)]),
        // Cloud brings go, a provider of the nav role, through its
        // dependency, and hub provides both roles itself.
        TestModule(
          'cloud',
          dependsOn: {'go'},
          providers: [RoleProvider.plain(store)],
        ),
        TestModule(
          'hub',
          providers: [RoleProvider.plain(store), RoleProvider.plain(nav)],
        ),
        TestModule('go', providers: [RoleProvider.plain(nav)]),
        TestModule('auto', providers: [RoleProvider.plain(nav)]),
      ]),
    );

    expect(
      harness.casesOfModule(const ModuleId('feature')).map((c) => '$c'),
      [
        'feature (disk, go) with nav',
        'feature (disk, auto) with nav',
        'feature (cloud, go) with nav',
        'feature (hub, hub) with nav',
        'feature (disk)',
        'feature (cloud)',
        'feature (hub)',
      ],
    );
    expect(errorsOf(await harness.checkAll()), isEmpty);
    // The cases left out take no provider of a role of feature away from
    // its apps.
    expect(await harness.uncheckedProviders(), isEmpty);
  });

  /// The names of the cases of [results] with errors.
  Set<String> failingOf(List<ContractResult> results) => {
        for (final result in results)
          if (result.errors.isNotEmpty) '${result.contractCase}',
      };

  test(
      'keeps every combination of providers for a subset of used roles when '
      'none can be in one app with the module, so that the cases report why',
      () async {
    final store = TestRole<NoDsl>('store');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule('go', providers: [RoleProvider.plain(nav)]),
        TestModule('auto', providers: [RoleProvider.plain(nav)]),
        // Every provider of the store role brings auto, and each add-on of
        // go needs the store role: one requires it, the other uses it.
        TestModule(
          'disk',
          dependsOn: {'auto'},
          providers: [RoleProvider.plain(store)],
        ),
        TestModule(
          'cloud',
          dependsOn: {'auto'},
          providers: [RoleProvider.plain(store)],
        ),
        TestModule('addon', dependsOn: {'go'}, requires: {store}),
        TestModule('extra', dependsOn: {'go'}, uses: {store}),
      ]),
    );

    expect(
      harness.casesOfModule(const ModuleId('addon')).map((c) => '$c'),
      ['addon (disk)', 'addon (cloud)'],
    );
    // Without the store role, extra can be in an app.
    expect(
      harness.casesOfModule(const ModuleId('extra')).map((c) => '$c'),
      ['extra (disk) with store', 'extra (cloud) with store', 'extra'],
    );
    final results = await harness.checkAll();
    expect(failingOf(results), {
      'addon (disk)',
      'addon (cloud)',
      'extra (disk) with store',
      'extra (cloud) with store',
    });
    expect(
      errorsOf(results),
      everyElement(contains('at most one provider of the nav role')),
    );
  });

  test(
      'keeps every case of a provider of a role when no combination of the '
      'providers it requires can be in one app with it, so that the cases '
      'report why', () async {
    final store = TestRole<NoDsl>('store');
    final shell = TestRole<NoDsl>('shell');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule('go', providers: [RoleProvider.plain(nav)]),
        TestModule('auto', providers: [RoleProvider.plain(nav)]),
        TestModule(
          'disk',
          dependsOn: {'auto'},
          providers: [RoleProvider.plain(store)],
        ),
        TestModule(
          'cloud',
          dependsOn: {'auto'},
          providers: [RoleProvider.plain(store)],
        ),
        // A provider of the shell role that brings go and requires the
        // store role, whose every provider brings auto.
        TestModule(
          'frame',
          dependsOn: {'go'},
          requires: {store},
          providers: [RoleProvider.plain(shell)],
        ),
      ]),
    );

    expect(harness.casesOfRole(shell).map((c) => '$c'), [
      'shell by frame (disk)',
      'shell by frame (cloud)',
    ]);
    final results = await harness.checkAll();
    expect(failingOf(results), {
      'frame (disk)',
      'frame (cloud)',
      'shell by frame (disk)',
      'shell by frame (cloud)',
    });
    expect(
      errorsOf(results),
      everyElement(contains('at most one provider of the nav role')),
    );
  });

  test(
      'checks each module with every provider of each role it requires or '
      'uses', () async {
    expect(await harness.uncheckedProviders(), isEmpty);
  });

  test(
      'names a provider of a role of a module that no app of its cases has, '
      'but none that cannot be in an app with the module', () async {
    final session = TestRole<NoDsl>('session');
    final store = TestRole<NoDsl>('store');
    final harness = ContractHarness(
      ModuleRegistry([
        scaffold(),
        TestModule(
          'feature',
          requires: {store},
          uses: {nav},
          variants: Variants(
            role: state,
            byProvider: {const ModuleId('bloc'): none},
          ),
        ),
        TestModule('bloc', providers: [RoleProvider.plain(state)]),
        // Feature has no variant for signals, so the two are in no app.
        TestModule('signals', providers: [RoleProvider.plain(state)]),
        TestModule('disk', providers: [RoleProvider.plain(store)]),
        TestModule('go', providers: [RoleProvider.plain(nav)]),
        // No module provides the session role, so the apps with cloud or
        // auto do not resolve.
        TestModule(
          'cloud',
          providers: [RoleProvider.plain(store)],
          requires: {session},
        ),
        TestModule(
          'auto',
          providers: [RoleProvider.plain(nav)],
          requires: {session},
        ),
      ]),
    );

    expect(await harness.uncheckedProviders(), [
      equals(
        'No case of feature builds an app in which cloud provides the store '
        'role, which feature requires.',
      ),
      equals(
        'No case of feature builds an app in which auto provides the nav '
        'role, which feature uses.',
      ),
    ]);
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
      expect(unchosen.hook, isNull);
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

    test(
        'gives the result the data and the roles of its app, with the context '
        'of the harness and the choices of the roles', () async {
      final pick = TestRole<String>(
        'pick',
        options: const [RoleOption(name: 'pick', help: 'What to pick.')],
        template: _PickTemplate(),
      );
      const context = ModuleContext(
        appName: 'bird_watch',
        orgName: 'org.example',
        appIdentity: AppIdentity(
          platforms: ['android'],
          androidApplicationId: 'org.example.bird_watch',
          iosBundleId: 'org.example.bird-watch',
          androidNamespace: 'org.example.bird_watch',
        ),
      );
      final harness = ContractHarness(
        ModuleRegistry([
          scaffold(),
          TestModule(
            'picker',
            providers: [RoleProvider.plain(pick)],
            contributions: [pick.data('seeds')],
          ),
        ]),
        context: context,
      );

      final result = await harness.check(
        const ContractCase(
          'picker',
          requested: [ModuleId('picker')],
          roleOptions: {'pick': 'blue'},
        ),
      );

      expect(result.errors, isEmpty);
      final hook = result.hook!;
      expect(hook.presentRoles, result.resolution!.presentRoles);
      expect(hook.presentRoles, containsAll([appEntryRole, pick]));
      expect(hook.context, same(context));
      expect(hook.choices, {pick: 'blue'});
      // A role reads from it what its hooks got when the app was rendered.
      final input = pick.hookInput(hook);
      expect([for (final data in input.data) data.value], ['seeds']);
      expect(input.data.single.origin, const ModuleOrigin(ModuleId('picker')));
      expect(input.choice, 'blue');
      expect(input.context.appName, 'bird_watch');
    });

    group('a question of a role', () {
      /// The harness of an app whose one module provides the role [asking]
      /// with the option `--color`.
      ContractHarness harnessOf(TestRole<String> asking) => ContractHarness(
            ModuleRegistry([
              scaffold(),
              TestModule('asker', providers: [RoleProvider.plain(asking)]),
            ]),
          );

      TestRole<String> colors(RoleTemplate<String> template) =>
          TestRole<String>(
            'colors',
            options: const [RoleOption(name: 'color', help: 'The color.')],
            template: template,
          );

      const asker = ContractCase('asker', requested: [ModuleId('asker')]);

      test(
          'gets the answer of a user who presses Enter, and the options that '
          'make the same choice', () async {
        final asking = colors(_AskTemplate());
        final harness = harnessOf(asking);

        final answered = await harness.check(asker);
        expect(answered.errors, isEmpty);
        expect(answered.choices, {asking: 'green'});
        expect(answered.answers, {'color': 'green'});
        expect(answered.app, isNotNull);

        // An option decides without a question.
        final given = await harness.check(
          const ContractCase(
            'asker',
            requested: [ModuleId('asker')],
            roleOptions: {'color': 'red'},
          ),
        );
        expect(given.errors, isEmpty);
        expect(given.choices, {asking: 'red'});
        expect(given.answers, isEmpty);
      });

      test(
          'is an error when the options of its role cannot make the answer '
          'without a terminal', () async {
        /// The only error of the app of a role with [template].
        Future<String> errorOf(RoleTemplate<String> template) async {
          final result = await harnessOf(colors(template)).check(asker);
          expect(result.app, isNull);
          expect(result.hook, isNull);
          return result.errors.single.message;
        }

        expect(
          await errorOf(_AskTemplate(optionsFor: (choice) => {})),
          'The colors role asks a question, but its template gives no option '
          'for '
          'the answer, green, so a run without a terminal cannot make the '
          'choice.',
        );
        expect(
          await errorOf(
            _AskTemplate(optionsFor: (choice) => {'colour': '$choice'}),
          ),
          'The template of the colors role gives --colour for an answer, but '
          'the colors role has no such option.',
        );
        expect(
          await errorOf(_AskTemplate(optionsFor: (choice) => {'color': 'red'})),
          'With --color red, the colors role makes the choice red in a run '
          'without a terminal, not green, which the harness answered.',
        );
        expect(
          await errorOf(_AskTemplate(needsTerminal: true)),
          'A run without a terminal cannot make the choices that the harness '
          'answered with --color green: The colors needs a terminal.',
        );
      });

      test('is an error when its template asks without a terminal', () async {
        final questions = <String, Future<void> Function(SmfPrompter)>{
          'Sure?': (prompter) => prompter.confirm('Sure?'),
          'Name?': (prompter) => prompter.input('Name?'),
          'Which one?': (prompter) => prompter.select('Which one?', ['a']),
          'Which?': (prompter) => prompter.multiSelect('Which?', ['a']),
        };
        for (final MapEntry(key: question, value: ask) in questions.entries) {
          // The harness answers the question in a terminal, and then makes
          // the choice again without one, where the option decides.
          final result = await harnessOf(
            colors(
              _AskTemplate(
                alsoDoes: (environment) => ask(environment.prompter),
              ),
            ),
          ).check(asker);

          expect(result.app, isNull, reason: question);
          expect(
            result.errors.single.message,
            'The template of the colors role failed to choose: Bad state: The '
            'contract harness cannot ask: $question',
            reason: question,
          );
        }
      });

      test('is an error when its template runs a command', () async {
        for (final run in <Future<void> Function(SmfProcessRunner)>[
          (runner) => runner.run('git', ['config', 'user.name']),
          (runner) => runner.runInteractive('git', ['config', 'user.name']),
        ]) {
          final result = await harnessOf(
            colors(
              _AskTemplate(
                alsoDoes: (environment) => run(environment.processRunner),
              ),
            ),
          ).check(asker);

          expect(
            result.errors.single.message,
            'The template of the colors role failed to choose: Bad state: The '
            'contract harness runs no commands: git',
          );
        }
      });

      test('lets its template report what it does', () async {
        // As a template that reads the themes of the app to choose does.
        final role = colors(
          _AskTemplate(
            alsoDoes: (environment) async {
              final logger = environment.logger
                ..info('Choosing a color')
                ..detail('Reading lib/theme.dart');
              logger.progress('Reading the light theme')
                ..update('Reading the colors of the light theme')
                ..complete('Read the light theme');
              logger.progress('Reading the dark theme').fail('No dark theme');
              logger
                ..error('lib/theme.dart has no dark theme')
                ..warn('Green unless --color says otherwise')
                ..success('Read the themes');
            },
          ),
        );

        final result = await harnessOf(role).check(asker);

        expect(result.errors, isEmpty);
        expect(result.choices, {role: 'green'});
      });

      test('of every kind gets its default or first choice', () async {
        final curious = TestRole<String>(
          'curious',
          options: const [RoleOption(name: 'answers', help: 'The answers.')],
          template: _CuriousTemplate(),
        );

        final result = await harnessOf(curious).check(asker);

        expect(result.errors, isEmpty);
        // The defaults of confirm, input and multiSelect, and the first
        // choice of a select without a default.
        expect(result.choices, {curious: 'true, typed, b, one'});
        expect(result.answers, {'answers': 'true, typed, b, one'});
      });
    });

    test('a harness that does not render leaves the app out', () async {
      final harness = ContractHarness(registry, render: false);
      final result = await harness.check(
        const ContractCase('scaffold', requested: [ModuleId('scaffold')]),
      );

      expect(result.errors, isEmpty);
      expect(result.app, isNull);
      expect(result.choices, isNull);
      expect(result.hook, isNull);
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
              // A library of the SDK is always there.
              "import 'dart:async';\n"
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
              'lib/user/user.dart imports package:contract_app/nowhere.dart '
              'in the template of user, but the app has no lib/nowhere.dart.',
            ),
            equals(
              'lib/user/user.dart imports package:zeta/zeta.dart in the '
              'template of user, but the app does not depend on zeta.',
            ),
            equals(
              'lib/user/user.dart imports lib/nav/nav.dart in the template of '
              'user, but that file is of go, which user neither depends on '
              'nor knows through a role.',
            ),
          ],
        );
        // The app with its problems, and what its roles got.
        expect(result.app, isNotNull);
        expect(result.hook!.presentRoles, result.resolution!.presentRoles);
      });

      test(
          'reports an import that the app cannot resolve on the module whose '
          'fragment needs it', () async {
        final harness = ContractHarness(
          ModuleRegistry([
            ...modules,
            TestModule(
              'teller',
              contributions: const [
                SocketContribution.code(
                  AppEntryRole.bootstrapLate,
                  Fragment(
                    'tell();',
                    imports: [
                      ImportRef.app('nowhere.dart'),
                      ImportRef('package:zeta/zeta.dart'),
                    ],
                  ),
                ),
              ],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase('teller', requested: [ModuleId('teller')]),
        );

        // The file is of scaffold, but the fragment of teller needs them.
        expect(
          [
            for (final issue in result.errors)
              '${issue.origin}: ${issue.message}',
          ],
          [
            equals(
              'teller: lib/bootstrap.dart imports '
              'package:contract_app/nowhere.dart for a fragment of teller, '
              'but the app has no lib/nowhere.dart.',
            ),
            equals(
              'teller: lib/bootstrap.dart imports package:zeta/zeta.dart for '
              'a fragment of teller, but the app does not depend on zeta.',
            ),
          ],
        );
      });

      test(
          'imports of a fragment variable belong to the owner of its render '
          'hook', () async {
        final shelf = TestRole<String>('shelf');
        final harness = ContractHarness(
          ModuleRegistry([
            ...modules,
            TestModule(
              'store',
              providers: [
                _VarsProvider(
                  shelf,
                  const {
                    'code': Fragment(
                      'final a = a0.A();\nfinal item = i0.Item();',
                      imports: [
                        ImportRef.app('a/a.dart', prefix: 'a0'),
                        ImportRef.app('item/item.dart', prefix: 'i0'),
                      ],
                    ),
                  },
                ),
              ],
              contributions: [dart('lib/store/store.dart', '{{{code}}}\n')],
            ),
            TestModule(
              'item',
              requires: {shelf},
              contributions: [
                shelf.data('item'),
                dart('lib/item/item.dart', 'class Item {}\n'),
              ],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase(
            'store',
            requested: [ModuleId('store'), ModuleId('lib_a'), ModuleId('item')],
          ),
        );

        // The provider renders the data of the role, so it may import the
        // files of the module that contributes it, but no other.
        expect(
          result.errors.single.message,
          'lib/store/store.dart imports lib/a/a.dart for a fragment of store, '
          'but that file is of lib_a, which store neither depends on nor '
          'knows through a role.',
        );
        expect(
          [
            for (final added
                in result.app!.files['lib/store/store.dart']!.addedImports)
              '${added.import.uri} ${added.contributor}',
          ],
          [
            'package:contract_app/a/a.dart store',
            'package:contract_app/item/item.dart store',
          ],
        );
      });

      test(
          'imports of a variable that depends on a role belong to the module '
          'of its brick', () async {
        final harness = ContractHarness(
          ModuleRegistry([
            ...modules,
            TestModule(
              'reader',
              uses: {nav},
              contributions: [
                BrickContribution(
                  bundle(
                    'reader',
                    files: {'lib/reader/reader.dart': 'final a = {{{a}}};\n'},
                  ),
                  vars: {
                    'a': RoleVar(
                      nav,
                      present: const Fragment(
                        'A()',
                        imports: [ImportRef.app('a/a.dart')],
                      ),
                      absent: 'null',
                    ),
                  },
                ),
              ],
            ),
          ]),
        );

        // With the role, the app has the code of the fragment, whose import
        // reaches a file that the module may not use.
        final withRole = await harness.check(
          const ContractCase(
            'reader with nav',
            requested: [ModuleId('reader'), ModuleId('go'), ModuleId('lib_a')],
          ),
        );
        expect(
          [
            for (final issue in withRole.errors)
              '${issue.origin}: ${issue.message}',
          ],
          [
            equals(
              'reader: lib/reader/reader.dart imports lib/a/a.dart for a '
              'fragment of reader, but that file is of lib_a, which reader '
              'neither depends on nor knows through a role.',
            ),
          ],
        );

        final without = await harness.check(
          const ContractCase(
            'reader',
            requested: [ModuleId('reader'), ModuleId('lib_a')],
          ),
        );
        expect(without.errors, isEmpty);
        expect(
          without.app!.texts['lib/reader/reader.dart'],
          'final a = null;\n',
        );
      });

      test('structural rules read every rendered file', () async {
        final notes = TestRole<NoDsl>(
          'notes',
          structuralRules: const [
            StructuralRule(
              id: 'notes.names_the_app',
              description: 'The notes name the app.',
              check: _checkNotes,
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
                  bundle('notes', files: {'NOTES.md': '# Another app\n'}),
                ),
              ],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase('writer', requested: [ModuleId('writer')]),
        );

        expect(result.errors.map((issue) => issue.message), [
          'NOTES.md does not name contract_app.',
        ]);
        expect(
          result.errors.single.origin,
          const ModuleOrigin(ModuleId('writer')),
        );
      });

      test('the files of render hooks are checked like the files of bricks',
          () async {
        final notes = TestRole<NoDsl>(
          'notes',
          structuralRules: const [
            StructuralRule(
              id: 'notes.names_the_app',
              description: 'The notes name the app.',
              check: _checkNotes,
            ),
          ],
        );
        final harness = ContractHarness(
          ModuleRegistry([
            ...modules,
            TestModule(
              'writer',
              providers: [
                _FilesProvider(notes, const {
                  'NOTES.md': '# Another app\n',
                  'lib/notes/broken.dart': 'final a = ;\n',
                  'lib/notes/notes.dart': "import '../a/a.dart';\n"
                      "import 'missing.dart';\n"
                      "import 'package:zeta/zeta.dart';\n"
                      '\n'
                      'final a = A();\n',
                }),
              ],
              contributions: [
                // A file of a brick finds the file of the hook.
                dart(
                  'lib/notes/reader.dart',
                  "import 'notes.dart';\n\nfinal b = a;\n",
                ),
              ],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase(
            'writer',
            requested: [ModuleId('writer'), ModuleId('lib_a')],
          ),
        );

        expect(
          [
            for (final issue in result.errors)
              '${issue.origin}: ${issue.message}',
          ],
          [
            startsWith('writer: lib/notes/broken.dart does not parse: '),
            equals('writer: NOTES.md does not name contract_app.'),
            equals(
              'writer: lib/notes/notes.dart imports lib/a/a.dart in a file of '
              'the render hook of writer, but that file is of lib_a, which '
              'writer neither depends on nor knows through a role.',
            ),
            equals(
              'writer: lib/notes/notes.dart imports missing.dart in a file of '
              'the render hook of writer, but the app has no '
              'lib/notes/missing.dart.',
            ),
            equals(
              'writer: lib/notes/notes.dart imports package:zeta/zeta.dart in '
              'a file of the render hook of writer, but the app does not '
              'depend on zeta.',
            ),
          ],
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

      test(
          'reports a module that imports the package of a provider without '
          'contributing it', () async {
        final state = TestRole<NoDsl>('state');
        const pinned = PubspecContribution.hosted('flutter_bloc', '^9.1.1');
        const taken = PubspecContribution.hosted('flutter_bloc', 'any');
        const import = "import 'package:flutter_bloc/flutter_bloc.dart';\n";
        final harness = ContractHarness(
          ModuleRegistry([
            scaffold(),
            TestModule(
              'bloc',
              providers: [RoleProvider.plain(state)],
              contributions: const [pinned],
            ),
            TestModule(
              'riverpod',
              providers: [RoleProvider.plain(state)],
              contributions: const [
                PubspecContribution.hosted('flutter_riverpod', '^3.0.0'),
              ],
            ),
            TestModule(
              'banner',
              uses: {state},
              contributions: [
                dart(
                  'lib/banner/banner.dart',
                  '{{#has_state}}\n$import{{/has_state}}\n'
                      'class Banner {}\n',
                ),
                SocketContribution.code(
                  AppEntryRole.bootstrapLate,
                  const Fragment(
                    'Bloc.observer;',
                    imports: [
                      ImportRef('package:flutter_bloc/flutter_bloc.dart'),
                    ],
                  ),
                  when: {state},
                ),
              ],
            ),
            // Taking the package, as the pipeline allows, lets a module
            // import it.
            TestModule(
              'helper',
              dependsOn: {'bloc'},
              contributions: [
                taken,
                dart('lib/helper/helper.dart', '$import\nclass Helper {}\n'),
              ],
            ),
            TestModule(
              'feature',
              variants: Variants(
                role: state,
                byProvider: {
                  const ModuleId('bloc'): (_) => [
                        taken,
                        dart(
                          'lib/feature/feature.dart',
                          '$import\nclass Feature {}\n',
                        ),
                      ],
                  const ModuleId('riverpod'): (_) => const [],
                },
              ),
            ),
            // Depending on the provider is not enough: a module contributes
            // what its code imports.
            TestModule(
              'lazy',
              dependsOn: {'bloc'},
              contributions: [
                dart('lib/lazy/lazy.dart', '$import\nclass Lazy {}\n'),
              ],
            ),
          ]),
        );
        Future<List<String>> errorsOf(String name, List<String> modules) async {
          final result = await harness.check(
            ContractCase(
              name,
              requested: [for (final id in modules) ModuleId(id)],
            ),
          );
          return [
            for (final issue in result.errors)
              '${issue.origin}: ${issue.message}',
          ];
        }

        const uri = 'package:flutter_bloc/flutter_bloc.dart';
        const ofBloc = 'a package of bloc, which provides the state role';
        String bannerTakes(String path, String how) =>
            'banner: $path imports $uri $how of banner, but banner does not '
            'contribute flutter_bloc, $ofBloc.';
        expect(await errorsOf('banner with bloc', ['banner', 'bloc']), [
          bannerTakes('lib/banner/banner.dart', 'in the template'),
          bannerTakes('lib/bootstrap.dart', 'for a fragment'),
        ]);
        // Without bloc, the package is of no provider, and not in the app.
        const notInApp = 'but the app does not depend on flutter_bloc.';
        expect(
          await errorsOf('banner with riverpod', ['banner', 'riverpod']),
          [
            equals(
              'banner: lib/banner/banner.dart imports $uri in the template of '
              'banner, $notInApp',
            ),
            equals(
              'banner: lib/bootstrap.dart imports $uri for a fragment of '
              'banner, $notInApp',
            ),
          ],
        );
        expect(await errorsOf('helper', ['helper']), isEmpty);
        expect(await errorsOf('feature', ['feature', 'bloc']), isEmpty);
        const lazyImports =
            'lazy: lib/lazy/lazy.dart imports $uri in the template of lazy, '
            'but lazy does not contribute flutter_bloc, $ofBloc.';
        expect(await errorsOf('lazy', ['lazy']), [lazyImports]);
        final lazy = await harness.check(
          const ContractCase('lazy', requested: [ModuleId('lazy')]),
        );
        expect(
          lazy.errors.single.hint,
          'A module contributes the packages that its code uses, and the '
          'package of a provider of a role with the constraint any: in its '
          'variant for the provider, or for a provider that depends on it, or '
          'in itself when it depends on the provider.',
        );
      });

      test(
          'a provider of a role may use the package of a module whose data it '
          'renders', () async {
        final state = TestRole<NoDsl>('state');
        final shelf = TestRole<String>('shelf');
        const uri = 'package:flutter_bloc/flutter_bloc.dart';
        final harness = ContractHarness(
          ModuleRegistry([
            scaffold(),
            TestModule(
              'bloc',
              providers: [RoleProvider.plain(state)],
              contributions: const [
                PubspecContribution.hosted('flutter_bloc', '^9.1.1'),
              ],
            ),
            TestModule(
              'store',
              providers: [
                _VarsProvider(
                  shelf,
                  const {
                    'code': Fragment(
                      'final observer = Bloc.observer;',
                      imports: [ImportRef(uri)],
                    ),
                  },
                ),
              ],
              contributions: [
                dart('lib/store/store.dart', '{{{code}}}\n'),
                dart('lib/store/own.dart', "import '$uri';\n"),
              ],
            ),
            // The data of the shelf that needs the package.
            TestModule(
              'item',
              requires: {shelf},
              dependsOn: {'bloc'},
              contributions: [
                shelf.data('item'),
                const PubspecContribution.hosted('flutter_bloc', 'any'),
              ],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase(
            'store',
            requested: [ModuleId('store'), ModuleId('item')],
          ),
        );

        // Its own template does not render the data of the shelf.
        expect(
          [
            for (final issue in result.errors)
              '${issue.origin}: ${issue.message}',
          ],
          [
            equals(
              'store: lib/store/own.dart imports $uri in the template of '
              'store, but store does not contribute flutter_bloc, a package of '
              'bloc, which provides the state role.',
            ),
          ],
        );
      });

      test(
          'a file that the render hook of a provider generates may use the '
          'package of a module whose data the provider renders', () async {
        final state = TestRole<NoDsl>('state');
        final shelf = TestRole<String>('shelf');
        const uri = 'package:flutter_bloc/flutter_bloc.dart';
        final harness = ContractHarness(
          ModuleRegistry([
            scaffold(),
            TestModule(
              'bloc',
              providers: [RoleProvider.plain(state)],
              contributions: const [
                PubspecContribution.hosted('flutter_bloc', '^9.1.1'),
              ],
            ),
            // The hook renders the data of the shelf into a file, as it
            // renders it into a fragment.
            TestModule(
              'store',
              providers: [
                _VarsProvider(
                  shelf,
                  const {},
                  files: const {
                    'lib/store/items/item_1.dart': "import '$uri';\n"
                        '\n'
                        'final observer = Bloc.observer;\n',
                  },
                ),
              ],
            ),
            // The data of the shelf that needs the package.
            TestModule(
              'item',
              requires: {shelf},
              dependsOn: {'bloc'},
              contributions: [
                shelf.data('item'),
                const PubspecContribution.hosted('flutter_bloc', 'any'),
              ],
            ),
          ]),
        );
        Future<List<String>> errorsOf(List<String> modules) async {
          final result = await harness.check(
            ContractCase(
              'store',
              requested: [for (final id in modules) ModuleId(id)],
            ),
          );
          return [
            for (final issue in result.errors)
              '${issue.origin}: ${issue.message}',
          ];
        }

        expect(await errorsOf(['store', 'item']), isEmpty);
        // Without a module whose data needs the package, the provider takes
        // it without contributing it.
        expect(await errorsOf(['store', 'bloc']), [
          equals(
            'store: lib/store/items/item_1.dart imports $uri in a file of the '
            'render hook of store, but store does not contribute '
            'flutter_bloc, a package of bloc, which provides the state role.',
          ),
        ]);
      });

      test(
          'the package check reads exports and every contribution of a '
          'module', () async {
        final state = TestRole<NoDsl>('state');
        final nav = TestRole<NoDsl>('nav');
        const bloc = 'package:flutter_bloc/flutter_bloc.dart';
        final harness = ContractHarness(
          ModuleRegistry([
            scaffold(),
            TestModule(
              'bloc',
              providers: [RoleProvider.plain(state)],
              contributions: const [
                PubspecContribution.hosted('flutter_bloc', '^9.1.1'),
              ],
            ),
            TestModule('go', providers: [RoleProvider.plain(nav)]),
            TestModule(
              'exporter',
              contributions: [
                dart('lib/exporter/exporter.dart', "export '$bloc';\n"),
              ],
            ),
            // A dev dependency, or one that the app leaves out, is a
            // contribution of the module all the same.
            TestModule(
              'tester',
              dependsOn: {'bloc'},
              contributions: [
                const PubspecContribution.hosted(
                  'flutter_bloc',
                  'any',
                  dev: true,
                ),
                dart('test/tester_test.dart', "import '$bloc';\n"),
              ],
            ),
            TestModule(
              'navigator',
              uses: {nav},
              dependsOn: {'bloc'},
              contributions: [
                PubspecContribution.hosted('flutter_bloc', 'any', when: {nav}),
                dart('lib/navigator/navigator.dart', "import '$bloc';\n"),
              ],
            ),
          ]),
        );

        final result = await harness.check(
          const ContractCase(
            'package check',
            requested: [
              ModuleId('exporter'),
              ModuleId('tester'),
              ModuleId('navigator'),
            ],
          ),
        );

        expect(result.resolution!.module(const ModuleId('go')), isNull);
        expect(
          [
            for (final issue in result.errors)
              '${issue.origin}: ${issue.message}',
          ],
          [
            equals(
              'exporter: lib/exporter/exporter.dart exports $bloc in the '
              'template of exporter, but exporter does not contribute '
              'flutter_bloc, a package of bloc, which provides the state '
              'role.',
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
              'lib/user/user.dart imports package:mocks/mocks.dart in the '
              'template of user, but mocks is only a dev dependency of the '
              'app.',
            ),
            equals(
              'lib/user/user.dart exports lib/a/a.dart in the template of '
              'user, but that file is of lib_a, which user neither depends '
              'on nor knows through a role.',
            ),
            equals(
              'lib/user/user.dart exports ../none.dart in the template of '
              'user, but the app has no lib/none.dart.',
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
              'lib/l10n_user.dart imports generated/other.dart in the '
              'template of l10n, but the app has no lib/generated/other.dart.',
            ),
          ],
        );
      });

      test(
          'a file of the app where code generation or the localizations '
          'write theirs is a problem', () async {
        final notes = TestRole<NoDsl>('notes');
        final harness = ContractHarness(
          ModuleRegistry([
            scaffold(),
            TestModule(
              'l10n',
              providers: [
                _FilesProvider(notes, const {
                  'lib/l10n/app_localizations.dart': '// Of the hook.\n',
                }),
              ],
              contributions: [
                const PubspecContribution.sdk('flutter_localizations'),
                const PubspecContribution.flutter(generate: true),
                const CodegenRequest(
                  outputs: ['lib/generated/config.dart', 'lib/other.g.dart'],
                ),
                BrickContribution(
                  bundle(
                    'l10n',
                    files: {
                      'l10n.yaml': '',
                      // One file with the output where case does not
                      // matter.
                      'lib/Generated/Config.dart': '// Of the brick.\n',
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
          [for (final issue in result.errors) '$issue'],
          [
            equals(
              'error [l10n] lib/Generated/Config.dart: A brick of l10n '
              'generates lib/Generated/Config.dart, but the code generation '
              'that l10n asks for writes lib/generated/config.dart, the same '
              'file where case does not matter, once the app is rendered.',
            ),
            equals(
              'error [l10n] lib/l10n/app_localizations.dart: A render hook of '
              'l10n generates lib/l10n/app_localizations.dart, but flutter '
              'pub get, which generates the localizations of l10n.yaml, '
              'writes that file once the app is rendered.',
            ),
          ],
        );
      });

      test('an l10n.yaml that flutter pub get fails on is a problem', () async {
        /// The errors of the app of a module with [l10n] as its
        /// `l10n.yaml`, whose code imports the default localizations.
        Future<List<String>> errorsWith(String l10n) async {
          final result = await ContractHarness(
            ModuleRegistry([
              scaffold(),
              TestModule(
                'l10n',
                contributions: [
                  const PubspecContribution.sdk('flutter_localizations'),
                  const PubspecContribution.flutter(generate: true),
                  BrickContribution(
                    bundle(
                      'l10n',
                      files: {
                        'l10n.yaml': l10n,
                        'lib/l10n_user.dart':
                            "import 'l10n/app_localizations.dart';\n",
                      },
                    ),
                  ),
                ],
              ),
            ]),
          ).check(const ContractCase('l10n', requested: [ModuleId('l10n')]));
          return [for (final issue in result.errors) '$issue'];
        }

        // Flutter takes the defaults for an empty file and an option
        // without a value, and the values below, and it ignores an option
        // it does not know.
        expect(await errorsWith(''), isEmpty);
        expect(await errorsWith('output-dir:\n'), isEmpty);
        expect(
          await errorsWith(
            'synthetic-package: false\n'
            'nullable-getter: false\n'
            'preferred-supported-locales: [en]\n'
            'unknown-option: 5\n',
          ),
          isEmpty,
        );
        expect(await errorsWith('preferred-supported-locales: en\n'), isEmpty);

        /// The error of the module for [problem] of its `l10n.yaml`.
        String error(String problem) => 'error [l10n] l10n.yaml: $problem, '
            'so flutter pub get fails to generate the localizations.';

        expect(await errorsWith('arb-dir: [lib/l10n\n'), [
          startsWith(
            'error [l10n] l10n.yaml: l10n.yaml is not valid YAML, so flutter '
            'pub get fails to generate the localizations: ',
          ),
        ]);
        expect(await errorsWith('# No options yet.\n'), [
          error('l10n.yaml is not a map of options'),
        ]);
        expect(await errorsWith('- lib/l10n\n'), [
          error('l10n.yaml is not a map of options'),
        ]);

        // Every option that Flutter 3.44 reads as text or as true or false,
        // with a value of another type: a list, or yes, which is text in
        // YAML 1.2.
        const textOptions = [
          'arb-dir',
          'output-dir',
          'template-arb-file',
          'output-localization-file',
          'untranslated-messages-file',
          'output-class',
          'header',
          'header-file',
        ];
        const flagOptions = [
          'synthetic-package',
          'use-deferred-loading',
          'required-resource-attributes',
          'nullable-getter',
          'format',
          'use-escaping',
          'suppress-warnings',
          'relax-syntax',
          'use-named-parameters',
        ];
        expect(
          await errorsWith(
            [
              for (final option in textOptions) '$option: [a]',
              for (final option in flagOptions) '$option: yes',
              'preferred-supported-locales: 5',
            ].join('\n'),
          ),
          [
            for (final option in textOptions)
              error('The option $option in l10n.yaml is not text'),
            for (final option in flagOptions)
              error('The option $option in l10n.yaml is not true or false'),
            error(
              'The option preferred-supported-locales in l10n.yaml is neither '
              'text nor a list',
            ),
          ],
        );
        expect(await errorsWith('synthetic-package: true\n'), [
          error('l10n.yaml turns on synthetic-package, which Flutter removed'),
        ]);
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

/// A template that asks which color, green or red, unless the option
/// `--color` gives one, and gives [optionsFor] of its answer. If
/// [needsTerminal] is set, it fails without a terminal even with the
/// option. It does [alsoDoes] before it chooses, with or without the
/// option.
final class _AskTemplate extends RoleTemplate<String> {
  _AskTemplate({
    this.optionsFor = _colorOf,
    this.needsTerminal = false,
    this.alsoDoes,
  });

  static Map<String, String> _colorOf(Object? choice) => {'color': '$choice'};

  /// The options of an answer.
  final Map<String, String> Function(Object? choice) optionsFor;

  /// Whether the template cannot choose without a terminal.
  final bool needsTerminal;

  /// What the template does with the machine and the user before it
  /// chooses.
  final Future<void> Function(SmfEnvironment environment)? alsoDoes;

  @override
  Future<Object?> choose(RoleChoiceContext<String> context) async {
    if (!context.environment.interactive && needsTerminal) {
      throw SmfUsageException('The ${context.role.id} needs a terminal.');
    }
    await alsoDoes?.call(context.environment);
    return context.option('color') ??
        await context.environment.prompter.select(
          'Which color?',
          const ['green', 'red'],
        );
  }

  @override
  Map<String, String> optionsOf(Object? choice) => optionsFor(choice);
}

/// A template that asks a question of every kind and joins the answers,
/// unless the option `--answers` gives them.
final class _CuriousTemplate extends RoleTemplate<String> {
  @override
  Future<Object?> choose(RoleChoiceContext<String> context) async {
    if (context.option('answers') case final answers?) return answers;
    final prompter = context.environment.prompter;
    final confirmed = await prompter.confirm('Sure?', defaultValue: true);
    final typed = await prompter.input('Name?', defaultValue: 'typed');
    final picked = await prompter.multiSelect(
      'Which?',
      const ['a', 'b'],
      defaultValues: const ['b'],
    );
    final selected = await prompter.select('Which one?', const ['one', 'two']);
    return '$confirmed, $typed, ${picked.join()}, $selected';
  }

  @override
  Map<String, String> optionsOf(Object? choice) => {'answers': '$choice'};
}

/// A provider whose render hook returns [vars] and generates [files].
final class _VarsProvider extends RoleProvider<String> {
  _VarsProvider(this.role, this.vars, {this.files = const {}});

  @override
  final Role<String> role;

  final Map<String, Object?> vars;

  final Map<String, String> files;

  @override
  RoleOutput render(RoleHookInput<String> input) =>
      RoleOutput(vars: vars, files: files);
}

/// A provider whose render hook generates [files].
final class _FilesProvider extends RoleProvider<NoDsl> {
  _FilesProvider(this.role, this.files);

  @override
  final Role<NoDsl> role;

  final Map<String, String> files;

  @override
  RoleOutput render(RoleHookInput<NoDsl> input) => RoleOutput(files: files);
}

/// A `{` in a mason template.
const _brace = '{{__LEFT_CURLY_BRACKET__}}';

List<SmfIssue> _checkNotes(StructuralRuleInput<NoDsl> input) => [
      if (input.texts['NOTES.md'] case final text?
          when !text.contains(input.roleInput.context.appName))
        SmfIssue(
          'NOTES.md does not name ${input.roleInput.context.appName}.',
          origin: input.owners['NOTES.md'],
          path: 'NOTES.md',
        ),
    ];

/// A module whose contributions fail.
final class _FailingModule extends SmfModule {
  _FailingModule(String id)
      : descriptor = ModuleDescriptor(
          id: ModuleId(id),
          description: 'The module $id',
          kind: plainKind,
        );

  @override
  final ModuleDescriptor descriptor;

  @override
  List<Contribution> contribute(ModuleContext context) =>
      throw StateError('No contributions.');
}
