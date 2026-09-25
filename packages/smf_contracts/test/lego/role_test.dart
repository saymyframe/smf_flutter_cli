import 'package:smf_contracts/lego_core.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A template that records the input of each hook.
final class _RecordingTemplate extends RoleTemplate<String> {
  RoleHookInput<String>? validated;
  RoleChoiceContext<String>? chosen;
  RoleHookInput<String>? rendered;

  @override
  List<SmfIssue> validate(RoleHookInput<String> input) {
    validated = input;
    return [SmfIssue('checked ${input.data.length}')];
  }

  @override
  Future<Object?> choose(RoleChoiceContext<String> context) async {
    chosen = context;
    return context.option('start') ?? context.data.first.value;
  }

  @override
  RoleOutput render(RoleHookInput<String> input) {
    rendered = input;
    return RoleOutput(vars: {'choice': input.choice});
  }
}

final class _Provider extends RoleProvider<String> {
  _Provider(this.role);

  @override
  final Role<String> role;

  @override
  List<SmfIssue> validate(RoleHookInput<String> input) =>
      [for (final data in input.data) SmfIssue(data.value)];
}

final class _PlainTemplate extends RoleTemplate<String> {
  const _PlainTemplate();
}

void main() {
  test('RoleCardinality says whether none or many are allowed', () {
    expect(RoleCardinality.exactlyOne.allowsNone, isFalse);
    expect(RoleCardinality.exactlyOne.allowsMany, isFalse);
    expect(RoleCardinality.atMostOne.allowsNone, isTrue);
    expect(RoleCardinality.atMostOne.allowsMany, isFalse);
    expect(RoleCardinality.many.allowsNone, isTrue);
    expect(RoleCardinality.many.allowsMany, isTrue);
  });

  group('Role defaults', () {
    const role = MinimalRole();

    test('a role has no relations, sockets, options, template or rules', () {
      expect(role.requires, isEmpty);
      expect(role.uses, isEmpty);
      expect(role.visibleRoles, isEmpty);
      expect(role.sockets, isEmpty);
      expect(role.socketFamilies, isEmpty);
      expect(role.interface.files, isEmpty);
      expect(role.interface.symbols, isEmpty);
      expect(role.options, isEmpty);
      expect(role.template, isNull);
      expect(role.moduleRules, isEmpty);
      expect(role.structuralRules, isEmpty);
      expect(role.openToAllModules, isFalse);
    });

    test('names its presence flag and itself', () {
      expect(role.presenceFlag, 'has_minimal');
      expect('$role', 'role minimal');
    });
  });

  group('Role data', () {
    final role = TestRole<String>('router');

    test('accepts values of its data type only', () {
      expect(role.accepts('routes'), isTrue);
      expect(role.accepts(1), isFalse);
      expect(role.accepts(null), isFalse);
      expect(const MinimalRole().accepts(Object()), isFalse);
    });

    test('creates typed data', () {
      final data = role.data('routes', when: {role});

      expect(data, isA<RoleData<String>>());
      expect(data.role, same(role));
      expect(data.when, {role});
    });
  });

  group('Role.hookInput', () {
    final layout = TestRole<int>('layout');
    final di = TestRole<double>('di');
    final hidden = TestRole<String>('hidden');
    final template = _RecordingTemplate();
    final router = TestRole<String>(
      'router',
      uses: {layout},
      requires: {di},
      template: template,
    );

    const home = ModuleOrigin(ModuleId('home'));
    const settings = ModuleOrigin(ModuleId('settings'));
    final request = RoleHookRequest(
      data: [
        RoleData<String>(router, 'home routes').withOrigin(home),
        RoleData<int>(layout, 5).withOrigin(home),
        RoleData<String>(hidden, 'secret').withOrigin(home),
        RoleData<String>(router, 'settings routes').withOrigin(settings),
        RoleData<double>(di, 1.5).withOrigin(settings),
      ],
      presentRoles: {router, di, hidden},
      context: testContext,
      choices: {router: '/home'},
    );

    test('gives a role its own data, typed and in order', () {
      final input = router.hookInput(request);

      expect(input.role, same(router));
      expect(input.data.map((data) => data.value), [
        'home routes',
        'settings routes',
      ]);
      expect(input.data.map((data) => data.origin), [home, settings]);
      expect(input.choice, '/home');
      expect(input.context, same(testContext));
      expect(input.appIdentity, same(testContext.appIdentity));
      expect(() => input.data.add(input.data.first), throwsUnsupportedError);
    });

    test('lets a role read the data of roles it requires or uses', () {
      final input = router.hookInput(request);

      expect(di.dataIn(input).single.value, 1.5);
      expect(router.dataIn(input), hasLength(2));
      expect(
        layout.dataIn(input),
        isEmpty,
        reason: 'the data of an absent role does not apply',
      );
      expect(
        layout
            .dataIn(
              router.hookInput(
                RoleHookRequest(
                  data: request.data,
                  presentRoles: {router, di, layout},
                  context: testContext,
                ),
              ),
            )
            .single
            .value,
        5,
      );
      expect(
        () => hidden.dataIn(input),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            contains('neither requires nor uses the role hidden'),
          ),
        ),
      );
    });

    test('lets a role check the presence of roles it requires or uses', () {
      final input = router.hookInput(request);

      expect(input.has(router), isTrue);
      expect(input.has(di), isTrue);
      expect(input.has(layout), isFalse);
      expect(() => input.has(hidden), throwsArgumentError);
    });

    test('keeps its runtime type when the pipeline holds an untyped role', () {
      // The pipeline knows roles only as Role<Object>; the input must still
      // be a RoleHookInput<String> for the template's typed hook.
      final Role untyped = router;
      final issues = untyped.template!.validate(untyped.hookInput(request));

      expect(issues.single.message, 'checked 2');
      expect(template.validated, isA<RoleHookInput<String>>());

      final output = untyped.template!.render(untyped.hookInput(request));
      expect(output.vars, {'choice': '/home'});
    });

    test('passes the input to a provider of the role', () {
      final RoleProvider provider = _Provider(router);
      final issues = provider.validate(provider.role.hookInput(request));

      expect(issues.map((issue) => issue.message), [
        'home routes',
        'settings routes',
      ]);
    });

    test('leaves out data whose when roles are absent', () {
      final conditional = RoleHookRequest(
        data: [
          RoleData<String>(router, 'always'),
          RoleData<String>(router, 'with layout', when: {layout}),
          RoleData<double>(di, 2.5, when: {layout}),
        ],
        presentRoles: {router, di},
        context: testContext,
      );
      final input = router.hookInput(conditional);

      expect(input.data.map((data) => data.value), ['always']);
      expect(di.dataIn(input), isEmpty);
    });

    test('rejects data of another type and names the contributor', () {
      // Role<String> is a Role<Object>, so data of the wrong type compiles.
      final wrong = RoleHookRequest(
        data: [RoleData<Object>(router, 42).withOrigin(home)],
        presentRoles: {router},
        context: testContext,
      );

      expect(
        () => router.hookInput(wrong),
        throwsA(
          isA<ArgumentError>().having(
            (e) => e.message,
            'message',
            'home contributed a int to the role router, which takes String',
          ),
        ),
      );
    });

    test('retypes data created with a wider type argument', () {
      final widened = RoleHookRequest(
        data: [
          RoleData<Object>(router, 'routes', when: {di}).withOrigin(home),
          RoleData<Object>(router, 'plain'),
        ],
        presentRoles: {router, di},
        context: testContext,
      );

      final data = router.hookInput(widened).data;
      expect(data.first, isA<RoleData<String>>());
      expect(data.first.origin, home);
      expect(data.first.when, {di});
      expect(data.last.origin, isNull);
    });
  });

  group('Role.choiceContext', () {
    final template = _RecordingTemplate();
    final router = TestRole<String>(
      'router',
      options: const [RoleOption(name: 'start', help: 'The start route.')],
      template: template,
    );
    final other = TestRole<String>('other');
    final environment = FakeEnvironment(interactive: true);

    RoleChoiceRequest request(String? start) => RoleChoiceRequest(
          data: [
            RoleData<String>(router, '/home'),
            RoleData<String>(router, '/absent', when: {other}),
            RoleData<String>(other, '/other'),
          ],
          presentRoles: {router},
          optionValues: {'start': start, 'unrelated': 'x'},
          environment: environment,
          context: testContext,
        );

    test('gives the hook its data, options and environment', () async {
      final Role untyped = router;
      final choice =
          await untyped.template!.choose(untyped.choiceContext(request(null)));

      expect(choice, '/home');
      final context = template.chosen!;
      expect(context.role, same(router));
      expect(context.data.map((data) => data.value), ['/home']);
      expect(context.environment, same(environment));
      expect(context.context, same(testContext));
    });

    test('reads the values of the role options only', () async {
      final context = router.choiceContext(request('/settings'));

      expect(context.option('start'), '/settings');
      expect(await router.template!.choose(context), '/settings');
      expect(() => context.option('unrelated'), throwsArgumentError);
    });
  });

  group('RoleTemplate and RoleProvider defaults', () {
    final role = TestRole<String>('router');
    final input = role.hookInput(
      RoleHookRequest(
        data: const [],
        presentRoles: {role},
        context: testContext,
      ),
    );

    test('a template contributes, checks, chooses and renders nothing',
        () async {
      const template = _PlainTemplate();

      expect(template.contribute(testContext), isEmpty);
      expect(template.validate(input), isEmpty);
      expect(
        await template.choose(
          role.choiceContext(
            RoleChoiceRequest(
              data: const [],
              presentRoles: {role},
              optionValues: const {},
              environment: FakeEnvironment(),
              context: testContext,
            ),
          ),
        ),
        isNull,
      );
      final output = template.render(input);
      expect(output.fragments, isEmpty);
      expect(output.vars, isEmpty);
    });

    test('a plain provider only names its role', () {
      final provider = RoleProvider<String>.plain(role);

      expect(provider.role, same(role));
      expect(provider.validate(input), isEmpty);
      expect(provider.render(input).fragments, isEmpty);
    });
  });

  test('RoleOption describes a command line option', () {
    const option = RoleOption(
      name: 'start',
      help: 'The start route.',
      valueHelp: 'path',
      allowed: ['/home'],
    );

    expect(option.name, 'start');
    expect(option.help, 'The start route.');
    expect(option.valueHelp, 'path');
    expect(option.allowed, ['/home']);
  });

  test('RoleInterface checks the required symbols of a provider', () {
    const interface = RoleInterface(
      files: ['lib/core/router/app_router.dart'],
      symbols: [
        RequiredFunction('createAppRouter', path: 'lib/router.dart'),
      ],
    );

    expect(interface.files, ['lib/core/router/app_router.dart']);
    expect(
      interface.checkSymbols(const {
        'lib/router.dart': DartFileIndex(
          path: 'lib/router.dart',
          declarations: [
            IndexedDeclaration(
              name: 'createAppRouter',
              kind: DeclarationKind.function,
            ),
          ],
        ),
      }),
      isEmpty,
    );
    expect(interface.checkSymbols(const {}), hasLength(1));
  });
}
