// Tests the plan of the jobs of CI that check the matrix: the apps with
// every module that a run takes (a pairwise or 3-wise covering of the
// combinations of the providers of the roles that take one, all of them,
// one by its name, or one for each provider of a role), the shards of the
// matrix, the options of the matrix tools that choose them, and the plan
// that the tools print for the workflows.
import 'dart:convert';

import 'package:smf_bloc/smf_bloc.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_riverpod/smf_riverpod.dart';
import 'package:test/test.dart';

/// A role that an app has at most one provider of.
final class _Role extends Role<Object> {
  const _Role(this.id);

  @override
  final String id;

  @override
  String get description => 'Role $id';

  @override
  RoleCardinality get cardinality => RoleCardinality.atMostOne;
}

/// The kind of the modules of the synthetic registries, which may have
/// variants.
const _kind = ModuleKind(id: 'synthetic', label: 'Synthetic');

/// A module [id] that provides [provides], depends on [dependsOn] and has
/// [variants], and contributes nothing.
final class _Module extends SmfModule {
  const _Module(
    this.id, {
    this.provides = const {},
    this.dependsOn = const {},
    this.variants,
  });

  final ModuleId id;
  final Set<Role> provides;
  final Set<ModuleId> dependsOn;
  final Variants? variants;

  @override
  ModuleDescriptor get descriptor => ModuleDescriptor(
        id: id,
        description: 'Synthetic',
        kind: _kind,
        dependsOn: dependsOn,
        providers: [for (final role in provides) RoleProvider.plain(role)],
        variants: variants,
      );
}

/// A module whose contributions cannot be collected, so the cases of the
/// contract harness with it fail.
final class _Broken extends SmfModule {
  const _Broken();

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: ModuleId('broken'),
        description: 'Broken',
        kind: _kind,
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      throw StateError('broken');
}

/// A synthetic registry with the app entry of flutter_core and, for each of
/// [sizes], a role `r<i>` with as many providers, `r<i>_p<j>`.
List<SmfModule> _registry(List<int> sizes) {
  // One instance of each role, as roles compare by identity.
  final roles = [for (final (index, _) in sizes.indexed) _Role('r$index')];
  return [
    const FlutterCoreModule(),
    for (final (role, size) in sizes.indexed)
      for (var provider = 0; provider < size; provider++)
        _Module(ModuleId('r${role}_p$provider'), provides: {roles[role]}),
  ];
}

/// The providers of the roles of [sizes], one list for each role.
List<List<String>> _providers(List<int> sizes) => [
      for (final (role, size) in sizes.indexed)
        [
          for (var provider = 0; provider < size; provider++)
            'r${role}_p$provider',
        ],
    ];

/// The modules of the registry of [sizes] and its apps with every module,
/// one for each combination of the providers of its roles, in the order of
/// the contract harness, which varies the provider of the last role first,
/// named as the harness names them; built by hand, without rendering them.
({List<SmfModule> modules, List<MatrixApp> apps}) _product(List<int> sizes) {
  var combinations = <List<String>>[[]];
  for (final providers in _providers(sizes)) {
    combinations = [
      for (final combination in combinations)
        for (final provider in providers) [...combination, provider],
    ];
  }
  return (
    modules: _registry(sizes),
    apps: [
      for (final combination in combinations)
        MatrixApp(
          'every module (${combination.join(', ')})',
          [
            const ModuleId('flutter_core'),
            for (final provider in combination) ModuleId(provider),
          ],
          everyModuleWith: [
            for (final provider in combination)
              if (!provider.endsWith('_p0')) ModuleId(provider),
          ],
        ),
    ],
  );
}

/// The sets of [strength] providers of different roles of the synthetic
/// registries, whose providers are `r<i>_p<j>`, that the apps of [apps]
/// have, as texts such as `r0_p1+r2_p0`.
Set<String> _tuplesOf(List<MatrixApp> apps, int strength) {
  final tuples = <String>{};
  for (final app in apps) {
    final providers = [
      for (final id in app.modules)
        if (RegExp(r'^r\d+_p\d+$').hasMatch(id.value)) id.value,
    ]..sort();
    void add(int start, List<String> chosen) {
      if (chosen.length == strength) {
        tuples.add(chosen.join('+'));
        return;
      }
      for (var i = start; i < providers.length; i++) {
        add(i + 1, [...chosen, providers[i]]);
      }
    }

    add(0, []);
  }
  return tuples;
}

