import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

List<Contribution> _none(ModuleContext context) => const [];

void main() {
  final nav = TestRole<NoDsl>('nav');
  final shell = TestRole<NoDsl>('shell', requires: {nav});
  final state = TestRole<NoDsl>('state');
  final tracking = TestRole<NoDsl>(
    'tracking',
    cardinality: RoleCardinality.many,
  );

  List<ModuleId> idsOf(List<String> names) => [
        for (final name in names) ModuleId(name),
      ];

  Future<ResolverResult> run(
    ModuleRegistry registry,
    List<String> requested, {
    FakeHost? host,
    Set<Role> declined = const {},
    Set<String> excluded = const {},
    Map<Role, ModuleId>? answers,
  }) =>
      resolve(
        requested: idsOf(requested),
        registry: registry,
        environment: (host ?? FakeHost()).environment(),
        declined: declined,
        excluded: {for (final id in excluded) ModuleId(id)},
        answers: answers,
      );

  List<String> names(ResolverResult result) =>
      [for (final module in result.resolution!.modules) module.id.value];

  test('adds dependencies and the only provider of each required role',
      () async {
    final registry = ModuleRegistry([
      scaffold(),
      TestModule('core'),
      TestModule('analytics', dependsOn: {'core'}, requires: {nav}),
      TestModule('tabs', providers: [RoleProvider.plain(shell)]),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
    ]);
    final host = FakeHost();

    final result = await run(registry, ['analytics', 'tabs'], host: host);

    expect(result.issues, isEmpty);
    expect(names(result), ['analytics', 'tabs', 'core', 'scaffold', 'go']);
    final resolution = result.resolution!;
    expect(resolution.presentRoles, {shell, appEntryRole, nav});
    expect(
      [for (final m in resolution.modules) '${m.reason}'],
      [
        'requested',
        'requested',
        'a dependency of analytics',
        'the only provider of the app_entry (every app needs the app_entry)',
        'the only provider of the nav (analytics requires the nav)',
      ],
    );
    // The pipeline reports the additions once the app is resolved.
    expect(host.logger.infos, isEmpty);
    expect(resolution.module(const ModuleId('core')), isNotNull);
    expect(resolution.module(const ModuleId('none')), isNull);
    expect(
      resolution.dependencyClosure(const ModuleId('analytics')),
      {const ModuleId('core')},
    );
  });

  test('a provider of several roles is added once', () async {
    final a = TestRole<NoDsl>('a');
    final b = TestRole<NoDsl>('b');
    final registry = ModuleRegistry([
      scaffold(),
      TestModule(
        'm',
        providers: [RoleProvider.plain(a), RoleProvider.plain(b)],
      ),
      TestModule('n', providers: [RoleProvider.plain(b)]),
      TestModule('f', requires: {a, b}),
    ]);

    final result = await run(registry, ['f']);

    expect(result.issues, isEmpty);
    expect(names(result), ['f', 'scaffold', 'm']);
    expect(
      '${result.resolution!.modules.last.reason}',
      'the only provider of the a (f requires the a)',
    );
  });

  test('--explain takes the first of several providers', () async {
    final nav = TestRole<NoDsl>('nav');
    final registry = ModuleRegistry([
      scaffold(),
      TestModule('home', requires: {nav}),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
      TestModule('auto', providers: [RoleProvider.plain(nav)]),
    ]);

    final result = await resolve(
      requested: const [ModuleId('home')],
      registry: registry,
      environment: FakeHost().environment(),
      explain: true,
    );

    expect(names(result), ['home', 'scaffold', 'go']);
    expect(
      '${result.resolution!.modules.last.reason}',
      'the first provider of the nav (home requires the nav); a run asks '
          'which one, also offering auto',
    );
  });

  test('the role of a provider needs a provider too', () async {
    final registry = ModuleRegistry([
      scaffold(),
      TestModule('tabs', providers: [RoleProvider.plain(shell)]),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
    ]);

    final result = await run(registry, ['tabs']);

    expect(names(result), ['tabs', 'scaffold', 'go']);
    expect(
      '${result.resolution!.modules.last.reason}',
      contains('tabs requires the nav'),
    );
  });

  group('several providers', () {
    final registry = ModuleRegistry([
      scaffold(),
      TestModule('home', requires: {nav}),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
      TestModule('auto', providers: [RoleProvider.plain(nav)]),
    ]);

    test('are a usage error without a terminal', () {
      expect(
        run(registry, ['home']),
        throwsA(
          isA<SmfUsageException>().having(
            (e) => e.message,
            'message',
            allOf(contains('go, auto'), contains('-m')),
          ),
        ),
      );
    });

    test('are a question in a terminal, answered once', () async {
      final host = FakeHost(answers: ['auto'], terminal: true);
      final answers = <Role, ModuleId>{};

      final first = await run(
        registry,
        ['home'],
        host: host,
        answers: answers,
      );
      final second = await run(
        registry,
        ['home'],
        host: host,
        answers: answers,
      );

      expect(names(first), ['home', 'scaffold', 'auto']);
      expect(names(second), names(first));
      expect(host.prompter.asked, hasLength(1));
      expect(
        '${first.resolution!.modules.last.reason}',
        startsWith('chosen to provide the nav'),
      );
    });
  });

  test('a declined role that a module requires is an error', () async {
    final registry = ModuleRegistry([
      scaffold(),
      TestModule('home', requires: {nav}),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
    ]);

    final result = await run(registry, ['home'], declined: {nav});

    expect(result.resolution, isNull);
    expect(result.issues.single.message, contains('as chosen'));
    expect(result.issues.single.origin, isNull);
  });

  test("a required role without providers is the requirer's problem", () async {
    final registry = ModuleRegistry([
      scaffold(),
      TestModule('home', requires: {nav}),
    ]);

    final result = await run(registry, ['home']);

    expect(result.issues.single.message, contains('No module provides'));
    expect(result.issues.single.origin, const ModuleOrigin(ModuleId('home')));
  });

  test('left-out modules are never added', () async {
    final registry = ModuleRegistry([
      scaffold(),
      TestModule('core'),
      TestModule('analytics', dependsOn: {'core'}),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
      TestModule('home', requires: {nav}),
    ]);

    final result = await run(
      registry,
      ['analytics', 'home', 'core'],
      excluded: {'core', 'go'},
    );

    expect(result.resolution, isNull);
    expect(
      result.issues.map((issue) => issue.message),
      [
        'analytics depends on core, which was left out.',
        'No module provides the nav, but home requires the nav.',
      ],
    );
  });

  test('one provider of a role unless it allows many', () async {
    final registry = ModuleRegistry([
      scaffold(),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
      TestModule('auto', providers: [RoleProvider.plain(nav)]),
      TestModule('a1', providers: [RoleProvider.plain(tracking)]),
      TestModule('a2', providers: [RoleProvider.plain(tracking)]),
    ]);

    expect(
      (await run(registry, ['a1', 'a2'])).issues,
      isEmpty,
    );
    expect(
      run(registry, ['go', 'auto']),
      throwsA(
        isA<SmfUsageException>().having(
          (e) => e.message,
          'message',
          contains('go (requested) and auto (requested)'),
        ),
      ),
    );
  });

  group('variants', () {
    final registry = ModuleRegistry([
      scaffold(),
      TestModule(
        'home',
        variants: Variants(
          role: state,
          byProvider: const {ModuleId('bloc'): _none},
        ),
      ),
      TestModule('bloc', providers: [RoleProvider.plain(state)]),
      TestModule('riverpod', providers: [RoleProvider.plain(state)]),
    ]);

    test('take the selected provider', () async {
      final result = await run(registry, ['home', 'bloc']);

      expect(result.issues, isEmpty);
      expect(
        result.resolution!.modules.first.variant,
        const ModuleId('bloc'),
      );
      expect(result.resolution!.modules[1].variant, isNull);
    });

    test('are missing for another provider', () async {
      final result = await run(registry, ['home', 'riverpod']);

      expect(result.resolution, isNull);
      expect(result.issues.single.message, contains('no variant for riverpod'));
      expect(
        result.issues.single.origin,
        const ModuleOrigin(ModuleId('home')),
      );
    });

    test('without the role report only the missing role', () async {
      final result = await run(
        registry,
        ['home'],
        excluded: {'bloc', 'riverpod'},
      );

      expect(result.issues.single.message, contains('No module provides'));
    });
  });

  test('asks again when the remembered provider was left out', () async {
    final registry = ModuleRegistry([
      scaffold(),
      TestModule('home', requires: {nav}),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
      TestModule('auto', providers: [RoleProvider.plain(nav)]),
      TestModule('beamer', providers: [RoleProvider.plain(nav)]),
    ]);
    final host = FakeHost(answers: ['beamer'], terminal: true);

    final result = await run(
      registry,
      ['home'],
      host: host,
      excluded: {'auto'},
      answers: {nav: const ModuleId('auto')},
    );

    expect(names(result), ['home', 'scaffold', 'beamer']);
    expect(host.prompter.asked.single.shown, [
      'go — The module go',
      'beamer — The module beamer',
    ]);
  });

  test('rejects a module that is not in the registry', () {
    expect(
      run(ModuleRegistry([scaffold()]), ['nope']),
      throwsArgumentError,
    );
  });

  test('providerObject finds the provider of a role', () {
    final provider = RoleProvider.plain(nav);
    final module = ResolvedModule(
      TestModule('go', providers: [provider]),
      const Requested(),
    );

    expect(Resolution.providerObject(module, nav), same(provider));
    expect(module.origin, const ModuleOrigin(ModuleId('go')));
  });
}
