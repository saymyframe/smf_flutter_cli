import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  final socketRole = TestRole<NoDsl>('s', openToAllModules: true);
  final socket =
      SocketRef<CodeSocket>.role(socketRole, 'code', const CodeSocket());

  Collected contribution(
    ContributionOrigin origin,
    String code, {
    Set<Role> when = const {},
  }) =>
      Collected(
        SocketContribution.code(socket, Fragment(code), when: when)
            .withOrigin(origin),
        origin,
        applies: true,
      );

  Collected of(String module, [String? code, Set<Role> when = const {}]) =>
      contribution(ModuleOrigin(ModuleId(module)), code ?? module, when: when);

  List<String> codes(ContributionOrder order) => [
        for (final c in order.contributions)
          (c.contribution as SocketContribution).fragment!.code,
      ];

  test('dependencies come first, then by name', () {
    final resolution = resolutionOf([
      TestModule('analytics', dependsOn: {'core'}),
      TestModule('core'),
      TestModule('beta'),
    ]);

    final order = orderContributions(
      [of('analytics'), of('beta'), of('core')],
      resolution,
    );

    expect(codes(order), ['beta', 'core', 'analytics']);
    expect(
      order.edges.map((e) => '$e'),
      ['core → analytics (analytics depends on core)'],
    );
    expect(order.cycle, isEmpty);
  });

  test('transitive dependencies count, narrowed to the contributors', () {
    final resolution = resolutionOf([
      TestModule('c', dependsOn: {'b'}),
      TestModule('b', dependsOn: {'a'}),
      TestModule('a'),
    ]);

    final order = orderContributions([of('c'), of('a')], resolution);

    expect(codes(order), ['a', 'c']);
    expect(order.edges.single.reason, 'c depends on a');
  });

  test('after the providers of required and conditional roles', () {
    final nav = TestRole<NoDsl>('nav');
    final di = TestRole<NoDsl>('di');
    final resolution = resolutionOf([
      TestModule('home', requires: {nav}),
      TestModule('menu', uses: {di}),
      TestModule('zgo', providers: [RoleProvider.plain(nav)]),
      TestModule('zdi', providers: [RoleProvider.plain(di)]),
    ]);

    final order = orderContributions(
      [
        of('home'),
        of('menu', 'menu', {di}),
        of('zgo'),
        of('zdi'),
      ],
      resolution,
    );

    expect(codes(order), ['zdi', 'menu', 'zgo', 'home']);
    expect(
      order.edges.map((e) => e.reason),
      containsAll(['home requires the nav', 'menu uses the di']),
    );
  });

  test('a template comes after its providers and their dependencies', () {
    final dep = TestRole<NoDsl>('dep');
    final service = TestRole<NoDsl>('aaa', requires: {dep});
    final resolution = resolutionOf([
      TestModule(
        'zzz',
        dependsOn: {'yyy'},
        providers: [RoleProvider.plain(service)],
      ),
      TestModule('yyy'),
      TestModule('xxx', providers: [RoleProvider.plain(dep)]),
    ]);

    final order = orderContributions(
      [
        contribution(RoleTemplateOrigin(service), 'template'),
        of('zzz'),
        of('yyy'),
        of('xxx'),
      ],
      resolution,
    );

    expect(codes(order), ['xxx', 'yyy', 'zzz', 'template']);
    expect(
      order.edges.map((e) => '$e'),
      containsAll([
        'zzz → role:aaa (role:aaa comes after the providers of the aaa)',
        equals(
            'yyy → role:aaa (role:aaa comes after the providers of the aaa and '
            'the modules they depend on)'),
        'xxx → role:aaa (role:aaa requires the dep)',
      ]),
    );
  });

  test('a template after the providers of roles in its conditions', () {
    final di = TestRole<NoDsl>('di');
    final service = TestRole<NoDsl>('aaa', uses: {di});
    final resolution = resolutionOf([
      TestModule('zdi', providers: [RoleProvider.plain(di)]),
    ]);

    final order = orderContributions(
      [
        contribution(RoleTemplateOrigin(service), 'template', when: {di}),
        of('zdi'),
      ],
      resolution,
    );

    expect(codes(order), ['zdi', 'template']);
    expect(order.edges.single.reason, 'role:aaa uses the di');
  });

  test('edges both ways cancel out', () {
    final role = TestRole<NoDsl>('thing');
    final resolution = resolutionOf([
      TestModule('b', dependsOn: {'a'}),
      TestModule('a', requires: {role}),
      TestModule('bb', providers: [RoleProvider.plain(role)]),
    ]);
    final roleOfB = resolutionOf([
      TestModule('b', dependsOn: {'a'}, providers: [RoleProvider.plain(role)]),
      TestModule('a', requires: {role}),
    ]);

    expect(codes(orderContributions([of('b'), of('a')], resolution)), [
      'a',
      'b',
    ]);
    final order = orderContributions([of('b'), of('a')], roleOfB);
    expect(codes(order), ['a', 'b']);
    expect(order.edges, isEmpty);
  });

  test('a cycle is reported and ordered by name', () {
    final x = TestRole<NoDsl>('x');
    final y = TestRole<NoDsl>('y');
    final z = TestRole<NoDsl>('z');
    final resolution = resolutionOf([
      TestModule('a', requires: {x}, providers: [RoleProvider.plain(z)]),
      TestModule('b', requires: {y}, providers: [RoleProvider.plain(x)]),
      TestModule('c', requires: {z}, providers: [RoleProvider.plain(y)]),
      TestModule('d', dependsOn: {'a'}),
      TestModule('e'),
    ]);

    final order = orderContributions(
      [of('d'), of('c'), of('b'), of('a'), of('e')],
      resolution,
    );

    expect(codes(order), ['e', 'a', 'b', 'c', 'd']);
    expect(order.cycle, ['a', 'b', 'c', 'd']);
  });

  test('a contributor keeps the order of its contributions and variant', () {
    final resolution = resolutionOf([TestModule('home'), TestModule('a')]);

    final order = orderContributions(
      [
        of('home', 'one'),
        contribution(
          const ModuleOrigin(ModuleId('home'), variant: ModuleId('bloc')),
          'two',
        ),
        of('a'),
        of('home', 'three'),
      ],
      resolution,
    );

    expect(codes(order), ['a', 'one', 'two', 'three']);
  });

  test('names contributors', () {
    expect(contributorName(const ModuleOrigin(ModuleId('home'))), 'home');
    expect(
      contributorName(
        const ModuleOrigin(ModuleId('home'), variant: ModuleId('bloc')),
      ),
      'home',
    );
    expect(contributorName(RoleTemplateOrigin(socketRole)), 'role:s');
    expect(contributorName(const PipelineOrigin()), 'pipeline');
    final order = orderContributions(
      [contribution(const PipelineOrigin(), 'p'), of('a')],
      resolutionOf([TestModule('a')]),
    );
    expect(codes(order), ['a', 'p']);
  });
}
