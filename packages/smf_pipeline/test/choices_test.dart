import 'package:smf_contracts/lego.dart';
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

    final choices = await chooseRoles(
      registry: ModuleRegistry(modules),
      resolution: resolution,
      collection: collect(resolution, testContext),
      optionValues: const {'start': '/home', 'ignored': 'x'},
      environment: host.environment(),
      context: testContext,
    );

    expect(choices, {chooser: 'picked'});
    final context = template.chosen.single;
    expect(context.option('start'), '/home');
    expect(context.option('other'), isNull);
    expect(() => context.option('ignored'), throwsArgumentError);
    expect(context.data.single.value, 'route');
    expect(context.environment.interactive, isTrue);
    expect(context.context, same(testContext));
    expect(host.logger.warnings, [
      '--ignored has no effect: no module of the app provides the absent.',
    ]);
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
          'The template of the failing failed to choose: Bad state: no',
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
    ) =>
        chooseRoles(
          registry: ModuleRegistry(modules),
          resolution: resolution,
          collection: collect(resolution, testContext),
          optionValues: options,
          environment: host.environment(),
          context: testContext,
        );

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