/// The modules that the apps of [apps] have.
Set<ModuleId> _modulesOf(List<MatrixApp> apps) => {
      for (final app in apps) ...app.modules,
    };

/// The names of [apps].
List<String> _names(List<MatrixApp> apps) => [
      for (final app in apps) app.name,
    ];

/// A registry whose modules fit only some combinations, as the contract
/// harness finds them (see `ContractHarness.casesOfAll`):
/// - `r0_p2` depends on `r1_p1`, a provider of `r1`, so it fits only in the
///   apps with `r1_p1`, and the harness has no app of `r0_p2` with another
///   provider of `r1`;
/// - `feature` has a variant only for `r2_p0`, so the apps with `r2_p1`
///   leave it out;
/// - `inner`, `middle` and `outer` have a variant only for `r0_p1`, `r1_p1`
///   and `r2_p1`, and each depends on the one before, so `outer` fits only
///   in the app with the three of them, whose pairs other apps have too.
final _constrained = <SmfModule>[
  const FlutterCoreModule(),
  const _Module(ModuleId('r0_p0'), provides: {_Role('r0')}),
  const _Module(ModuleId('r0_p1'), provides: {_Role('r0')}),
  const _Module(
    ModuleId('r0_p2'),
    provides: {_Role('r0')},
    dependsOn: {ModuleId('r1_p1')},
  ),
  const _Module(ModuleId('r1_p0'), provides: {_Role('r1')}),
  const _Module(ModuleId('r1_p1'), provides: {_Role('r1')}),
  const _Module(ModuleId('r1_p2'), provides: {_Role('r1')}),
  const _Module(ModuleId('r2_p0'), provides: {_Role('r2')}),
  const _Module(ModuleId('r2_p1'), provides: {_Role('r2')}),
  _Module(
    const ModuleId('feature'),
    variants: Variants(
      role: const _Role('r2'),
      byProvider: {const ModuleId('r2_p0'): (context) => const []},
    ),
  ),
  _Module(
    const ModuleId('inner'),
    variants: Variants(
      role: const _Role('r0'),
      byProvider: {const ModuleId('r0_p1'): (context) => const []},
    ),
  ),
  _Module(
    const ModuleId('middle'),
    dependsOn: const {ModuleId('inner')},
    variants: Variants(
      role: const _Role('r1'),
      byProvider: {const ModuleId('r1_p1'): (context) => const []},
    ),
  ),
  _Module(
    const ModuleId('outer'),
    dependsOn: const {ModuleId('middle')},
    variants: Variants(
      role: const _Role('r2'),
      byProvider: {const ModuleId('r2_p1'): (context) => const []},
    ),
  ),
];

