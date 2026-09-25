import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A check that writes a temporary file, to see that the run deletes it.
final class _TempFileCheck extends PreflightCheck {
  String? path;

  @override
  String get id => 'temp';

  @override
  String get description => 'Temporary file';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    path = await environment.writeTempFile('probe.sh', 'true');
    return const PreflightPassed();
  }
}

final class _OneTab extends LayoutProvider {
  const _OneTab();

  @override
  int? get maxDestinations => 1;
}

String _screen(String name) =>
    '${name[0].toUpperCase()}${name.substring(1)}Screen';

/// A feature [name] with a start route and the brick of its screen.
TestModule _feature(String name) => TestModule(
      name,
      kind: ModuleKinds.feature,
      contributions: [
        routerRole.data(_routes(name)),
        BrickContribution(
          bundle(
            name,
            files: {
              'lib/features/$name/${name}_screen.dart': '{{{'
                  'smf_router__screen_annotations__${name}__${name}_screen'
                  '}}}\nclass ${_screen(name)} {}\n',
            },
          ),
        ),
      ],
    );

RoutesData _routes(String name) => RoutesData([
      Route(
        '/',
        name: name,
        screen: ScreenRef(
          _screen(name),
          import: ImportRef.app('features/$name/${name}_screen.dart'),
        ),
        destination: Destination(
          label: name,
          icon: const Fragment('Icons.home'),
        ),
        startCandidate: name == 'home',
      ),
    ]);

