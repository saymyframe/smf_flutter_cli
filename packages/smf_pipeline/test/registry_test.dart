import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

List<String> _problems(List<SmfModule> modules) =>
    ModuleRegistry.problemsOf(modules);

Matcher _hasProblem(String part) => contains(contains(part));

void main() {
  test('a valid registry lists its modules and roles', () {
    final router = TestRole<NoDsl>('nav');
    final layout = TestRole<NoDsl>('shell', requires: {router});
    final registry = ModuleRegistry([
      scaffold(),
      TestModule('tabs', providers: [RoleProvider.plain(layout)]),
      TestModule('home', requires: {router}),
    ]);

    expect(registry.modules, hasLength(3));
    expect(registry.roles, [appEntryRole, layout, router]);
    expect(registry[const ModuleId('home')], isNotNull);
    expect(registry[const ModuleId('nope')], isNull);
    expect(registry.ids.map((id) => id.value), ['scaffold', 'tabs', 'home']);
    expect(
      registry.providersOf(layout).map((m) => m.descriptor.id.value),
      ['tabs'],
    );
    expect(registry.openRoles, {appEntryRole});
  });

  test('rolesOf follows kinds, variants and the roles of roles', () {
    final used = TestRole<NoDsl>('used');
    final state = TestRole<NoDsl>('state', uses: {used});
    final roles = ModuleRegistry.rolesOf([
      TestModule(
        'feature',
        kind: ModuleKinds.feature,
        variants: Variants(role: state, byProvider: const {}),
      ),
    ]);

    expect(roles, containsAll([routerRole, layoutRole, state, used]));
  });

  test('an invalid registry throws with every problem', () {
    expect(
      () => ModuleRegistry([
        TestModule('a', dependsOn: {'missing'}),
        TestModule('a'),
      ]),
      throwsA(
        isA<RegistryException>()
            .having((e) => e.problems, 'problems', hasLength(2))
            .having((e) => '$e', 'toString', contains('missing')),
      ),
    );
  });

  group('module ids', () {
    test('must be lower snake_case', () {
      expect(_problems([TestModule('Home')]), _hasProblem('not lower'));
    });

    test('must be unique', () {
      expect(
        _problems([TestModule('home'), TestModule('home')]),
        _hasProblem('Two modules have the id home'),
      );
    });

    test('must not become reserved words or members of Object', () {
      expect(_problems([TestModule('class')]), _hasProblem('reserved'));
      expect(_problems([TestModule('hash_code')]), _hasProblem('reserved'));
    });

    test('must not be pipeline', () {
      expect(
        _problems([TestModule('pipeline')]),
        _hasProblem('The module id pipeline names the pipeline'),
      );
    });

    test('must not become the same Dart name', () {
      expect(
        _problems([TestModule('a_b1'), TestModule('a_b_1')]),
        _hasProblem('both become the Dart name aB1'),
      );
    });
  });

  group('role ids', () {
    test('must be lower snake_case and unique', () {
      final bad = TestRole<NoDsl>('Bad');
      final one = TestRole<NoDsl>('twin');
      final two = TestRole<NoDsl>('twin');

      expect(
        _problems([
          TestModule('a', uses: {bad, one, two}),
        ]),
        allOf(
          _hasProblem('"Bad" is not lower snake_case'),
          _hasProblem('Two different roles have the id twin'),
        ),
      );
    });

    test('must differ from module ids', () {
      final role = TestRole<NoDsl>('home');

      expect(
        _problems([
          TestModule('home', uses: {role}),
        ]),
        _hasProblem('have the same id'),
      );
    });
  });

  group('dependencies', () {
    test('must be registered and not the module itself', () {
      expect(
        _problems([
          TestModule('a', dependsOn: {'a', 'b'}),
        ]),
        allOf(_hasProblem('depends on itself'), _hasProblem('b, which is not')),
      );
    });

    test('must not form a cycle', () {
      final problems = _problems([
        TestModule('a', dependsOn: {'b'}),
        TestModule('b', dependsOn: {'c'}),
        TestModule('c', dependsOn: {'a'}),
      ]);

      expect(
        problems.where((p) => p.contains('depend on each other')),
        hasLength(1),
      );
    });
  });

  group('descriptors', () {
    test('provide each role once and what their kind requires', () {
      final role = TestRole<NoDsl>('thing');

      expect(
        _problems([
          TestModule(
            'a',
            kind: ModuleKinds.scaffold,
            providers: [RoleProvider.plain(role), RoleProvider.plain(role)],
          ),
        ]),
        allOf(
          _hasProblem('two providers of the role thing'),
          _hasProblem('must provide the role app_entry'),
        ),
      );
    });

    test('do not require or use a role they provide', () {
      final role = TestRole<NoDsl>('thing');

      expect(
        _problems([
          TestModule(
            'a',
            requires: {role},
            providers: [RoleProvider.plain(role)],
          ),
        ]),
        _hasProblem('must not also require or use it'),
      );
    });

    test('have valid variants', () {
      final many = TestRole<NoDsl>('many', cardinality: RoleCardinality.many);
      final state = TestRole<NoDsl>('state');
      List<Contribution> none(ModuleContext context) => const [];

      final problems = _problems([
        TestModule(
          'infra',
          kind: ModuleKinds.infrastructure,
          variants: Variants(role: many, byProvider: const {}),
        ),
        TestModule(
          'self',
          providers: [RoleProvider.plain(state)],
          variants: Variants(
            role: state,
            byProvider: {
              const ModuleId('self'): none,
            },
          ),
        ),
        TestModule(
          'feature',
          variants: Variants(
            role: state,
            byProvider: {
              const ModuleId('blok'): none,
            },
          ),
        ),
      ]);

      expect(
        problems,
        allOf([
          _hasProblem('which has no variants'),
          _hasProblem('variants need a role with at most one'),
          _hasProblem('declares variants but has none'),
          _hasProblem('cannot have variants for it'),
          _hasProblem('variant for blok, which is not a registered provider'),
        ]),
      );
    });
  });

  group('sockets', () {
    test('belong to their owner and have valid names', () {
      final other = TestRole<NoDsl>('other');
      final role = TestRole<NoDsl>(
        'owner',
        sockets: [
          SocketRef<CodeSocket>.role(other, 'code', const CodeSocket()),
          const SocketRef<CodeSocket>.role(
            appEntryRole,
            'Bad Name',
            CodeSocket(),
          ),
        ],
        socketFamilies: [
          SocketFamily<String, CodeSocket>.role(
            other,
            'family',
            const CodeSocket(),
            keyOf: (key) => [key],
          ),
        ],
      );
      final problems = _problems([
        TestModule(
          'a',
          uses: {role},
          sockets: const [
            SocketRef<CodeSocket>.module(ModuleId('b'), 'x', CodeSocket()),
          ],
          socketFamilies: [
            SocketFamily<String, CodeSocket>.module(
              const ModuleId('b'),
              'family',
              const CodeSocket(),
              keyOf: (key) => [key],
            ),
          ],
        ),
      ]);

      expect(
        problems,
        allOf([
          _hasProblem('owner declares the socket other.code'),
          _hasProblem('owner declares the socket app_entry.Bad Name'),
          _hasProblem('declares the socket family family of other'),
          _hasProblem('module a declares the socket b.x'),
          _hasProblem('module a declares the socket family family of b'),
        ]),
      );
    });

    test('have unique tags, also against wrapper tags and families', () {
      final role = TestRole<NoDsl>(
        'owner',
      );
      const wrapper = SocketRef<WrapperSocket>.module(
        ModuleId('a'),
        'wrap',
        WrapperSocket(),
      );
      const clash = SocketRef<CodeSocket>.module(
        ModuleId('a'),
        'wrap_open',
        CodeSocket(),
      );
      const member = SocketRef<CodeSocket>.module(
        ModuleId('a'),
        'fam__x',
        CodeSocket(),
      );
      final problems = _problems([
        TestModule(
          'a',
          uses: {role},
          sockets: [wrapper, clash, member],
          socketFamilies: [
            SocketFamily<String, CodeSocket>.module(
              const ModuleId('a'),
              'fam',
              const CodeSocket(),
              keyOf: (key) => [key],
            ),
            SocketFamily<String, CodeSocket>.module(
              const ModuleId('a'),
              'Fam',
              const CodeSocket(),
              keyOf: (key) => [key],
            ),
            SocketFamily<String, CodeSocket>.module(
              const ModuleId('a'),
              'fam',
              const CodeSocket(),
              keyOf: (key) => [key],
            ),
          ],
        ),
      ]);

      expect(
        problems,
        allOf([
          _hasProblem('have the same tag smf_a__wrap_open'),
          _hasProblem('starts like the members of the socket family a.fam'),
          _hasProblem('"Fam" of a is not lower snake_case'),
          _hasProblem('have overlapping tags'),
        ]),
      );
    });
  });

  group('role options', () {
    test('are kebab-case, unique and not options of the pipeline', () {
      final a = TestRole<NoDsl>(
        'a',
        options: const [
          RoleOption(name: 'Start', help: ''),
          RoleOption(name: 'modules', help: ''),
          RoleOption(name: 'verbose', help: ''),
          RoleOption(name: 'shared', help: ''),
        ],
      );
      final b = TestRole<NoDsl>(
        'b',
        options: const [RoleOption(name: 'shared', help: '')],
      );

      expect(
        _problems([
          TestModule('m', uses: {a, b}),
        ]),
        allOf([
          _hasProblem('--Start of the a is not lower kebab-case'),
          _hasProblem('--modules of the a is an option of the pipeline'),
          _hasProblem('--verbose of the a is an option of the pipeline'),
          _hasProblem('The a and the b both have the option --shared'),
        ]),
      );
    });
  });

  test('role options need a template and must not start with no-', () {
    final role = TestRole<NoDsl>(
      'a',
      options: const [RoleOption(name: 'no-input', help: '')],
    );

    expect(
      _problems([
        TestModule('m', uses: {role}),
      ]),
      allOf(
        _hasProblem('starts with no-, which negates its flags'),
        _hasProblem('has the option --no-input but no template'),
      ),
    );
  });

  test('two different kinds must not share an id', () {
    expect(
      _problems([
        TestModule('a', kind: const ModuleKind(id: 'same', label: 'A')),
        TestModule('b', kind: const ModuleKind(id: 'same', label: 'B')),
      ]),
      _hasProblem('Two different module kinds have the id same'),
    );
  });

  test('a role every app needs must have a provider', () {
    expect(
      _problems([
        TestModule('home', uses: {appEntryRole}),
      ]),
      _hasProblem('Every app needs the app_entry, but no module provides it'),
    );
  });

  test('the built-in roles pass', () {
    expect(
      _problems([
        scaffold(),
        TestModule(
          'home',
          kind: ModuleKinds.feature,
          requires: {diRole, stateManagementRole},
          uses: {analyticsRole, crashReportingRole, eventsRole},
        ),
      ]),
      isEmpty,
    );
  });
}