void main() {
  group('a pairwise covering of the apps with every module', () {
    test(
        'has every pair of providers of two different roles, every provider '
        'and every module in one of its apps, which keep their order', () {
      for (final sizes in const [
        [2],
        [2, 2],
        [3, 2],
        [2, 2, 2],
        [4, 3, 2],
        [2, 2, 2, 3, 2],
        [3, 3, 3, 3, 3],
      ]) {
        final (:modules, :apps) = _product(sizes);

        final selected = EveryModuleCombinations.pairwise.select(
          apps,
          modules,
        );

        expect(_tuplesOf(selected, 2), _tuplesOf(apps, 2), reason: '$sizes');
        expect(_tuplesOf(selected, 1), _tuplesOf(apps, 1), reason: '$sizes');
        expect(_modulesOf(selected), _modulesOf(apps), reason: '$sizes');
        expect(
          selected,
          orderedEquals(apps.where(selected.contains)),
          reason: '$sizes',
        );
      }
    });

    test('is the same for the same apps', () {
      final first = _product(const [2, 2, 2, 3, 2]);
      final second = _product(const [2, 2, 2, 3, 2]);

      List<String> pairwise(List<MatrixApp> apps, List<SmfModule> modules) =>
          _names(EveryModuleCombinations.pairwise.select(apps, modules));

      expect(
        pairwise(first.apps, first.modules),
        pairwise(second.apps, second.modules),
      );
    });

    test(
        'takes one app for each provider of the one role with several, as '
        'the apps of bloc and riverpod of the CLI', () async {
      final (:apps, :failed) = await everyModuleAppsOf(smfModules);
      final product = _product(const [3]);

      expect(failed, isEmpty);
      expect(
        _names(EveryModuleCombinations.pairwise.select(apps, smfModules)),
        ['every module (bloc)', 'every module (riverpod)'],
      );
      expect(
        EveryModuleCombinations.pairwise.select(
          product.apps,
          product.modules,
        ),
        product.apps,
      );
    });

    test('takes the one app of a registry without a role with several', () {
      final (:modules, :apps) = _product(const [1, 1]);

      expect(EveryModuleCombinations.pairwise.select(apps, modules), apps);
      expect(EveryModuleCombinations.threeWise.select(apps, modules), apps);
    });

    test(
        'stays small: for 5 roles of 3 providers, at most 15 of the 243 '
        'apps, and at most 60 for a 3-wise covering', () {
      final (:modules, :apps) = _product(const [3, 3, 3, 3, 3]);

      expect(apps, hasLength(243));
      expect(
        EveryModuleCombinations.pairwise.select(apps, modules),
        hasLength(lessThanOrEqualTo(15)),
      );
      expect(
        EveryModuleCombinations.threeWise.select(apps, modules),
        hasLength(lessThanOrEqualTo(60)),
      );
    });

    test(
        'respects the rules of the contract harness for the modules that fit '
        'in an app: it takes only apps that the harness builds, needs no '
        'pair that no app has, and takes a module that fits only one '
        'combination', () async {
      final (:apps, :failed) = await everyModuleAppsOf(_constrained);

      expect(failed, isEmpty);
      // 3 * 3 * 2 combinations, but none of r0_p2 without r1_p1.
      expect(apps, hasLength(14));
      expect(_tuplesOf(apps, 2), isNot(contains('r0_p2+r1_p0')));
      expect(
        [
          for (final app in apps)
            if (app.modules.contains(const ModuleId('outer'))) app.name,
        ],
        ['every module (r0_p1, r1_p1, r2_p1)'],
      );
      for (final combinations in [
        EveryModuleCombinations.pairwise,
        EveryModuleCombinations.threeWise,
      ]) {
        final selected = combinations.select(apps, _constrained);
        final strength = combinations.strength!;

        expect(
          selected,
          orderedEquals(apps.where(selected.contains)),
          reason: '$combinations',
        );
        expect(
          _tuplesOf(selected, strength),
          _tuplesOf(apps, strength),
          reason: '$combinations',
        );
        expect(_modulesOf(selected), _modulesOf(apps), reason: '$combinations');
      }
    });

    test(
        'of the apps that the contract harness builds for 5 roles of 3 '
        'providers has every pair in at most 15 of the 243 apps', () async {
      final modules = _registry(const [3, 3, 3, 3, 3]);

      final (:apps, :failed) = await everyModuleAppsOf(modules);

      expect(failed, isEmpty);
      expect(apps, hasLength(243));
      final selected = EveryModuleCombinations.pairwise.select(apps, modules);
      expect(selected, hasLength(lessThanOrEqualTo(15)));
      expect(_tuplesOf(selected, 2), _tuplesOf(apps, 2));
    });
  });

  group('a 3-wise covering of the apps with every module', () {
    test(
        'has every triple of providers of three different roles in one of '
        'its apps, and all of them with fewer roles', () {
      for (final sizes in const [
        [2, 3],
        [2, 2, 2],
        [2, 2, 2, 3, 2],
        [3, 3, 3, 3, 3],
      ]) {
        final (:modules, :apps) = _product(sizes);

        final selected = EveryModuleCombinations.threeWise.select(
          apps,
          modules,
        );

        expect(_tuplesOf(selected, 3), _tuplesOf(apps, 3), reason: '$sizes');
        expect(_tuplesOf(selected, 2), _tuplesOf(apps, 2), reason: '$sizes');
        if (sizes.length < 3) expect(selected, apps, reason: '$sizes');
      }
    });
  });

  group('the other selections of the apps with every module', () {
    test('all of them takes every app', () {
      final (:modules, :apps) = _product(const [3, 3, 3]);

      expect(EveryModuleCombinations.all.select(apps, modules), apps);
      expect(EveryModuleCombinations.all.problemsOf(const []), isEmpty);
    });

    test('are read from the option of the matrix tools', () {
      expect(
        [
          for (final option in ['pairwise', '3-wise', 'all', 'most'])
            EveryModuleCombinations.parse(option),
        ],
        [
          EveryModuleCombinations.pairwise,
          EveryModuleCombinations.threeWise,
          EveryModuleCombinations.all,
          isNull,
        ],
      );
      expect(
        [for (final value in EveryModuleCombinations.values) value.option],
        ['pairwise', '3-wise', 'all'],
      );
    });

    test('one by its name takes it, or none, which is a problem', () {
      final (:modules, :apps) = _product(const [2, 2]);
      const named = NamedEveryModuleApp('every module (r0_p1, r1_p0)');
      const missing = NamedEveryModuleApp('every module (bloc)');

      expect(_names(named.select(apps, modules)), [named.name]);
      expect(named.problemsOf(named.select(apps, modules)), isEmpty);
      expect(missing.select(apps, modules), isEmpty);
      expect(missing.problemsOf(const []), [
        'No app with every module is every module (bloc).',
      ]);
    });

    test(
        'one for each provider of a role takes the first app of each, which '
        'is the first combination that fits it', () async {
      final (:apps, :failed) = await everyModuleAppsOf(_constrained);
      final (apps: cli, failed: cliFailed) = await everyModuleAppsOf(
        smfModules,
      );

      expect(failed, isEmpty);
      expect(cliFailed, isEmpty);
      expect(
        _names(
          const EveryModuleAppPerProvider(_Role('r0')).select(
            apps,
            _constrained,
          ),
        ),
        [
          'every module (r0_p0, r1_p0, r2_p0)',
          'every module (r0_p1, r1_p0, r2_p0)',
          'every module (r0_p2, r1_p1, r2_p0)',
        ],
      );
      // One app entry, flutter_core, so one app, with bloc, the first state
      // manager.
      expect(
        _names(
          const EveryModuleAppPerProvider(appEntryRole).select(
            cli,
            smfModules,
          ),
        ),
        ['every module (bloc)'],
      );
      expect(
        const EveryModuleAppPerProvider(appEntryRole).problemsOf(const []),
        isEmpty,
      );
    });
  });

  group('a shard of the matrix', () {
    test('is read as <index>/<count>, from 1', () {
      final shard = MatrixShard.parse('2/3');

      expect(shard?.index, 2);
      expect(shard?.count, 3);
      expect('$shard', '2/3');
      for (final text in ['0/2', '3/2', '1/0', '1', 'a/b', '1/2/3', '-1/2']) {
        expect(MatrixShard.parse(text), isNull, reason: text);
      }
    });

    test(
        'takes every app in exactly one of the shards, in the order of the '
        'apps, one after another round the shards', () {
      final items = [for (var item = 1; item <= 10; item++) item];

      final shards = [
        for (final shard in MatrixShard.allOf(3)) shard.of(items),
      ];

      expect(
        [for (final shard in MatrixShard.allOf(3)) '$shard'],
        ['1/3', '2/3', '3/3'],
      );
      expect(shards, [
        [1, 4, 7, 10],
        [2, 5, 8],
        [3, 6, 9],
      ]);
      expect([for (final shard in shards) ...shard]..sort(), items);
      expect(const MatrixShard(1, 1).of(items), items);
    });
  });

  group('runMatrix', () {
    late List<String> log;
    late List<List<String>> created;

    setUp(() {
      log = [];
      created = [];
    });

    Future<int> run(
      List<SmfModule> modules, {
      bool everyModule = false,
      EveryModuleSelection everyModuleApps = EveryModuleCombinations.all,
      MatrixShard? shard,
    }) =>
        runMatrix(
          modules,
          directory: '/apps',
          everyModule: everyModule,
          everyModuleApps: everyModuleApps,
          shard: shard,
          commands: MatrixCommands(
            log: log.add,
            create: (arguments, onCreated) async {
              created.add(arguments);
              onCreated(
                GeneratedApp(
                  name: arguments[1],
                  path: '/apps/${arguments[1]}',
                ),
              );
              return 0;
            },
            analyze: (directory) async => (0, 'Analyzed $directory'),
            test: (generated, app, tests) async => (0, ''),
          ),
        );

    test(
        'checks in each shard its share of the apps, each in exactly one '
        'shard, with its number in the matrix', () async {
      final (:apps, :failed) = await matrixOf(smfModules);
      expect(failed, isEmpty);

      final shards = <List<String>>[];
      for (final shard in MatrixShard.allOf(3)) {
        created.clear();
        expect(await run(smfModules, shard: shard), 0, reason: '$shard');
        shards.add([for (final arguments in created) arguments[1]]);
        expect(log.last, '\n${created.length} apps generated in /apps.');
      }

      String number(int index) => 'app_${index + 1}';
      expect(shards, [
        for (final shard in MatrixShard.allOf(3))
          [
            for (final (index, _) in apps.indexed)
              if (index % 3 == shard.index - 1) number(index),
          ],
      ]);
      expect(
        [for (final shard in shards) ...shard]..sort(),
        [for (final (index, _) in apps.indexed) number(index)]..sort(),
      );
    });

    test('checks the apps with every module of the selection it is given',
        () async {
      final modules = _registry(const [2, 2, 2]);

      expect(
        await run(
          modules,
          everyModule: true,
          everyModuleApps: EveryModuleCombinations.pairwise,
        ),
        0,
      );
      expect(created, hasLength(4));

      created.clear();
      expect(await run(modules, everyModule: true), 0);
      expect(created, hasLength(8));

      // A shard of them.
      created.clear();
      expect(
        await run(
          modules,
          everyModule: true,
          everyModuleApps: EveryModuleCombinations.pairwise,
          shard: const MatrixShard(2, 2),
        ),
        0,
      );
      expect(created, hasLength(2));
    });

    test(
        'checks the app with every module of the name it is given, also when '
        'another case built it, with its number in the matrix', () async {
      const modules = [FlutterCoreModule(), BlocModule(), RiverpodModule()];

      expect(
        await run(
          modules,
          everyModule: true,
          everyModuleApps: const NamedEveryModuleApp(
            'every module (riverpod)',
          ),
        ),
        0,
      );
      expect(
        [for (final arguments in created) arguments.take(4).join(' ')],
        ['create app_3 -m riverpod,flutter_core'],
      );

      created.clear();
      expect(
        await run(
          modules,
          everyModule: true,
          everyModuleApps: const NamedEveryModuleApp('every module (redux)'),
        ),
        1,
      );
      expect(created, isEmpty);
      expect(log.sublist(log.indexOf('Problems:') + 1), [
        'No app with every module is every module (redux).',
      ]);
    });
  });

  group('createEveryModuleApps', () {
    late List<String> log;
    late List<List<String>> created;

    setUp(() {
      log = [];
      created = [];
    });

    Future<int> create(
      List<SmfModule> modules,
      EveryModuleSelection selection, {
      bool withoutExternalSteps = false,
    }) =>
        createEveryModuleApps(
          modules,
          directory: '/apps',
          name: 'start_app',
          withoutExternalSteps: withoutExternalSteps,
          selection: selection,
          commands: MatrixCommands(
            log: log.add,
            create: (arguments, onCreated) async {
              created.add(arguments);
              onCreated(
                GeneratedApp(
                  name: arguments[1],
                  path: '/apps/${arguments[1]}',
                ),
              );
              return 0;
            },
          ),
        );

    test(
        'generates only the app with every module of the name it is given, '
        'under its own name', () async {
      for (final withoutExternalSteps in [false, true]) {
        created.clear();
        expect(
          await create(
            smfModules,
            const NamedEveryModuleApp('every module (riverpod)'),
            withoutExternalSteps: withoutExternalSteps,
          ),
          0,
        );
        expect(
          [for (final arguments in created) arguments[1]],
          ['start_app_riverpod'],
        );
        expect(
          created.single[created.single.indexOf('-m') + 1].split(','),
          contains('riverpod'),
        );
        expect(
          created.single[created.single.indexOf('-m') + 1].split(','),
          withoutExternalSteps
              ? isNot(contains('firebase_core'))
              : contains('firebase_core'),
        );
      }
    });

    test(
        'fails without generating an app for a name that no app with every '
        'module has', () async {
      expect(
        await create(
          smfModules,
          const NamedEveryModuleApp('every module (redux)'),
        ),
        1,
      );

      expect(created, isEmpty);
      expect(log, [
        'Problems:',
        'No app with every module is every module (redux).',
      ]);
    });

    test('generates the apps with every module of a covering', () async {
      expect(
        await create(
          _registry(const [2, 2, 2]),
          EveryModuleCombinations.pairwise,
        ),
        0,
      );

      expect(
        [for (final arguments in created) arguments[1]],
        hasLength(4),
      );
    });
  });

  group('the options of the matrix tools', () {
    test(
        'choose a pairwise covering of the apps with every module and every '
        'shard without them', () {
      final options = MatrixToolOptions.parse(['/apps', 'app']);

      expect(options.arguments, ['/apps', 'app']);
      expect(options.selection, EveryModuleCombinations.pairwise);
      expect(options.shard, isNull);
      expect(options.problem, isNull);
    });

    test(
        'are taken out of the options before the directory, in any order, '
        'and the others stay', () {
      final matrix = MatrixToolOptions.parse(
        ['--combinations', 'all', '--shard', '2/3', '/apps', 'an app'],
      );
      expect(matrix.arguments, ['/apps', 'an app']);
      expect(matrix.selection, EveryModuleCombinations.all);
      expect('${matrix.shard}', '2/3');
      expect(matrix.problem, isNull);

      final everyModule = MatrixToolOptions.parse([
        '--shard',
        '1/2',
        '--every-module',
        '--app',
        'every module (bloc)',
        '/apps',
      ]);
      expect(everyModule.arguments, ['--every-module', '/apps']);
      expect(
        everyModule.selection,
        isA<NamedEveryModuleApp>().having(
          (selection) => selection.name,
          'name',
          'every module (bloc)',
        ),
      );
      expect('${everyModule.shard}', '1/2');
      expect(everyModule.problem, isNull);

      // The options after the directory and the name of --create are those
      // of smf create.
      final create = MatrixToolOptions.parse([
        '--create',
        '--app',
        'every module (bloc)',
        '--without-external-steps',
        '/apps',
        'start_app',
        '--org',
        'com.example',
        '--app',
        'x',
      ]);
      expect(create.arguments, [
        '--create',
        '--without-external-steps',
        '/apps',
        'start_app',
        '--org',
        'com.example',
        '--app',
        'x',
      ]);
      expect(create.selection, isA<NamedEveryModuleApp>());
      expect(create.problem, isNull);

      // The app of the matrix that --add-app-tests adds the tests to.
      final add = MatrixToolOptions.parse([
        '--add-app-tests',
        '--without-external-steps',
        '--app',
        'every module (bloc)',
        '/apps/start_app',
        'app_tests/start',
      ]);
      expect(add.arguments, [
        '--add-app-tests',
        '--without-external-steps',
        '/apps/start_app',
        'app_tests/start',
      ]);
      expect(add.selection, isA<NamedEveryModuleApp>());
      expect(add.problem, isNull);

      expect(
        MatrixToolOptions.parse(['--combinations', '3-wise', '/apps'])
            .selection,
        EveryModuleCombinations.threeWise,
      );
    });

    test('have a problem when they are wrong or do not go together', () {
      for (final (arguments, problem) in [
        (['--combinations', 'most', '/apps'], contains('pairwise, 3-wise')),
        (['--combinations'], contains('--combinations')),
        (['--shard', '3/2', '/apps'], contains('--shard')),
        (['--shard', '1/2', '--shard', '2/2', '/apps'], contains('once')),
        (['--app', 'every module (bloc)', '/apps'], contains('--app')),
        (
          ['--create', '--shard', '1/2', '/apps', 'start_app'],
          contains('--shard'),
        ),
        (
          [
            '--every-module',
            '--app',
            'every module (bloc)',
            '--combinations',
            'all',
            '/apps',
          ],
          contains('--app'),
        ),
      ]) {
        expect(
          MatrixToolOptions.parse(arguments).problem,
          problem,
          reason: '$arguments',
        );
      }
    });
  });

  group('the plan of the jobs of CI', () {
    test(
        'of the CLI checks a pairwise covering of the apps with every module '
        'in one shard, builds and starts each app of pairwise coverings, and '
        'one app for each app entry', () async {
      final (:plan, :problems) = await matrixPlanOf(
        smfModules,
        native: appEntryRole,
      );

      expect(problems, isEmpty);
      expect(plan, {
        'combinations': 'pairwise',
        'shards': ['1/1'],
        'apps': ['every module (bloc)', 'every module (riverpod)'],
        'start': ['every module (bloc)', 'every module (riverpod)'],
        'entries': ['every module (bloc)'],
      });
    });

    test(
        'of a registry without native apps has only the combinations and the '
        'shards', () async {
      final (:plan, :problems) = await matrixPlanOf(
        const [FlutterCoreModule(), BlocModule(), RiverpodModule()],
      );

      expect(problems, isEmpty);
      expect(plan, {
        'combinations': 'pairwise',
        'shards': ['1/1'],
      });
    });

    test(
        'with every combination checks all of them up to 100, and a 3-wise '
        'covering of more, in as many shards as it takes for each to check '
        'at most 24 apps', () async {
      final cli = await matrixPlanOf(smfModules, everyCombination: true);
      expect(cli.problems, isEmpty);
      expect(cli.plan['combinations'], 'all');

      // 2 ** 7 = 128 combinations.
      final modules = _registry(const [2, 2, 2, 2, 2, 2, 2]);
      final (:plan, :problems) = await matrixPlanOf(
        modules,
        everyCombination: true,
      );
      expect(problems, isEmpty);
      expect(plan['combinations'], '3-wise');

      // The jobs check the apps of the matrix, and the apps with every
      // module again in a directory whose name has letters beyond ASCII.
      final matrix = await matrixOf(
        modules,
        everyModuleApps: EveryModuleCombinations.threeWise,
      );
      final checked = matrix.apps.length +
          matrix.apps.where((app) => app.everyModuleWith != null).length;
      final count = (checked + appsPerShard - 1) ~/ appsPerShard;
      expect(appsPerShard, 24);
      expect(count, greaterThan(1));
      expect(plan['shards'], [
        for (var shard = 1; shard <= count; shard++) '$shard/$count',
      ]);
    });

    test('has the problems of the cases of the contract harness', () async {
      final (:plan, :problems) = await matrixPlanOf(
        const [FlutterCoreModule(), _Broken()],
      );

      expect(problems, [
        startsWith('broken: error [broken]: broken failed to contribute'),
        startsWith('every module: error [broken]'),
      ]);
      expect(plan, isEmpty);
    });

    test(
        'is printed for the workflows as one line of JSON, with its problems '
        'and its usage apart', () async {
      final out = <String>[];
      final err = <String>[];
      Future<int> printPlan(List<SmfModule> modules, List<String> options) =>
          printMatrixPlan(
            modules,
            options,
            native: appEntryRole,
            out: out.add,
            err: err.add,
          );

      expect(await printPlan(smfModules, const []), 0);
      expect(out, hasLength(1));
      expect(
        jsonDecode(out.single),
        (await matrixPlanOf(smfModules, native: appEntryRole)).plan,
      );
      expect(err, isEmpty);

      out.clear();
      expect(await printPlan(smfModules, const ['--every-combination']), 0);
      expect(
        (jsonDecode(out.single) as Map<String, Object?>)['combinations'],
        'all',
      );

      out.clear();
      expect(await printPlan(smfModules, const ['--all']), 64);
      expect(out, isEmpty);
      expect(err.single, startsWith('Usage: '));

      err.clear();
      expect(
        await printPlan(const [FlutterCoreModule(), _Broken()], const []),
        1,
      );
      expect(out, isEmpty);
      expect(err, [
        'Problems:',
        startsWith('broken: error [broken]'),
        startsWith('every module: error [broken]'),
      ]);
    });
  });
}
