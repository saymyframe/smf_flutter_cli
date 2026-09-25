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
      'home (bloc)',
      'home (bloc) with tracking',
      'home (bloc) with nav',
      'home (bloc) with tracking, nav',
      'home (riverpod)',
      'home (riverpod) with tracking',
      'home (riverpod) with nav',
      'home (riverpod) with tracking, nav',
    ]);
    expect(
      cases[3].requested.map((id) => id.value),
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
    for (final contractCase in harness.casesOfModule(const ModuleId('home'))) {
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

  test('checks every module and role', () async {
    final results = await harness.checkAll();

    expect(
      {
        for (final result in results)
          if (result.errors.isNotEmpty) '${result.contractCase}',
      },
      {'broken', 'both'},
    );
  });

  test('checks rendered code with the structural rules of the roles', () {
    final resolution = resolutionOf([scaffold()]);

    final issues = harness.checkStructure(
      resolution: resolution,
      files: {
        'lib/main.dart': 'Future<void> main() async { runApp(App()); }',
        'lib/bootstrap.dart': 'Future<void> bootstrap() async {',
        'README.md': '# not Dart',
      },
      owners: const {'lib/main.dart': ModuleOrigin(ModuleId('scaffold'))},
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
