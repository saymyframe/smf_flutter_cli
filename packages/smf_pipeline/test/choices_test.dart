import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  test('runs choose of every present template with its options', () async {
    final template = TestTemplate<String>(choice: 'picked');
    final chooser = TestRole<String>(
      'chooser',
      template: template,
      options: const [
        RoleOption(name: 'start', help: ''),
        RoleOption(name: 'other', help: ''),
      ],
    );
    final absent = TestRole<String>(
      'absent',
      template: TestTemplate(),
      options: const [RoleOption(name: 'ignored', help: '')],
    );
    final plain = TestRole<String>('plain');
    final modules = [
      TestModule(
        'home',
        uses: {chooser, absent},
        contributions: [chooser.data('route')],
      ),
      TestModule(
        'prov',
        providers: [RoleProvider.plain(chooser), RoleProvider.plain(plain)],
      ),
    ];
    final resolution = resolutionOf(modules);
    final host = FakeHost(terminal: true);
    final reported = <(Role, Object?)>[];

    final (:choices, :issues) = await chooseRoles(
      registry: ModuleRegistry(modules),
      resolution: resolution,
      collection: collect(resolution, testContext),
      optionValues: const {'start': '/home', 'ignored': 'x'},
      environment: host.environment(),
      context: testContext,
      onChoice: (role, choice) => reported.add((role, choice)),
    );

    expect(choices, {chooser: 'picked'});
    // Each choice as it is made; the roles without a template make none.
    expect(reported, [(chooser, 'picked')]);
    final context = template.chosen.single;
    expect(context.option('start'), '/home');
    expect(context.option('other'), isNull);
    expect(() => context.option('ignored'), throwsArgumentError);
    expect(context.data.single.value, 'route');
    expect(context.environment.interactive, isTrue);
    expect(context.context, same(testContext));
    // An option of a role that the app lacks is a warning about the app,
    // which the pipeline reports.
    expect(
      [for (final issue in issues) '$issue'],
      [
        equals(
          'warning pipeline.unused_option: --ignored has no effect: no module '
          'of the app provides the absent role.',
        ),
      ],
    );
    expect(host.logger.warnings, isEmpty);
  });

  test(
      'returns the warnings that the templates report, each of its template '
      'unless it names its own origin, and an error of the template for a '
      'code of another role', () async {
    final first = TestRole<String>(
      'first',
      template: TestTemplate(
        choice: 1,
        warnings: const [
          SmfIssue.warning('One.', code: 'first.one', hint: 'Fix it.'),
          SmfIssue.warning(
            'Of home.',
            code: 'first.of_home',
            origin: ModuleOrigin(ModuleId('home')),
            path: 'lib/home.dart',
          ),
        ],
      ),
    );
    final second = TestRole<String>(
      'second',
      template: TestTemplate(
        choice: 2,
        warnings: const [
          SmfIssue.warning('Borrowed.', code: 'first.one'),
          SmfIssue.warning('Bare.', code: 'second'),
        ],
      ),
    );
    final modules = [
      TestModule('home', uses: {first, second}),
      TestModule(
        'prov',
        providers: [RoleProvider.plain(first), RoleProvider.plain(second)],
      ),
    ];
    final resolution = resolutionOf(modules);
    final host = FakeHost();

    final (:choices, :issues) = await chooseRoles(
      registry: ModuleRegistry(modules),
      resolution: resolution,
      collection: collect(resolution, testContext),
      optionValues: const {},
      environment: host.environment(),
      context: testContext,
    );

    // The warnings do not keep the roles from choosing.
    expect(choices, {first: 1, second: 2});
    const code = 'A code of the second role is second.<name>, with a name in '
        'lower snake_case.';
    expect(
      [for (final issue in issues) '$issue'],
      [
        'warning [role:first] first.one: One. (Fix it.)',
        'warning [home] first.of_home lib/home.dart: Of home.',
        equals(
          'error [role:second]: The template of the second role reported a '
          'warning with the code "first.one", which is not a code of the '
          'second role: Borrowed. ($code)',
        ),
        equals(
          'error [role:second]: The template of the second role reported a '
          'warning with the code "second", which is not a code of the '
          'second role: Bare. ($code)',
        ),
      ],
    );
    expect(host.logger.warnings, isEmpty);
  });

  test(
      'reports the issues of the hooks before a hook that stops generation '
      'through the logger, since the caller gets none', () async {
    for (final (stopping, stops) in [
      (_Refusing(), isA<SmfUsageException>()),
      (_Failing(), isA<GenerationFailedException>()),
    ]) {
      final first = TestRole<String>(
        'first',
        template: TestTemplate(
          warnings: const [
            SmfIssue.warning('One.', code: 'first.one'),
            SmfIssue.warning('Borrowed.', code: 'other.code'),
          ],
        ),
      );
      final last = TestRole<String>('last', template: stopping);
      final absent = TestRole<String>(
        'absent',
        template: TestTemplate(),
        options: const [RoleOption(name: 'ignored', help: '')],
      );
      final modules = [
        TestModule('home', uses: {absent}),
        TestModule(
          'prov',
          providers: [RoleProvider.plain(first), RoleProvider.plain(last)],
        ),
      ];
      final resolution = resolutionOf(modules);
      final host = FakeHost();

      await expectLater(
        chooseRoles(
          registry: ModuleRegistry(modules),
          resolution: resolution,
          collection: collect(resolution, testContext),
          optionValues: const {'ignored': 'x'},
          environment: host.environment(),
          context: testContext,
        ),
        throwsA(stops),
      );
      expect(host.logger.warnings, [
        equals(
          '--ignored has no effect: no module of the app provides the absent '
          'role.',
        ),
        '[role:first]: One.',
      ]);
      expect(host.logger.errors, [
        startsWith(
          '[role:first]: The template of the first role reported a warning '
          'with the code "other.code"',
        ),
      ]);
    }
  });

  test('a template that fails to choose stops generation', () async {
    final failing = TestRole<String>('failing', template: _Failing());
    final modules = [
      TestModule('prov', providers: [RoleProvider.plain(failing)]),
    ];
    final resolution = resolutionOf(modules);

    await expectLater(
      chooseRoles(
        registry: ModuleRegistry(modules),
        resolution: resolution,
        collection: collect(resolution, testContext),
        optionValues: const {},
        environment: FakeHost().environment(),
        context: testContext,
      ),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          'The template of the failing role failed to choose: Bad state: no',
        ),
      ),
    );
  });

  test('a template whose question the user cancels cancels the run', () async {
    final asking = TestRole<String>('asking', template: _Asking());
    final modules = [
      TestModule('prov', providers: [RoleProvider.plain(asking)]),
    ];
    final resolution = resolutionOf(modules);

    await expectLater(
      chooseRoles(
        registry: ModuleRegistry(modules),
        resolution: resolution,
        collection: collect(resolution, testContext),
        optionValues: const {},
        environment: FakeHost(
          terminal: true,
          answers: [const SmfCancelledException()],
        ).environment(),
        context: testContext,
      ),
      throwsA(isA<SmfCancelledException>()),
    );
  });

  test('the router asks for the start screen or takes --start', () async {
    final modules = [
      TestModule(
        'home',
        requires: {routerRole},
        contributions: [
          routerRole.data(
            const RoutesData([
              Route(
                '/',
                name: 'home',
                screen: ScreenRef(
                  'HomeScreen',
                  import: ImportRef.app('features/home/home_screen.dart'),
                ),
                startCandidate: true,
              ),
              Route(
                '/other',
                name: 'other',
                screen: ScreenRef(
                  'OtherScreen',
                  import: ImportRef.app('features/home/other_screen.dart'),
                ),
                startCandidate: true,
              ),
            ]),
          ),
        ],
      ),
      TestModule(
        'go',
        providers: [const RoleProvider.plain(routerRole)],
      ),
    ];
    final resolution = resolutionOf(modules);
    Future<Map<Role, Object?>> choose(
      FakeHost host,
      Map<String, String?> options,
    ) async =>
        (await chooseRoles(
          registry: ModuleRegistry(modules),
          resolution: resolution,
          collection: collect(resolution, testContext),
          optionValues: options,
          environment: host.environment(),
          context: testContext,
        ))
            .choices;

    final given = await choose(FakeHost(), {'start': '/home/other'});
    expect((given[routerRole]! as RouterChoice).startPath, '/home/other');

    final asked = await choose(
      FakeHost(answers: ['/home ('], terminal: true),
      const {},
    );
    expect((asked[routerRole]! as RouterChoice).startPath, '/home');

    expect(
      choose(FakeHost(), const {}),
      throwsA(isA<SmfUsageException>()),
    );
  });

  group('conditions of data on what roles chose', () {
    /// A role that chooses [choice], and records the data it got.
    TestRole<String> chooser(String id, String choice) =>
        TestRole<String>(id, template: TestTemplate(choice: choice));

    test(
        'a role chooses after the roles whose choices its data depends on, '
        'with the data whose conditions hold, and the others keep their '
        'order', () async {
      final first = chooser('first', 'a');
      final labels = chooser('labels', 'chosen');
      final clock = chooser('clock', '12');
      final last = chooser('last', 'z');
      final twelve = ChoiceCondition(
        clock,
        'the clock shows 12 hours',
        holdsFor: (choice) => choice == '12',
        withoutRole: false,
      );
      final evening = ChoiceCondition(
        clock,
        'the clock shows the evening',
        holdsFor: (choice) => choice == 'evening',
        withoutRole: false,
      );
      final modules = [
        TestModule(
          'face',
          uses: {labels, clock},
          contributions: [
            labels.data('always'),
            labels.data('noon', whenChosen: {twelve}),
            labels.data('dusk', whenChosen: {evening}),
          ],
        ),
        TestModule(
          'providers',
          providers: [
            for (final role in [first, labels, clock, last])
              RoleProvider.plain(role),
          ],
        ),
      ];
      final resolution = resolutionOf(modules);
      final order = <Role>[];

      final (:choices, :issues) = await chooseRoles(
        registry: ModuleRegistry(modules),
        resolution: resolution,
        collection: collect(resolution, testContext),
        optionValues: const {},
        environment: FakeHost().environment(),
        context: testContext,
        onChoice: (role, choice) => order.add(role),
      );

      expect(order, [first, clock, labels, last]);
      expect(choices, {first: 'a', clock: '12', labels: 'chosen', last: 'z'});
      expect(issues, isEmpty);
      final template = labels.template! as TestTemplate<String>;
      expect(
        template.chosen.single.data.map((data) => data.value),
        ['always', 'noon'],
      );
    });

    test(
        'a condition of a role without a template, or of an absent role, '
        'makes no role wait', () async {
      final labels = chooser('labels', 'chosen');
      final plain = TestRole<String>('plain');
      final absent = chooser('absent', 'x');
      final modules = [
        TestModule(
          'face',
          uses: {labels, plain, absent},
          contributions: [
            labels.data(
              'plain',
              whenChosen: {
                ChoiceCondition(
                  plain,
                  'the plain role chose nothing',
                  holdsFor: (choice) => choice == null,
                  withoutRole: false,
                ),
              },
            ),
            labels.data(
              'absent',
              whenChosen: {
                ChoiceCondition(
                  absent,
                  'the absent role chose',
                  holdsFor: (choice) => true,
                  withoutRole: false,
                ),
              },
            ),
          ],
        ),
        TestModule(
          'providers',
          providers: [RoleProvider.plain(labels), RoleProvider.plain(plain)],
        ),
      ];
      final resolution = resolutionOf(modules);

      final (:choices, :issues) = await chooseRoles(
        registry: ModuleRegistry(modules),
        resolution: resolution,
        collection: collect(resolution, testContext),
        optionValues: const {},
        environment: FakeHost().environment(),
        context: testContext,
      );

      expect(choices, {labels: 'chosen'});
      expect(issues, isEmpty);
      final template = labels.template! as TestTemplate<String>;
      expect(
        template.chosen.single.data.map((data) => data.value),
        ['plain'],
      );
    });

    test('choiceOrder names the roles of a cycle, which chooseRoles refuses',
        () async {
      final a = chooser('a', 'x');
      final b = chooser('b', 'y');
      final c = chooser('c', 'z');
      ChoiceCondition chose(Role role) => ChoiceCondition(
            role,
            'the ${role.id} role chose',
            holdsFor: (choice) => true,
            withoutRole: false,
          );
      final modules = [
        TestModule(
          'face',
          uses: {a, b, c},
          contributions: [
            a.data('of a', whenChosen: {chose(b)}),
            b.data('of b', whenChosen: {chose(a)}),
            // A role that waits for the cycle is not part of it.
            c.data('of c', whenChosen: {chose(a)}),
            // Data of a role with a condition of the role itself, which
            // validation reports, makes the role wait for nothing.
            c.data('of c too', whenChosen: {chose(c)}),
          ],
        ),
        TestModule(
          'providers',
          providers: [
            RoleProvider.plain(c),
            RoleProvider.plain(a),
            RoleProvider.plain(b),
          ],
        ),
      ];
      final resolution = resolutionOf(modules);
      final collection = collect(resolution, testContext);

      final (:order, :cycle) =
          choiceOrder(resolution.presentRoles, collection.roleData);
      expect(order, isEmpty);
      expect(cycle, [a, b, a]);
      final plain = choiceOrder({a, b}, [a.data('of a')]);
      expect(plain.order, [a, b]);
      expect(plain.cycle, isEmpty);

      await expectLater(
        chooseRoles(
          registry: ModuleRegistry(modules),
          resolution: resolution,
          collection: collection,
          optionValues: const {},
          environment: FakeHost().environment(),
          context: testContext,
        ),
        throwsA(
          isA<StateError>().having(
            (e) => e.message,
            'message',
            'The roles cannot choose, because the conditions of their data '
                'form a cycle: a role → b role → a role.',
          ),
        ),
      );
    });
  });
}

final class _Refusing extends RoleTemplate<String> {
  @override
  Future<Object?> choose(RoleChoiceContext<String> context) async =>
      throw const SmfUsageException('Give --last.');
}

final class _Failing extends RoleTemplate<String> {
  @override
  Future<Object?> choose(RoleChoiceContext<String> context) async =>
      throw StateError('no');
}

final class _Asking extends RoleTemplate<String> {
  @override
  Future<Object?> choose(RoleChoiceContext<String> context) =>
      context.environment.prompter.input('Which one?');
}