void main() {
  final nav = TestRole<String>(
    'nav',
    options: const [RoleOption(name: 'start', help: 'Start')],
    template: TestTemplate(choice: 'the start'),
  );

  CreatePipeline pipeline(List<SmfModule> modules, FakeHost host) =>
      CreatePipeline(registry: ModuleRegistry(modules), host: host.host);

  CreateRequest request(
    List<String> modules, {
    bool strict = false,
    bool explain = false,
  }) =>
      CreateRequest(
        appName: 'my_app',
        modules: [for (final id in modules) ModuleId(id)],
        strict: strict,
        explain: explain,
        roleOptions: const {'start': '/home'},
      );

  test('plans an app', () async {
    final host = FakeHost();
    final modules = [
      scaffold(),
      TestModule('home', requires: {nav}, contributions: [nav.data('/home')]),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
    ];

    final plan = (await pipeline(modules, host).plan(request(['home'])))!;

    expect(plan.context.appName, 'my_app');
    expect(plan.selection.target.path, '/work/my_app');
    expect(
      plan.resolution.modules.map((m) => m.id.value),
      ['home', 'scaffold', 'go'],
    );
    expect(plan.choices, {nav: 'the start'});
    expect(plan.environment.sdk!.flutter, '/sdk/bin/flutter');
    expect(plan.environment.interactive, isFalse);
    expect(plan.preflight.results.single.passed, isTrue);
    expect(plan.leftOut, isEmpty);
    expect(plan.collection.roleData.single.value, '/home');
    // The base value of the minimum iOS version, from the scaffold.
    expect(plan.socketOrders.keys, [AppEntryRole.iosDeploymentTarget]);
    expect(plan.postGenOrder.contributions, isEmpty);
    expect(plan.pubspec.dependencies, isEmpty);
    expect(plan.request.appName, 'my_app');
    await plan.environment.dispose();
  });

  group('lenient mode', () {
    final bad = TestModule(
      'bad',
      contributions: [
        CodegenRequest(when: {nav}),
      ],
    );

    test('leaves out modules at fault and their dependents', () async {
      final host = FakeHost();
      final modules = [
        scaffold(),
        bad,
        TestModule('child', dependsOn: {'bad'}),
        TestModule('fine'),
      ];

      final plan =
          (await pipeline(modules, host).plan(request(['child', 'fine'])))!;

      expect(
        plan.resolution.modules.map((m) => m.id.value),
        ['fine', 'scaffold'],
      );
      expect(plan.leftOut.map((l) => '${l.module}'), ['bad', 'child']);
      expect(plan.leftOut.last.reason, contains('depends on bad'));
      expect(host.logger.warnings, [
        startsWith('Leaving out bad: bad lists the nav'),
        'Leaving out child: child depends on bad, which was left out.',
      ]);
    });

    test('leaves out a module whose required check fails', () async {
      final host = FakeHost();
      final modules = [
        scaffold(),
        TestModule(
          'firebase',
          contributions: [
            Preflight([
              TestCheck(
                'cli',
                status: const PreflightMissing(instructions: 'Install it.'),
                required: true,
              ),
            ]),
          ],
        ),
      ];

      final plan = (await pipeline(modules, host).plan(request(['firebase'])))!;

      expect(plan.leftOut.single.module, const ModuleId('firebase'));
      expect(plan.resolution.modules.single.id, const ModuleId('scaffold'));
    });

    test('leaves out a feature the layout cannot show', () async {
      final host = FakeHost();
      final modules = [
        scaffold(),
        _feature('home'),
        _feature('settings'),
        TestModule(
          'go',
          kind: ModuleKinds.infrastructure,
          providers: [const RoleProvider.plain(routerRole)],
        ),
        TestModule(
          'tabs',
          kind: ModuleKinds.layout,
          providers: [const _OneTab()],
        ),
      ];

      final plan = (await pipeline(modules, host)
          .plan(request(['home', 'settings', 'tabs'])))!;

      expect(plan.leftOut.single.module, const ModuleId('settings'));
      expect(plan.leftOut.single.reason, contains('can show 1'));
      expect(
        (plan.choices[routerRole]! as RouterChoice).startPath,
        '/home',
      );
    });

    test('fails on an error no module caused', () async {
      final modules = [
        scaffold(),
        TestModule('home', requires: {nav}),
        TestModule('go', providers: [RoleProvider.plain(nav)]),
      ];

      expect(
        pipeline(modules, FakeHost(flutter: false)).plan(request(['home'])),
        throwsA(
          isA<GenerationFailedException>()
              .having(
                (e) => e.issues.single.message,
                'issue',
                contains('Flutter SDK is missing'),
              )
              .having((e) => e.message, 'message', contains('an error')),
        ),
      );
    });
  });

  test('a retry of lenient mode asks nothing again', () async {
    final other = TestRole<NoDsl>('other');
    final host = FakeHost(answers: ['go'], terminal: true);
    final modules = [
      scaffold(),
      TestModule('home', requires: {nav}, contributions: [nav.data('/')]),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
      TestModule('auto', providers: [RoleProvider.plain(nav)]),
      TestModule(
        'broken',
        contributions: [
          CodegenRequest(when: {other}),
        ],
      ),
      TestModule('uses_other', uses: {other}),
    ];

    final plan = (await pipeline(modules, host).plan(
      const CreateRequest(
        appName: 'my_app',
        org: 'com.example',
        modules: [ModuleId('home'), ModuleId('broken')],
      ),
    ))!;

    expect(plan.leftOut.single.module, const ModuleId('broken'));
    expect(
      host.prompter.asked.where((p) => p.message.contains('nav')),
      hasLength(1),
    );
    expect(plan.resolution.module(const ModuleId('go')), isNotNull);
    expect(host.prompter.done, isTrue);
  });

  test('strict mode fails on every error', () async {
    final modules = [
      scaffold(),
      TestModule(
        'a',
        contributions: [
          CodegenRequest(when: {nav}),
        ],
      ),
      TestModule(
        'b',
        contributions: [
          CodegenRequest(when: {nav}),
        ],
      ),
    ];

    await expectLater(
      pipeline(modules, FakeHost()).plan(request(['a', 'b'], strict: true)),
      throwsA(
        isA<GenerationFailedException>()
            .having((e) => e.issues, 'issues', hasLength(2))
            .having((e) => e.message, 'message', contains('2 errors'))
            .having((e) => '$e', 'toString', contains('lists the nav')),
      ),
    );
  });

  test('reports each warning once, also in a pass with errors', () async {
    final host = FakeHost();
    final modules = [
      scaffold(),
      TestModule(
        'firebase',
        contributions: [
          Preflight([
            TestCheck(
              'cli',
              status: const PreflightMissing(instructions: 'Install it.'),
            ),
          ]),
        ],
      ),
      TestModule(
        'strict_tool',
        contributions: [
          Preflight([
            TestCheck(
              'sdk',
              status: const PreflightMissing(instructions: 'Get it.'),
              required: true,
            ),
          ]),
        ],
      ),
    ];

    final plan = (await pipeline(modules, host)
        .plan(request(['firebase', 'strict_tool'])))!;

    expect(plan.leftOut.single.module, const ModuleId('strict_tool'));
    expect(
      host.logger.warnings.where((w) => w.contains('Tool cli is missing')),
      hasLength(1),
    );
  });

  test('leaves out a module whose variant is at fault', () async {
    final state = TestRole<NoDsl>('state');
    final host = FakeHost();
    final modules = [
      scaffold(),
      TestModule(
        'home',
        variants: Variants(
          role: state,
          byProvider: {
            const ModuleId('bloc'): (context) => [
                  CodegenRequest(when: {nav}),
                ],
          },
        ),
      ),
      TestModule('bloc', providers: [RoleProvider.plain(state)]),
    ];

    final plan = (await pipeline(modules, host).plan(request(['home'])))!;

    expect(plan.leftOut.single.module, const ModuleId('home'));
  });

  test('warnings do not stop generation', () async {
    final host = FakeHost();
    final modules = [
      scaffold(),
      TestModule(
        'firebase',
        contributions: [
          Preflight([
            TestCheck(
              'cli',
              status: const PreflightMissing(instructions: 'Install it.'),
            ),
          ]),
        ],
      ),
    ];

    final plan = await pipeline(modules, host).plan(request(['firebase']));

    expect(plan, isNotNull);
    expect(host.logger.warnings.single, contains('Tool cli is missing'));
  });

  test('deletes temporary files when generation fails', () async {
    final host = FakeHost(flutter: false);
    final check = _TempFileCheck();
    final modules = [
      scaffold(
        contributions: [
          Preflight([check]),
        ],
      ),
    ];

    await expectLater(
      pipeline(modules, host).plan(request([])),
      throwsA(isA<GenerationFailedException>()),
    );
    expect(host.fileSystem.file(check.path).existsSync(), isFalse);
  });

  group('--explain', () {
    test('prints what would happen and stops without asking', () async {
      final host = FakeHost(terminal: true);
      host.fileSystem
          .file('/work/my_app/pubspec.yaml')
          .createSync(recursive: true);
      final template = TestTemplate<String>(choice: 'never');
      final chooser = TestRole<String>('chooser', template: template);
      final install = TestCheck(
        'cli',
        status: const PreflightMissing(
          instructions: 'Run the installer.',
          installable: true,
        ),
        required: true,
      );
      final modules = [
        scaffold(
          contributions: [
            const SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment('scaffold();'),
            ),
          ],
        ),
        TestModule(
          'core',
          contributions: [
            const SocketContribution.code(
              AppEntryRole.bootstrapPlatform,
              Fragment('core();'),
            ),
            const PostGenStep(ToolRef('a'), ['--flag']),
            const PubspecContribution.hosted('core_lib', '^1.2.0'),
            const PubspecContribution.sdk('flutter_test', dev: true),
            const CodegenRequest(),
          ],
        ),
        TestModule(
          'analytics',
          dependsOn: {'core'},
          requires: {chooser},
          contributions: [
            const SocketContribution.code(
              AppEntryRole.bootstrapPlatform,
              Fragment('analytics();'),
            ),
            const PostGenStep(ToolRef('b'), []),
            Preflight([install]),
          ],
        ),
        TestModule('prov', providers: [RoleProvider.plain(chooser)]),
        TestModule(
          'bad',
          contributions: [
            CodegenRequest(when: {nav}),
          ],
        ),
      ];

      final plan = await pipeline(modules, host).plan(
        const CreateRequest(
          appName: 'my_app',
          modules: [ModuleId('analytics'), ModuleId('bad')],
          explain: true,
        ),
      );

      expect(plan, isNull);
      expect(host.prompter.asked, isEmpty);
      expect(install.installs, 0);
      expect(template.chosen, isEmpty);
      final report = host.logger.infos.join('\n');
      expect(report, contains('App my_app of com.example'));
      expect(report, contains('Android application id: com.example.my_app'));
      expect(report, contains('iOS bundle id: com.example.my-app'));
      expect(
        report,
        contains('Directory: /work/my_app (exists and is not empty'),
      );
      expect(report, contains('  analytics: requested'));
      expect(report, contains('  core: a dependency of analytics'));
      expect(report, contains('  chooser: prov'));
      expect(report, contains('Left out (lenient mode)\n  bad: bad lists'));
      expect(
        report,
        contains(
          '  socket app_entry.bootstrap_platform: core, analytics\n'
          '    core → analytics (analytics depends on core)',
        ),
      );
      expect(
        report,
        contains('  post-generation steps: core, analytics'),
      );
      expect(
        report,
        contains(
          'Dependencies\n  core_lib ^1.2.0 (core)\n\n'
          'Dev dependencies\n  flutter_test from the flutter SDK (core)',
        ),
      );
      expect(
        report,
        contains(
          'After generation\n'
          '  dart run build_runner build (core)\n'
          '  a --flag (core)\n'
          '  b (analytics)',
        ),
      );
      expect(report, isNot(contains('bootstrap_late')));
      expect(report, contains('  ✓ Flutter SDK'));
      expect(
        report,
        contains(
          '  ✗ Tool cli (for analytics): missing\n'
          '    Run the installer.\n'
          '    An interactive run offers to install it.\n'
          '    Generation would leave out analytics.',
        ),
      );
    });

    test('says when generation would stop', () async {
      final host = FakeHost(flutter: false);
      final modules = [
        scaffold(
          contributions: [
            Preflight([
              TestCheck(
                'broken',
                status: const PreflightFailed('no network'),
                required: true,
              ),
            ]),
          ],
        ),
        TestModule('home'),
      ];

      await pipeline(modules, host).plan(
        const CreateRequest(
          appName: 'my_app',
          modules: [ModuleId('home')],
          explain: true,
          strict: true,
        ),
      );

      final report = host.logger.infos.join('\n');
      expect(report, contains('  ✗ Flutter SDK: missing'));
      expect(report, contains('  home: requested'));
      expect(
        report,
        contains(
          '  ✗ Tool broken (for scaffold): no network\n'
          '    Generation would stop.',
        ),
      );
    });

    test('prints the variant and a cycle', () {
      const order = ContributionOrder(
        contributions: [
          Collected(
            CodegenRequest(),
            ModuleOrigin(ModuleId('a')),
            applies: true,
          ),
          Collected(
            CodegenRequest(),
            ModuleOrigin(ModuleId('b')),
            applies: true,
          ),
        ],
        edges: [],
        cycle: ['a', 'b'],
      );
      final lines = explain(
        selection: const Selection(
          appName: 'app',
          org: 'com.example',
          target: TargetDecision(path: '/app'),
          requested: [],
        ),
        context: testContext,
        resolution: Resolution([
          ResolvedModule(
            TestModule('home'),
            const Requested(),
            variant: const ModuleId('bloc'),
          ),
        ]),
        validation: const ValidationResult(
          issues: [],
          socketOrders: {},
          postGenOrder: order,
          pubspec: MergedPubspec(),
        ),
        preflight: const PreflightReport([], []),
        leftOut: const [],
        strict: false,
      );

      expect(lines, contains('  home: requested, variant for bloc'));
      expect(lines, contains('  Directory: /app'));
      expect(lines, contains('    cycle: a, b'));
      expect(lines, isNot(contains('Roles')));
    });

    test('notes a launcher of flutter and a Flutter too old', () {
      final launched = FlutterSdkCheck(FakeHost().fileSystem, explain: true)
        ..launcher = '/snap/bin/flutter';
      final lines = explain(
        selection: const Selection(
          appName: 'app',
          org: 'com.example',
          target: TargetDecision(path: '/app'),
          requested: [],
        ),
        context: testContext,
        resolution: Resolution(const []),
        validation: const ValidationResult(
          issues: [],
          socketOrders: {},
          postGenOrder: ContributionOrder(contributions: [], edges: []),
          pubspec: MergedPubspec(),
        ),
        preflight: PreflightReport(
          [
            CheckResult(
              PlannedCheck(launched, const PipelineOrigin()),
              const PreflightPassed(),
            ),
          ],
          const [],
        ),
        leftOut: const [],
        strict: false,
        sdkIssues: const [SmfIssue('The app needs Dart ^3.99.0.')],
      );

      const note =
          '    /snap/bin/flutter is a launcher; a run asks it where the SDK is.';
      expect(
        lines,
        containsAllInOrder([
          '  ✓ Flutter SDK',
          note,
          '  ✗ The app needs Dart ^3.99.0.',
        ]),
      );
    });
  });
}
