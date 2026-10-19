import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/src/render.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _OneTab extends LayoutProvider {
  const _OneTab();

  @override
  int? get maxDestinations => 1;
}

/// A provider whose hook of the steps by hand throws.
final class _ThrowingSteps extends RoleProvider<NoDsl> {
  _ThrowingSteps(this.role);

  @override
  final Role<NoDsl> role;

  @override
  List<ManualStep> manualSteps(RoleHookInput<NoDsl> input) =>
      throw StateError('no steps');
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
          label: LocalizedText('label', en: name),
          icon: const Fragment('Icons.home'),
        ),
        startCandidate: name == 'home',
      ),
    ]);

void main() {
  // Its option is not --start, which is the router's: the app entry uses
  // the router, so every registry has it.
  final nav = TestRole<String>(
    'nav',
    options: const [RoleOption(name: 'entry', help: 'Entry')],
    template: TestTemplate(choice: 'the start'),
  );

  CreatePipeline pipeline(
    List<SmfModule> modules,
    FakeHost host, {
    SetupLink? setupLink,
  }) =>
      CreatePipeline(
        registry: ModuleRegistry(modules),
        host: host.host,
        setupLink: setupLink,
      );

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
        roleOptions: const {'entry': '/home'},
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
    // The template of the app entry role makes no choice.
    expect(plan.choices, {nav: 'the start', appEntryRole: null});
    expect(plan.environment.sdk!.flutter, '/sdk/bin/flutter');
    expect(plan.environment.interactive, isFalse);
    expect(plan.preflight.results.single.passed, isTrue);
    expect(plan.leftOut, isEmpty);
    expect(plan.collection.roleData.single.value, '/home');
    // The base value of the minimum iOS version, from the scaffold, and
    // what the template of the app entry role gives every app: its note for
    // coding agents, and the widget for the icons of the status bar.
    expect(plan.socketOrders.keys, [
      AppEntryRole.iosDeploymentTarget,
      AppEntryRole.agentSections,
      AppEntryRole.appBuilder,
    ]);
    expect(plan.postGenOrder.contributions, isEmpty);
    expect(plan.pubspec.dependencies.keys, ['flutter']);
    expect(plan.request.appName, 'my_app');
    await plan.environment.dispose();
  });

  test('plans the steps by hand once, before the roles choose', () async {
    final host = FakeHost();
    final steps = <ManualStep>[];
    final template = TestTemplate<String>(choice: 'chosen', steps: steps);
    final sign = TestRole<String>('sign', template: template);
    steps.add(
      ManualStep(ManualStepId.role(sign, 'app_id'), 'Register the App ID'),
    );
    final modules = [
      scaffold(),
      TestModule(
        'fire',
        providers: [RoleProvider.plain(sign)],
        contributions: const [
          ManualStep(
            ManualStepId(ModuleId('fire'), 'apple'),
            'Turn on Sign in with Apple in Firebase Authentication',
          ),
        ],
      ),
      TestModule('go', providers: [RoleProvider.plain(nav)]),
    ];
    final asked = <List<ManualStepId>>[];

    final plan = (await pipeline(
      modules,
      host,
      setupLink: (steps) {
        asked.add(steps);
        return guideOf(steps);
      },
    ).plan(request(['fire', 'go'])))!;

    expect(plan.choices[sign], 'chosen');
    expect(template.chosen, hasLength(1));
    // The steps depend on no choice, so a run that stops before the
    // choices, as --explain does, has them too.
    expect(template.listed, hasLength(1));
    expect(template.listed.single.choice, isNull);
    final planned = [for (final step in plan.manualSteps) '$step'];
    expect(planned, [
      'sign.app_id: Register the App ID (role:sign)',
      equals(
        'fire.apple: Turn on Sign in with Apple in Firebase Authentication '
        '(fire)',
      ),
    ]);
    // The front end names the guide of the steps once, by their ids.
    expect(asked, [
      [
        ManualStepId.role(sign, 'app_id'),
        const ManualStepId(ModuleId('fire'), 'apple'),
      ],
    ]);
    expect(
      plan.setupLink,
      Uri.parse('https://guide.example/setup?steps=sign.app_id,fire.apple'),
    );
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

    test(
        'leaves out a module whose step by hand breaks a rule, or whose hook '
        'of the steps fails', () async {
      final host = FakeHost();
      final modules = [
        scaffold(),
        TestModule(
          'untitled',
          contributions: const [
            ManualStep(ManualStepId(ModuleId('untitled'), 'key'), ''),
          ],
        ),
        TestModule(
          'fire',
          providers: [_ThrowingSteps(TestRole<NoDsl>('sign'))],
        ),
        TestModule(
          'fine',
          contributions: const [
            ManualStep(ManualStepId(ModuleId('fine'), 'key'), 'Upload a key'),
          ],
        ),
      ];

      final plan = (await pipeline(modules, host, setupLink: guideOf)
          .plan(request(['untitled', 'fire', 'fine'])))!;

      expect(plan.leftOut.map((l) => '${l.module}'), ['untitled', 'fire']);
      expect(host.logger.warnings, [
        startsWith(
          'Leaving out untitled: The title of the step by hand untitled.key '
          'of untitled is blank',
        ),
        equals(
          'Leaving out fire: The hook of fire that lists the steps by hand '
          'failed: Bad state: no steps',
        ),
      ]);
      expect(
        [for (final step in plan.manualSteps) '$step'],
        ['fine.key: Upload a key (fine)'],
      );
      // The link is that of the steps of the app without the modules.
      expect(
        plan.setupLink,
        Uri.parse('https://guide.example/setup?steps=fine.key'),
      );
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

    group('keeps a module that no app can be made without', () {
      /// A required check that fails, which nothing can install.
      TestCheck failing() => TestCheck(
            'tool',
            status: const PreflightMissing(instructions: 'Get the tool.'),
            required: true,
          );

      /// Another provider of the app entry, [id], with the contributions of
      /// the scaffold of the tests.
      TestModule entry(
        String id, {
        Set<String> dependsOn = const {},
        Set<Role> requires = const {},
        List<Contribution> contributions = const [],
      }) =>
          TestModule(
            id,
            kind: ModuleKinds.scaffold,
            dependsOn: dependsOn,
            requires: requires,
            providers: [const RoleProvider.plain(appEntryRole)],
            contributions: [
              entryBrick(),
              fallbackBrick(),
              AppEntryRole.iosDeploymentTarget.value('13.0'),
              const PubspecContribution.environment(sdk: '^3.8.1'),
              const PubspecContribution.sdk('flutter'),
              ...contributions,
            ],
          );

      test(
          'and stops at its problem, with its hint, for a Flutter SDK that is '
          'too old', () async {
        final host = FakeHost();
        host.fileSystem.file('/sdk/bin/cache/flutter.version.json')
          ..createSync(recursive: true)
          ..writeAsStringSync(
            '{"flutterVersion": "3.29.3", "dartSdkVersion": "3.7.2"}',
          );
        final modules = [scaffold(), TestModule('home')];

        await expectLater(
          pipeline(modules, host).plan(request(['home'])),
          throwsA(
            isA<GenerationFailedException>().having(
              (e) => [for (final issue in e.issues) '$issue'],
              'issues',
              // Not "No module provides the app entry role", which leaving
              // out the scaffold would bring, and not to leave it out.
              [
                equals(
                  'error [scaffold]: scaffold needs Dart ^3.8.1, but the '
                  'Flutter SDK at /sdk/bin/flutter has Dart 3.7.2. (Upgrade '
                  'Flutter.)',
                ),
              ],
            ),
          ),
        );
        expect(host.logger.warnings, isEmpty);
      });

      test('and installs nothing for a run that stops so', () async {
        final host = FakeHost(answers: [true], terminal: true);
        host.fileSystem.file('/sdk/bin/cache/flutter.version.json')
          ..createSync(recursive: true)
          ..writeAsStringSync(
            '{"flutterVersion": "3.29.3", "dartSdkVersion": "3.7.2"}',
          );
        final installable = TestCheck(
          'cli',
          status: const PreflightMissing(
            instructions: 'Install it.',
            installable: true,
          ),
          afterInstall: const PreflightPassed(),
        );
        final modules = [
          scaffold(),
          TestModule(
            'firebase',
            contributions: [
              Preflight([installable]),
            ],
          ),
        ];

        await expectLater(
          pipeline(modules, host).plan(
            const CreateRequest(
              appName: 'my_app',
              org: 'com.example',
              modules: [ModuleId('firebase')],
            ),
          ),
          throwsA(
            isA<GenerationFailedException>().having(
              (e) => e.issues.map((issue) => issue.message),
              'issues',
              [startsWith('scaffold needs Dart ^3.8.1')],
            ),
          ),
        );
        // The check of firebase only warns, and is not asked about.
        expect(installable.installs, 0);
        expect(host.prompter.asked, isEmpty);
        expect(host.logger.warnings, [
          '[firebase]: Tool cli is missing. Install it.',
        ]);
      });

      test('and the modules it depends on', () async {
        final host = FakeHost();
        final modules = [
          entry('entry', dependsOn: {'base'}),
          TestModule(
            'base',
            contributions: [
              Preflight([failing()]),
            ],
          ),
          TestModule('home'),
        ];

        await expectLater(
          pipeline(modules, host).plan(request(['home'])),
          throwsA(
            isA<GenerationFailedException>().having(
              (e) => [for (final issue in e.issues) '${issue.origin}'],
              'origins',
              ['base'],
            ),
          ),
        );
        expect(host.logger.warnings, isEmpty);
      });

      test('and the modules it depends on through others', () async {
        final host = FakeHost();
        // In this order, one pass over the registry would not reach entry
        // from base.
        final modules = [
          entry('entry', dependsOn: {'mid'}),
          TestModule('mid', dependsOn: {'base'}),
          TestModule(
            'base',
            contributions: [
              Preflight([failing()]),
            ],
          ),
          TestModule('home'),
        ];

        await expectLater(
          pipeline(modules, host).plan(request(['home'])),
          throwsA(
            isA<GenerationFailedException>().having(
              (e) => [for (final issue in e.issues) '${issue.origin}'],
              'origins',
              ['base'],
            ),
          ),
        );
        expect(host.logger.warnings, isEmpty);
      });

      test('and the only provider of a role it requires', () async {
        final host = FakeHost();
        final tooling = TestRole<NoDsl>('tooling');
        final modules = [
          entry('entry', requires: {tooling}),
          TestModule(
            'maker',
            providers: [RoleProvider.plain(tooling)],
            contributions: [
              Preflight([failing()]),
            ],
          ),
          TestModule('home'),
        ];

        await expectLater(
          pipeline(modules, host).plan(request(['home'])),
          throwsA(
            isA<GenerationFailedException>().having(
              (e) => [for (final issue in e.issues) '${issue.origin}'],
              'origins',
              ['maker'],
            ),
          ),
        );
        expect(host.logger.warnings, isEmpty);
      });

      test('but leaves out a provider that another can replace', () async {
        final host = FakeHost();
        final modules = [
          entry(
            'entry',
            contributions: [
              Preflight([failing()]),
            ],
          ),
          entry('other'),
        ];

        final plan = (await pipeline(modules, host).plan(request(['entry'])))!;

        expect(plan.leftOut.single.module, const ModuleId('entry'));
        expect(
          '${plan.resolution.modules.single.reason}',
          'the only provider of the app entry role, which every app needs',
        );
        await plan.environment.dispose();
      });

      test('once the provider that could replace it is left out', () async {
        final host = FakeHost();
        final modules = [
          entry(
            'entry',
            contributions: [
              Preflight([failing()]),
            ],
          ),
          entry(
            'other',
            contributions: [
              Preflight([failing()]),
            ],
          ),
        ];

        await expectLater(
          pipeline(modules, host).plan(request(['entry'])),
          throwsA(
            isA<GenerationFailedException>().having(
              (e) => [for (final issue in e.issues) '${issue.origin}'],
              'origins',
              ['other'],
            ),
          ),
        );
        // entry was left out while other could replace it; other could not.
        expect(host.logger.warnings, [
          startsWith('Leaving out entry: Tool tool is missing.'),
        ]);
      });

      test('and says that an app has only one provider of such a role', () {
        final host = FakeHost();
        final modules = [entry('entry'), entry('other')];

        expect(
          pipeline(modules, host).plan(request(['entry', 'other'])),
          throwsA(
            isA<SmfUsageException>().having(
              (e) => e.message,
              'message',
              'An app can have only one provider of the app entry role, but '
                  'it has entry (requested) and other (requested). Keep one '
                  'of them.',
            ),
          ),
        );
      });

      test('and --explain says so for a Flutter SDK that is too old', () async {
        final host = FakeHost();
        host.fileSystem.file('/sdk/bin/cache/flutter.version.json')
          ..createSync(recursive: true)
          ..writeAsStringSync(
            '{"flutterVersion": "3.29.3", "dartSdkVersion": "3.7.2"}',
          );
        final modules = [
          scaffold(),
          TestModule(
            'home',
            contributions: const [
              PubspecContribution.environment(flutter: '>=3.32.0'),
            ],
          ),
        ];

        await pipeline(modules, host).plan(request(['home'], explain: true));

        final report = host.logger.infos.join('\n');
        expect(
          report,
          contains(
            '  ✗ scaffold needs Dart ^3.8.1, but the Flutter SDK at '
            '/sdk/bin/flutter has Dart 3.7.2.\n'
            '    Upgrade Flutter.\n'
            '    Generation would stop.',
          ),
        );
        // A module that an app can do without would be left out.
        expect(
          report,
          contains(
            '  ✗ home needs Flutter >=3.32.0, but the Flutter SDK at '
            '/sdk/bin/flutter has Flutter 3.29.3.\n'
            '    Upgrade Flutter, or leave out home.\n'
            '    Generation would leave out home.',
          ),
        );
      });

      test('and --explain says that generation would stop', () async {
        final host = FakeHost();
        final modules = [
          scaffold(
            contributions: [
              Preflight([failing()]),
            ],
          ),
          TestModule(
            'home',
            contributions: [
              Preflight([
                TestCheck(
                  'cli',
                  status: const PreflightMissing(instructions: 'Get it.'),
                  required: true,
                ),
              ]),
            ],
          ),
        ];

        await pipeline(modules, host).plan(request(['home'], explain: true));

        final report = host.logger.infos.join('\n');
        expect(
          report,
          contains(
            '  ✗ Tool tool (for scaffold): missing\n'
            '    Get the tool.\n'
            '    Generation would stop.',
          ),
        );
        expect(
          report,
          contains(
            '  ✗ Tool cli (for home): missing\n'
            '    Get it.\n'
            '    Generation would leave out home.',
          ),
        );
      });
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

  group('a module that generates the guide for coding agents itself', () {
    for (final file in [AppEntryRole.agentsFile, AppEntryRole.claudeFile]) {
      List<SmfModule> modules() => [
            scaffold(),
            TestModule(
              'own_guide',
              contributions: [
                BrickContribution(
                  bundle('own_guide', files: {file: 'My own guide.\n'}),
                ),
              ],
            ),
            TestModule('fine'),
          ];

      test('stops generation in strict mode, as the one at fault: $file',
          () async {
        await expectLater(
          pipeline(modules(), FakeHost())
              .plan(request(['own_guide', 'fine'], strict: true)),
          throwsA(
            isA<GenerationFailedException>().having(
              (e) => [
                for (final issue in e.issues)
                  '${issue.origin}: ${issue.message}',
              ],
              'issues',
              [
                equals(
                  'own_guide: Both own_guide and role:app_entry generate '
                  '$file; every file has one brick.',
                ),
              ],
            ),
          ),
        );
      });

      test('is left out in lenient mode, and the app has the guide: $file',
          () async {
        final host = FakeHost();

        final plan = (await pipeline(modules(), host)
            .plan(request(['own_guide', 'fine'])))!;

        expect(plan.leftOut.single.module, const ModuleId('own_guide'));
        expect(
          plan.leftOut.single.reason,
          'Both own_guide and role:app_entry generate $file; every file has '
          'one brick.',
        );
        expect(
          plan.resolution.modules.map((module) => module.id.value),
          ['fine', 'scaffold'],
        );
      });
    }
  });

  group('a module that contributes a note of a role to the guide', () {
    List<SmfModule> modules() => [
          scaffold(),
          TestModule(
            'as_a_role',
            contributions: [
              AppEntryRole.agentSections.entry(
                'App entry',
                AgentNote.ofRole('What only the role may say.'),
              ),
            ],
          ),
        ];
    const problem = 'The module as_a_role contributes a note of a role to '
        'the section "App entry" of the guide for coding agents. Only the '
        'template of a role says what the role guarantees; a module '
        'contributes AgentNote(text).';

    test('stops generation in strict mode', () async {
      await expectLater(
        pipeline(modules(), FakeHost())
            .plan(request(['as_a_role'], strict: true)),
        throwsA(
          isA<GenerationFailedException>().having(
            (e) => [
              for (final issue in e.issues) '${issue.origin}: ${issue.message}',
            ],
            'issues',
            ['as_a_role: $problem'],
          ),
        ),
      );
    });

    test('is left out in lenient mode', () async {
      final plan =
          (await pipeline(modules(), FakeHost()).plan(request(['as_a_role'])))!;

      expect(plan.leftOut.single.module, const ModuleId('as_a_role'));
      expect(plan.leftOut.single.reason, problem);
    });
  });

  test(
      'renders only the bricks and the data whose conditions on what the '
      'roles chose hold', () async {
    final hours = TestRole<String>(
      'hours',
      options: const [RoleOption(name: 'hours', help: 'Hours')],
      template: _HoursTemplate(),
    );
    final twelve = ChoiceCondition(
      hours,
      'the clock shows 12 hours',
      holdsFor: (choice) => choice == '12',
      withoutRole: false,
    );
    final labelsTemplate = _LabelsTemplate();
    final labels = TestRole<String>('labels', template: labelsTemplate);
    final modules = [
      scaffold(),
      TestModule(
        'face',
        uses: {hours, labels},
        contributions: [
          labels.data('always'),
          labels.data('noon', whenChosen: {twelve}),
          BrickContribution(
            bundle('dial', files: {'lib/dial.dart': 'class Dial {}\n'}),
            whenChosen: {twelve},
          ),
        ],
      ),
      // The labels choose first, unless their data waits for the hours.
      TestModule('tags', providers: [RoleProvider.plain(labels)]),
      TestModule('clock', providers: [RoleProvider.plain(hours)]),
    ];

    Future<(GenerationPlan, RenderedApp)> run(String value) async {
      final plan = (await pipeline(modules, FakeHost()).plan(
        CreateRequest(
          appName: 'my_app',
          modules: const [
            ModuleId('face'),
            ModuleId('tags'),
            ModuleId('clock'),
          ],
          roleOptions: {'hours': value},
        ),
      ))!;
      await plan.environment.dispose();
      final app = renderApp(
        registry: ModuleRegistry(modules),
        resolution: plan.resolution,
        collection: plan.collection,
        context: plan.context,
        choices: plan.choices,
        pubspec: plan.pubspec,
        manualSteps: plan.manualSteps,
      );
      return (plan, app);
    }

    final (twelveHours, withDial) = await run('12');
    expect(twelveHours.choices[hours], '12');
    expect(
      twelveHours.collection.roleData.map((data) => data.value),
      ['always', 'noon'],
    );
    expect(withDial.files['lib/dial.dart']!.text, 'class Dial {}\n');
    expect(
      withDial.files['lib/labels.dart']!.text,
      "const labels = 'always, noon';\n",
    );

    final (twentyFourHours, withoutDial) = await run('24');
    expect(twentyFourHours.choices[hours], '24');
    expect(
      twentyFourHours.collection.roleData.map((data) => data.value),
      ['always'],
    );
    expect(withoutDial.files.containsKey('lib/dial.dart'), isFalse);
    expect(
      withoutDial.files['lib/labels.dart']!.text,
      "const labels = 'always';\n",
    );
    // The choice of the labels read only the data whose conditions held.
    expect(
      [
        for (final context in labelsTemplate.chosen)
          [for (final data in context.data) data.value],
      ],
      [
        ['always', 'noon'],
        ['always'],
      ],
    );
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
    // Without the word warning, which the logger of the CLI adds as
    // [WARN].
    expect(
      host.logger.warnings.single,
      '[firebase]: Tool cli is missing. Install it.',
    );
  });

  group('--strict and the warnings about what the app is made of', () {
    const noStart = SmfIssue.warning(
      'No screen to start on.',
      code: 'watch.no_start',
    );
    const noTabs = SmfIssue.warning(
      'No main navigation.',
      code: 'watch.no_tabs',
    );

    /// A module that provides the role `watch`, whose template reports
    /// [validated] from its validation and [chosen] from its choice, and
    /// that has [check] among its checks of the machine.
    TestModule watcher({
      List<SmfIssue> validated = const [],
      List<SmfIssue> chosen = const [],
      TestCheck? check,
    }) =>
        TestModule(
          'watcher',
          providers: [
            RoleProvider.plain(
              TestRole<String>(
                'watch',
                template: TestTemplate(issues: validated, warnings: chosen),
              ),
            ),
          ],
          contributions: [
            if (check != null) Preflight([check]),
          ],
        );

    /// A run on [host] of the app with [watcher], which generates the app.
    Future<GeneratedApp?> create(
      TestModule watcher,
      FakeHost host, {
      bool strict = false,
      Set<String> allowed = const {},
      bool explain = false,
    }) =>
        pipeline([scaffold(), watcher], host).run(
          CreateRequest(
            appName: 'my_app',
            modules: const [ModuleId('watcher')],
            strict: strict,
            allowedWarnings: allowed,
            explain: explain,
          ),
        );

    /// What a run that stops throws: [message] with [issues].
    Matcher stops(String message, List<String> issues) => throwsA(
          isA<GenerationFailedException>()
              .having((e) => e.message, 'message', message)
              .having(
                (e) => [for (final issue in e.issues) '$issue'],
                'issues',
                issues,
              ),
        );

    const stoppedByOne = 'Generation stopped because of a warning about the '
        'app. Without --strict, the run goes on after it.';
    const noStartLine = 'warning [role:watch] watch.no_start: No screen to '
        'start on.';
    const noTabsLine =
        'warning [role:watch] watch.no_tabs: No main navigation.';

    test(
        'a warning of a validation stops a strict run before the machine is '
        'checked, with the warning, and a run without --strict goes on',
        () async {
      TestCheck tool() => TestCheck(
            'cli',
            status: const PreflightMissing(instructions: 'Install it.'),
            afterInstall: const PreflightPassed(),
          );

      final host = FakeHost(processRunner: RecordingRunner());
      final strictTool = tool();
      await expectLater(
        create(
          watcher(validated: [noStart], check: strictTool),
          host,
          strict: true,
        ),
        stops(stoppedByOne, [noStartLine]),
      );
      // It stopped before the machine was checked, so nothing could be
      // installed, and it printed the warning only as the cause.
      expect(strictTool.checks, 0);
      expect(host.logger.warnings, isEmpty);
      expect(host.fileSystem.directory('/work/my_app').existsSync(), isFalse);

      final lenient = FakeHost(processRunner: RecordingRunner());
      final app = await create(
        watcher(validated: [noStart], check: tool()),
        lenient,
      );
      expect(app?.path, '/work/my_app');
      expect(
        lenient.logger.warnings,
        contains('[role:watch]: No screen to start on.'),
      );
    });

    test(
        'a warning of a choice stops a strict run before the app is '
        'rendered, and a run without --strict goes on', () async {
      final runner = RecordingRunner();
      final host = FakeHost(processRunner: runner);
      await expectLater(
        create(watcher(chosen: [noStart]), host, strict: true),
        stops(stoppedByOne, [noStartLine]),
      );
      expect(
        host.logger.progresses,
        isNot(contains('start: Rendering the app')),
      );
      expect(runner.calls, isEmpty);
      expect(host.fileSystem.directory('/work/my_app').existsSync(), isFalse);

      final lenient = FakeHost(processRunner: RecordingRunner());
      final app = await create(watcher(chosen: [noStart]), lenient);
      expect(app?.path, '/work/my_app');
      expect(
        lenient.logger.warnings,
        ['[role:watch]: No screen to start on.'],
      );
    });

    test(
        'a strict run goes on after a warning whose code --allow-warning '
        'names, which it prints once, and stops on another code', () async {
      final host = FakeHost(processRunner: RecordingRunner());
      final app = await create(
        watcher(validated: [noStart], chosen: [noStart]),
        host,
        strict: true,
        allowed: {'watch.no_start', 'watch.other'},
      );

      expect(app?.path, '/work/my_app');
      expect(host.logger.warnings, ['[role:watch]: No screen to start on.']);

      await expectLater(
        create(
          watcher(validated: [noStart, noTabs]),
          FakeHost(processRunner: RecordingRunner()),
          strict: true,
          allowed: {'watch.no_start'},
        ),
        stops(stoppedByOne, [
          noTabsLine,
        ]),
      );
    });

    test(
        'a strict run tells how many warnings and errors stopped it, all of '
        'which lenient mode reports', () async {
      await expectLater(
        create(
          watcher(validated: [noStart, noTabs]),
          FakeHost(),
          strict: true,
        ),
        stops(
          'Generation stopped because of 2 warnings about the app. Without '
          '--strict, the run goes on after them.',
          [noStartLine, noTabsLine],
        ),
      );

      // An error of the template of a role stops lenient mode too, which
      // reports the warnings.
      const broken = SmfIssue('The data is broken.');
      final validated = watcher(validated: [noStart, broken, noTabs]);
      await expectLater(
        create(validated, FakeHost(), strict: true),
        stops(
          'Generation stopped because of an error and 2 warnings about the '
          'app.',
          [
            noStartLine,
            'error [role:watch]: The data is broken.',
            noTabsLine,
          ],
        ),
      );
      await expectLater(
        create(
          watcher(validated: [noStart, broken, broken, noTabs]),
          FakeHost(),
          strict: true,
          allowed: {'watch.no_tabs'},
        ),
        stops(
          'Generation stopped because of 2 errors and a warning about the '
          'app.',
          [
            noStartLine,
            'error [role:watch]: The data is broken.',
            'error [role:watch]: The data is broken.',
          ],
        ),
      );

      final lenient = FakeHost();
      await expectLater(
        create(validated, lenient),
        stops(
          'Generation stopped because of an error.',
          ['error [role:watch]: The data is broken.'],
        ),
      );
      expect(lenient.logger.warnings, [
        '[role:watch]: No screen to start on.',
        '[role:watch]: No main navigation.',
      ]);
    });

    test(
        'an option of a role that the app lacks stops a strict run before '
        'the machine is checked, since the command line asks for a role that '
        'the app does not have, and --explain tells of it', () async {
      final tool = TestCheck(
        'cli',
        status: const PreflightMissing(instructions: 'Install it.'),
      );
      final modules = [
        scaffold(),
        TestModule('go', providers: [RoleProvider.plain(nav)]),
        TestModule(
          'fine',
          contributions: [
            Preflight([tool]),
          ],
        ),
      ];

      const unused =
          '--entry has no effect: no module of the app provides the nav role.';

      // The request gives --entry, an option of the nav role.
      await expectLater(
        pipeline(modules, FakeHost()).plan(request(['fine'], strict: true)),
        stops(stoppedByOne, ['warning pipeline.unused_option: $unused']),
      );
      // It depends only on the command line and the roles of the app, so
      // the run stops with the validation.
      expect(tool.checks, 0);

      final host = FakeHost();
      final plan = (await pipeline(modules, host).plan(request(['fine'])))!;
      expect(host.logger.warnings, [
        unused,
        '[fine]: Tool cli is missing. Install it.',
      ]);
      await plan.environment.dispose();

      final explained = FakeHost();
      expect(
        await pipeline(modules, explained)
            .plan(request(['fine'], explain: true)),
        isNull,
      );
      expect(explained.logger.warnings, [unused]);
    });

    test('a warning about the machine never stops a strict run', () async {
      final host = FakeHost(processRunner: RecordingRunner());
      final app = await create(
        watcher(
          check: TestCheck(
            'cli',
            status: const PreflightMissing(instructions: 'Install it.'),
          ),
        ),
        host,
        strict: true,
      );

      expect(app?.path, '/work/my_app');
      expect(host.logger.warnings, [
        '[watcher]: Tool cli is missing. Install it.',
      ]);
    });

    test(
        '--explain with --strict stops on a warning of the validation, as on '
        'an error, and without --strict it prints the warning', () async {
      await expectLater(
        create(
          watcher(validated: [noStart]),
          FakeHost(),
          strict: true,
          explain: true,
        ),
        stops(stoppedByOne, [noStartLine]),
      );

      final host = FakeHost();
      expect(
        await create(watcher(validated: [noStart]), host, explain: true),
        isNull,
      );
      expect(host.logger.warnings, ['[role:watch]: No screen to start on.']);
      expect(host.logger.infos, contains('Modules'));
    });
  });

  test(
      'reports the warnings of the choices as warnings of the template of '
      'their role, and stops on one with a code of another role', () async {
    TestModule watcher(List<SmfIssue> warnings) => TestModule(
          'watcher',
          providers: [
            RoleProvider.plain(
              TestRole<String>(
                'watch',
                template: TestTemplate(warnings: warnings),
              ),
            ),
          ],
        );

    final host = FakeHost();
    final warning = watcher(const [
      SmfIssue.warning('No start screen.', code: 'watch.no_start'),
    ]);
    final plan =
        await pipeline([scaffold(), warning], host).plan(request(['watcher']));

    expect(plan, isNotNull);
    // With the role, and without the code.
    expect(host.logger.warnings, ['[role:watch]: No start screen.']);

    final borrowing = watcher(const [
      SmfIssue.warning('Borrowed.', code: 'nav.borrowed'),
    ]);
    await expectLater(
      pipeline([scaffold(), borrowing], FakeHost()).plan(request(['watcher'])),
      throwsA(
        isA<GenerationFailedException>()
            .having(
              (e) => e.message,
              'message',
              'Generation stopped because of an error.',
            )
            .having(
              (e) => '${e.issues.single}',
              'issue',
              'error [role:watch]: The template of the watch role reported a '
                  'warning with the code "nav.borrowed", which is not a code '
                  'of the watch role: Borrowed. (A code of the watch role is '
                  'watch.<name>, with a name in lower snake_case.)',
            ),
      ),
    );
  });

  test('the line of a warning has all of it but the severity and the code', () {
    expect(
      issueLine(
        const SmfIssue.warning(
          'Unused import.',
          code: 'imports.unused',
          hint: 'Remove it.',
          origin: ModuleOrigin(ModuleId('home')),
          path: 'lib/main.dart',
        ),
      ),
      '[home] lib/main.dart: Unused import. (Remove it.)',
    );
    expect(
      issueLine(
        const SmfIssue.warning('Careful.', code: 'a.b', path: 'lib/a.dart'),
      ),
      'lib/a.dart: Careful.',
    );
    expect(
      issueLine(const SmfIssue.warning('Careful.', code: 'a.b', hint: 'Look.')),
      'Careful. (Look.)',
    );
    expect(issueLine(const SmfIssue.machineWarning('Careful.')), 'Careful.');
  });

  test('deletes temporary files when generation fails', () async {
    final host = FakeHost(flutter: false);
    final check = TempFileCheck();
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
      const coreStep = PostGenStepId(ModuleId('core'), 'a');
      const fixStep = PostGenStepId(ModuleId('analytics'), 'fix');
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
            const PostGenStep(ToolRef('a'), ['--flag'], id: coreStep),
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
            // It continues the step of core, which knows nothing of it.
            const PostGenStep(
              ToolRef('fix'),
              ['it', 'in "a b"'],
              id: fixStep,
              followUpOf: coreStep,
              skippable: true,
            ),
            const PostGenStep(
              ToolRef('check'),
              [],
              followUpOf: fixStep,
              hosts: {HostOperatingSystem.macos},
            ),
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
          'Dependencies\n'
          '  core_lib ^1.2.0 (core)\n'
          '  flutter from the flutter SDK (scaffold, role:app_entry)\n\n'
          'Dev dependencies\n'
          // Code generation needs build_runner, which the pipeline adds.
          '  build_runner ^2.10.0 (pipeline)\n'
          '  flutter_test from the flutter SDK (core, role:app_entry)',
        ),
      );
      expect(
        report,
        contains(
          'After generation\n'
          '  dart run build_runner build --force-jit (core)\n'
          '  a --flag (core)\n'
          // The steps that continue a step run once the step above them
          // succeeded, each named with its own module. Quoted for the shell
          // of the host, as the commands for later.
          '    then fix it \'in "a b"\' (analytics)\n'
          '      then check (analytics, on macOS)\n'
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
          '    An interactive run offers to set it up.\n'
          '    Generation would leave out analytics.',
        ),
      );
    });

    test(
        'quotes a step for a shell of the systems it runs on, which may not '
        'be this one', () async {
      final host = FakeHost(operatingSystem: HostOperatingSystem.windows);
      final modules = [
        scaffold(),
        TestModule(
          'core',
          contributions: const [
            PostGenStep(
              ToolRef('tool'),
              ['--platforms=android,ios'],
              id: PostGenStepId(ModuleId('core'), 'tool'),
            ),
            PostGenStep(
              ToolRef('ruby'),
              ['-e', r'puts "$HOME"', 'a b'],
              followUpOf: PostGenStepId(ModuleId('core'), 'tool'),
              hosts: {HostOperatingSystem.macos},
            ),
          ],
        ),
      ];

      await pipeline(modules, host).plan(
        const CreateRequest(
          appName: 'my_app',
          modules: [ModuleId('core')],
          explain: true,
        ),
      );

      expect(
        host.logger.infos.join('\n'),
        contains(
          'After generation\n'
          // PowerShell reads the comma as its own.
          '  tool "--platforms=android,ios" (core)\n'
          // The shell of macOS would expand \$HOME in double quotes.
          '    then ruby -e \'puts "\$HOME"\' \'a b\' (core, on macOS)',
        ),
      );
    });

    test(
        'shows the notice of a step under its command, and tells that a run '
        'asks first', () async {
      const configure = PostGenStepId(ModuleId('core'), 'configure');
      const enable = PostGenStepId(ModuleId('auth'), 'enable');
      final host = FakeHost(terminal: true);
      final modules = [
        scaffold(),
        TestModule(
          'core',
          contributions: const [
            PostGenStep(ToolRef('configure'), [], id: configure),
          ],
        ),
        TestModule(
          'auth',
          dependsOn: {'core'},
          contributions: const [
            // It continues the step of core, and another continues it.
            PostGenStep(
              ToolRef('enable'),
              ['methods'],
              id: enable,
              followUpOf: configure,
              notice: 'The tool also registers a web app in the project.',
              skippable: true,
            ),
            PostGenStep(ToolRef('verify'), [], followUpOf: enable),
            // A step that continues no other.
            PostGenStep(
              ToolRef('report'),
              [],
              notice: 'It sends the names of the modules.',
              skippable: true,
            ),
          ],
        ),
      ];

      await pipeline(modules, host).plan(
        const CreateRequest(
          appName: 'my_app',
          modules: [ModuleId('auth')],
          explain: true,
        ),
      );

      expect(host.prompter.asked, isEmpty);
      expect(
        host.logger.infos.join('\n'),
        contains(
          'After generation\n'
          '  configure (core)\n'
          '    then enable methods (auth)\n'
          '      The tool also registers a web app in the project.\n'
          '      A run asks before it runs this step, and leaves it for later '
          'when it cannot ask.\n'
          '      then verify (auth)\n'
          '  report (auth)\n'
          '    It sends the names of the modules.\n'
          '    A run asks before it runs this step, and leaves it for later '
          'when it cannot ask.\n',
        ),
      );
    });

    test(
        'shows the steps by hand under the link to their guide, between the '
        'steps after generation and the machine', () async {
      const appId = ManualStep(
        ManualStepId.role(appEntryRole, 'ios_app_id'),
        'In Xcode, sign the iOS app with your paid Apple Developer team',
      );
      const key = ManualStepId(ModuleId('core'), 'apns_key');
      final modules = [
        scaffold(),
        TestModule(
          'core',
          contributions: const [
            PostGenStep(ToolRef('configure'), []),
            ManualStep(key, 'Give Firebase your Apple push key (APNs key)'),
            appId,
          ],
        ),
        // It lists the step of the role too, which the app has once.
        TestModule(
          'push',
          dependsOn: {'core'},
          contributions: const [appId],
        ),
      ];
      const explain = CreateRequest(
        appName: 'my_app',
        modules: [ModuleId('push')],
        explain: true,
      );
      const steps =
          '  app_entry.ios_app_id: In Xcode, sign the iOS app with your paid '
          'Apple Developer team (core, push)\n'
          '  core.apns_key: Give Firebase your Apple push key (APNs key) '
          '(core)\n';

      final host = FakeHost();
      final plan =
          await pipeline(modules, host, setupLink: guideOf).plan(explain);

      expect(plan, isNull);
      expect(
        host.logger.infos.join('\n'),
        contains(
          'After generation\n'
          '  configure (core)\n'
          '\n'
          'By hand\n'
          // The steps of roles come first, in the link too.
          '  ${guideOf([appId.id, key])}\n'
          '$steps'
          '\n'
          'Machine\n',
        ),
      );

      // A front end that names no page shows the steps alone.
      final unlinked = FakeHost();
      await pipeline(modules, unlinked).plan(explain);
      expect(
        unlinked.logger.infos.join('\n'),
        contains('  configure (core)\n\nBy hand\n$steps\nMachine\n'),
      );
    });

    test('shows no steps by hand for an app without any', () async {
      final host = FakeHost();
      final asked = <List<ManualStepId>>[];

      await pipeline(
        [scaffold(), TestModule('core')],
        host,
        setupLink: (steps) {
          asked.add(steps);
          return guideOf(steps);
        },
      ).plan(
        const CreateRequest(
          appName: 'my_app',
          modules: [ModuleId('core')],
          explain: true,
        ),
      );

      final report = host.logger.infos.join('\n');
      expect(report, contains('Machine'));
      expect(report, isNot(contains('By hand')));
      expect(asked, isEmpty);
    });

    test('says when generation would stop', () async {
      final host = FakeHost(flutter: false);
      final modules = [
        scaffold(
          contributions: [
            Preflight([
              TestCheck(
                'broken',
                status: const PreflightFailed(
                  '"tool --list" exited with code 2:\nno network',
                ),
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
      // It could not tell, which differs from a missing tool, and the
      // lines of the reason stay under the check.
      expect(
        report,
        contains(
          '  ✗ Tool broken (for scaffold) could not be checked: "tool --list" '
          'exited with code 2:\n'
          '    no network\n'
          '    Generation would stop.',
        ),
      );
    });

    test('says what a check found in place of what it looks for', () async {
      final host = FakeHost();
      final modules = [
        scaffold(),
        TestModule(
          'home',
          contributions: [
            Preflight([
              TestCheck(
                'cli',
                status: const PreflightMissing(
                  found: 'cli 1.0.0 is active',
                  instructions: 'Activate 2.0.0 in its place.',
                  installable: true,
                ),
              ),
            ]),
          ],
        ),
      ];

      await pipeline(modules, host).plan(
        const CreateRequest(
          appName: 'my_app',
          modules: [ModuleId('home')],
          explain: true,
        ),
      );

      expect(
        host.logger.infos.join('\n'),
        contains(
          '  ✗ Tool cli (for home): cli 1.0.0 is active\n'
          '    Activate 2.0.0 in its place.\n'
          '    An interactive run offers to set it up.',
        ),
      );
    });

    test('lists no order for a socket that does not follow the order edges',
        () async {
      final host = FakeHost();
      List<Contribution> both(String name) => [
            AppEntryRole.agentSections.entry(name, AgentNote('The $name.')),
            SocketContribution.code(
              AppEntryRole.bootstrapLate,
              Fragment('$name();'),
            ),
          ];
      final modules = [
        scaffold(contributions: both('scaffold')),
        TestModule('home', contributions: both('home')),
      ];

      await pipeline(modules, host).plan(
        const CreateRequest(
          appName: 'my_app',
          modules: [ModuleId('home')],
          explain: true,
        ),
      );

      // The start-up code runs in the order of its contributors. The notes
      // of the guide for coding agents are ordered by the renderer of their
      // socket, so the report has no order to tell.
      final report = host.logger.infos.join('\n');
      expect(
        report,
        contains('  socket app_entry.bootstrap_late: home, scaffold'),
      );
      expect(report, isNot(contains('app_entry.agent_sections')));
    });

    test('prints the variant and a cycle', () {
      const order = ContributionOrder(
        contributions: [
          Collected(
            PostGenStep(ToolRef('a'), []),
            ModuleOrigin(ModuleId('a')),
            applies: true,
          ),
          Collected(
            PostGenStep(ToolRef('b'), []),
            ModuleOrigin(ModuleId('b')),
            applies: true,
          ),
        ],
        edges: [],
        cycle: ['a', 'b'],
      );
      final lines = Explanation(
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
        canDoWithout: (_) => true,
        operatingSystem: HostOperatingSystem.linux,
      ).lines;

      expect(lines, contains('  home: requested, variant for bloc'));
      expect(lines, contains('  Directory: /app'));
      expect(lines, contains('    cycle: a, b'));
      expect(lines, isNot(contains('Roles')));
    });

    test('notes a launcher of flutter and a Flutter too old', () {
      final launched = FlutterSdkCheck(FakeHost().fileSystem, explain: true)
        ..launcher = '/snap/bin/flutter';
      final lines = Explanation(
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
        canDoWithout: (_) => true,
        operatingSystem: HostOperatingSystem.linux,
        sdkIssues: const [SmfIssue('The app needs Dart ^3.99.0.')],
      ).lines;

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

/// A template that chooses the value of `--hours`, or 24.
final class _HoursTemplate extends RoleTemplate<String> {
  @override
  Future<Object?> choose(RoleChoiceContext<String> context) async =>
      context.option('hours') ?? '24';
}

/// A template that writes its data into `lib/labels.dart`, and records the
/// data that its choice got.
final class _LabelsTemplate extends RoleTemplate<String> {
  /// The contexts of [choose], in order.
  final List<RoleChoiceContext<String>> chosen = [];

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(
          bundle(
            'labels',
            files: {'lib/labels.dart': "const labels = '{{labels}}';\n"},
          ),
        ),
      ];

  @override
  Future<Object?> choose(RoleChoiceContext<String> context) async {
    chosen.add(context);
    return null;
  }

  @override
  RoleOutput render(RoleHookInput<String> input) => RoleOutput(
        vars: {
          'labels': [for (final data in input.data) data.value].join(', '),
        },
      );
}
