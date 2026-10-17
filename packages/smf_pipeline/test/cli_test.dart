import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late RecordingRunner runner;
  late FakeHost host;

  /// The modules of a small app, with [contributions] of a module `extra`.
  List<SmfModule> modulesWith([List<Contribution> contributions = const []]) =>
      [
        scaffold(),
        TestModule('extra', contributions: contributions),
      ];

  setUp(() {
    runner = RecordingRunner();
    host = FakeHost(processRunner: runner);
  });

  late List<bool> flags;
  late List<SmfModule> modules;
  late List<GeneratedApp> created;

  Future<int> smf(List<String> arguments, {int? usageLineLength}) => runSmf(
        arguments,
        modules: modules,
        hostFor: ({required verbose}) {
          flags.add(verbose);
          return host.host;
        },
        version: '1.2.3',
        usageLineLength: usageLineLength,
        onCreated: created.add,
      );

  setUp(() {
    flags = [];
    modules = modulesWith();
    created = [];
  });

  /// The end of what the run reported, from the line that the app is
  /// created, each message after its level.
  List<String> end() => host.logger.reports
      .skipWhile((report) => !report.startsWith('success: '))
      .toList();

  test('creates the app and says how to run it', () async {
    expect(
      await smf([
        'create',
        'my_app',
        '-o',
        '/work',
        '-m',
        'extra',
        '--no-input',
        '--skip-external-setup',
      ]),
      SmfExitCodes.success,
    );

    expect(host.logger.successes, ['Created my_app in /work/my_app.']);
    expect(
      host.logger.infos.last,
      'Run it:\n  cd /work/my_app\n  flutter run',
    );
    // Nothing comes between the two, and nothing after them.
    expect(end(), [
      'success: Created my_app in /work/my_app.',
      'info: Run it:\n  cd /work/my_app\n  flutter run',
    ]);
    expect(host.logger.warnings, isEmpty);
    expect(flags, [false]);
    expect(created.single.path, '/work/my_app');
  });

  test('quotes the directory of the app for the shell', () async {
    await smf([
      'create',
      'my_app',
      '-o',
      '/work/my apps',
      '--no-input',
    ]);

    expect(
      host.logger.infos.last,
      "Run it:\n  cd '/work/my apps/my_app'\n  flutter run",
    );
  });

  test('--verbose reaches the host, before or after the command', () async {
    await smf(['--verbose', 'create', 'my_app', '--explain']);
    await smf(['create', 'my_app', '--explain', '--verbose']);
    await smf(['create', 'my_app', '--explain']);

    expect(flags, [true, true, false]);
    expect(created, isEmpty);
  });

  test('prints the version, help and explanations', () async {
    expect(await smf(['--version']), SmfExitCodes.success);
    expect(host.logger.infos.last, '1.2.3');

    expect(await smf(['--help']), SmfExitCodes.success);
    expect(host.logger.infos.last, contains('Available commands:'));

    expect(await smf([]), SmfExitCodes.success);
    expect(host.logger.infos.last, contains('create'));

    expect(await smf(['create', '--help']), SmfExitCodes.success);
    expect(host.logger.infos.last, contains('--on-conflict'));
    expect(host.logger.infos.last, isNot(contains('--verbose')));

    expect(
      await smf(['create', 'my_app', '--explain', '-m', 'extra']),
      SmfExitCodes.success,
    );
    expect(host.logger.infos, contains('Modules'));
  });

  test('--version with a command prints the version and runs it', () async {
    expect(
      await smf(['-v', 'create', 'my_app', '--explain', '-m', 'extra']),
      SmfExitCodes.success,
    );

    expect(host.logger.infos.first, '1.2.3');
    expect(host.logger.infos, contains('Modules'));
  });

  test('wraps help at the given width', () async {
    await smf(['--help'], usageLineLength: 30);
    expect(
      host.logger.infos.last,
      startsWith('Generates Flutter apps from\nindependent modules.'),
    );

    await smf(['create', '--help'], usageLineLength: 30);
    expect(
      host.logger.infos.last,
      startsWith('Generates a Flutter app from\nmodules.'),
    );
  });

  test('usage errors exit with 64', () async {
    expect(await smf(['--nope']), SmfExitCodes.usage);
    expect(
        host.logger.errors.last,
        'Could not find an option named '
        '"--nope".');

    expect(await smf(['create', 'my_app', '--nope']), SmfExitCodes.usage);
    expect(host.logger.infos.last, contains('Usage: smf create <app name>'));

    expect(
      await smf(['create', 'my_app', '-m', 'unknown']),
      SmfExitCodes.usage,
    );
    expect(
      host.logger.errors.last,
      startsWith('There is no module unknown.'),
    );

    expect(await smf(['create', 'a', 'b']), SmfExitCodes.usage);
    expect(host.logger.errors.last, 'Give one app name, not 2: a b.');
    expect(host.logger.infos.last, contains('Usage: smf create <app name>'));
  });

  test('the help of an unknown command is a usage error', () async {
    expect(await smf(['help', 'nope']), SmfExitCodes.usage);
    expect(
      host.logger.errors.last,
      'Could not find a command named "nope".',
    );
  });

  group('a step that is left for later', () {
    const logIn = PostGenStep(
      ToolRef('firebase'),
      ['login'],
      description: 'Log in to Firebase',
      external: true,
      skippable: true,
    );
    const create = [
      'create',
      'my_app',
      '-o',
      '/work',
      '-m',
      'extra',
      '--skip-external-setup',
    ];

    test(
        'is no warning: it comes after the line of the app, with its reason '
        'and its command, before the lines on running the app', () async {
      modules = modulesWith([logIn]);

      expect(await smf(create), SmfExitCodes.success);

      expect(host.logger.warnings, isEmpty);
      expect(end(), [
        'success: Created my_app in /work/my_app.',
        equals(
          'info: One step is left for later. Run it in the app:\n'
          '  Log in to Firebase (the run skips external setup):\n'
          '    firebase login',
        ),
        'info: Then run the app:\n  cd /work/my_app\n  flutter run',
      ]);
      expect(created.single.skippedSteps.single.command, 'firebase login');
    });

    test('has its whole command on one line, however long it is', () async {
      const arguments = [
        'configure',
        '--platforms=android,ios',
        '--overwrite-firebase-options',
        '--ios-bundle-id=com.example.my-app',
        '--android-package-name=com.example.my_app',
        '--out',
        'lib/my options.dart',
      ];
      const command = 'flutterfire configure --platforms=android,ios '
          '--overwrite-firebase-options --ios-bundle-id=com.example.my-app '
          "--android-package-name=com.example.my_app --out 'lib/my "
          "options.dart'";
      modules = modulesWith([
        const PostGenStep(
          ToolRef('flutterfire'),
          arguments,
          description: 'Configuring',
          external: true,
          skippable: true,
        ),
      ]);

      expect(await smf(create), SmfExitCodes.success);

      expect(command.length, greaterThan(160));
      expect(host.logger.infos[host.logger.infos.length - 2].split('\n'), [
        'One step is left for later. Run it in the app:',
        '  Configuring (the run skips external setup):',
        '    $command',
      ]);
    });

    test('is numbered among several, in the order in which they run', () async {
      host = FakeHost(processRunner: runner, terminal: true, answers: [false]);
      modules = [
        ...modulesWith([logIn]),
        TestModule(
          'other',
          contributions: const [
            PostGenStep(
              ToolRef('dart'),
              ['run', 'deploy'],
              description: 'Deploying the rules',
              skippable: true,
            ),
          ],
        ),
      ];

      expect(
        await smf([
          'create',
          'my_app',
          '-o',
          '/work',
          '--org',
          'com.example',
          '-m',
          'extra,other',
          '--skip-external-setup',
        ]),
        SmfExitCodes.success,
      );

      expect(host.logger.warnings, isEmpty);
      expect(end(), [
        'success: Created my_app in /work/my_app.',
        equals(
          'info: 2 steps are left for later. Run them in the app, in this '
          'order:\n'
          '  1. Log in to Firebase (the run skips external setup):\n'
          '     firebase login\n'
          '  2. Deploying the rules (you chose to run it later):\n'
          '     dart run deploy',
        ),
        'info: Then run the app:\n  cd /work/my_app\n  flutter run',
      ]);
    });

    test('comes before the directory of the app, quoted for Windows', () async {
      host = FakeHost(
        processRunner: runner,
        operatingSystem: HostOperatingSystem.windows,
      );
      modules = modulesWith([logIn]);

      expect(
        await smf([
          'create',
          'my_app',
          '-o',
          r'C:\work\my apps',
          '-m',
          'extra',
          '--skip-external-setup',
        ]),
        SmfExitCodes.success,
      );

      expect(end(), [
        r'success: Created my_app in C:\work\my apps\my_app.',
        equals(
          'info: One step is left for later. Run it in the app:\n'
          '  Log in to Firebase (the run skips external setup):\n'
          '    firebase login',
        ),
        equals(
          'info: Then run the app:\n'
          r'  cd "C:\work\my apps\my_app"'
          '\n  flutter run',
        ),
      ]);
    });
  });

  group('a step that fails', () {
    const first = PostGenStepId(ModuleId('extra'), 'first');
    const enable = PostGenStepId(ModuleId('auth'), 'enable');
    const notice = 'The tool also registers a web app in the project.';
    const create = [
      'create',
      'my_app',
      '-o',
      '/work',
      '--org',
      'com.example',
    ];
    const notDone = 'Setting up is not done, because it exited with code 1. '
        'Run it in the app: dart run first';
    const failed = [
      'The step "Setting up" failed: it exited with code 1',
      notDone,
    ];

    setUp(() {
      host = FakeHost(
        processRunner: runner,
        terminal: true,
        answers: [true, false],
      );
      runner.onRun = (call) => call.line == 'dart run first'
          ? const SmfProcessResult(exitCode: 1)
          : const SmfProcessResult(exitCode: 0);
      modules = [
        ...modulesWith([
          const PostGenStep(
            ToolRef('dart'),
            ['run', 'first'],
            id: first,
            description: 'Setting up',
            skippable: true,
          ),
        ]),
        // Its steps continue the step that fails, one after the other.
        TestModule(
          'auth',
          dependsOn: {'extra'},
          contributions: const [
            PostGenStep(
              ToolRef('dart'),
              ['run', 'enable'],
              id: enable,
              followUpOf: first,
              description: 'Enabling the methods',
              notice: notice,
              skippable: true,
            ),
            PostGenStep(
              ToolRef('dart'),
              ['run', 'verify'],
              followUpOf: enable,
              description: 'Verifying the methods',
              skippable: true,
            ),
          ],
        ),
        TestModule(
          'other',
          contributions: const [
            PostGenStep(
              ToolRef('dart'),
              ['run', 'deploy'],
              description: 'Deploying the rules',
              skippable: true,
            ),
          ],
        ),
      ];
    });

    test('is a warning, before the line of the app, and no step for later',
        () async {
      host = FakeHost(processRunner: runner, terminal: true, answers: [true]);

      expect(await smf([...create, '-m', 'extra']), SmfExitCodes.success);

      expect(host.logger.warnings, failed);
      expect(host.logger.reports.sublist(host.logger.reports.length - 4), [
        for (final warning in failed) 'warn: $warning',
        'success: Created my_app in /work/my_app.',
        'info: Run it:\n  cd /work/my_app\n  flutter run',
      ]);
      expect(created.single.skippedSteps.single.failed, isTrue);
    });

    test(
        'is a warning, and the steps that are left for later with it are '
        'not: the one that continues it names it, and the next one its '
        'number', () async {
      expect(
        await smf([...create, '-m', 'auth,other']),
        SmfExitCodes.success,
      );

      expect(host.prompter.asked.map((prompt) => prompt.message), [
        'Setting up (dart run first), for extra. Run it now?',
        'Deploying the rules (dart run deploy), for other. Run it now?',
      ]);
      expect(host.logger.warnings, failed);
      expect(host.logger.reports.sublist(host.logger.reports.length - 5), [
        for (final warning in failed) 'warn: $warning',
        'success: Created my_app in /work/my_app.',
        equals(
          'info: 3 steps are left for later. Run them in the app, in this '
          'order:\n'
          '  1. Enabling the methods (it runs after "Setting up", which is '
          'not done):\n'
          '     dart run enable\n'
          '     $notice\n'
          '  2. Verifying the methods (it runs after step 1):\n'
          '     dart run verify\n'
          '  3. Deploying the rules (you chose to run it later):\n'
          '     dart run deploy',
        ),
        'info: Then run the app:\n  cd /work/my_app\n  flutter run',
      ]);
      expect(
        created.single.skippedSteps.map((step) => step.failed),
        [true, false, false, false],
      );
    });
  });

  group('a step with a notice that continues a step of another module', () {
    const first = PostGenStepId(ModuleId('extra'), 'first');
    const notice = 'The tool also registers a web app in the project.';
    // Everything that a run in a terminal would ask for otherwise.
    const create = [
      'create',
      'my_app',
      '-o',
      '/work',
      '--org',
      'com.example',
      '-m',
      'auth',
    ];

    /// A host with a terminal, whose user gives [answers].
    FakeHost terminal([List<Object?> answers = const []]) =>
        FakeHost(processRunner: runner, terminal: true, answers: answers);

    /// What the run reports after the line of the app when the step is the
    /// only one that is left for later, because of [reason]: the notice
    /// comes below the command.
    String leftAlone(String reason) =>
        'info: One step is left for later. Run it in the app:\n'
        '  Enabling the methods ($reason):\n'
        '    dart run enable\n'
        '    $notice';

    setUp(() {
      modules = [
        ...modulesWith([
          const PostGenStep(ToolRef('dart'), ['run', 'first'], id: first),
        ]),
        // It depends on extra, which knows nothing of it.
        TestModule(
          'auth',
          dependsOn: {'extra'},
          contributions: const [
            PostGenStep(
              ToolRef('dart'),
              ['run', 'enable'],
              followUpOf: first,
              description: 'Enabling the methods',
              notice: notice,
              skippable: true,
              external: true,
            ),
          ],
        ),
      ];
    });

    test('is asked about in a terminal, and runs when the user agrees',
        () async {
      host = terminal([true]);

      expect(await smf(create), SmfExitCodes.success);

      expect(
        host.prompter.asked.single.message,
        'Enabling the methods (dart run enable), for auth. $notice Run it '
        'now?',
      );
      expect(
        runner.lines,
        containsAllInOrder(['dart run first', 'dart run enable']),
      );
      expect(host.logger.warnings, isEmpty);
      expect(created.single.skippedSteps, isEmpty);
    });

    test('that the user declines is left for later, with the notice', () async {
      host = terminal([false]);

      expect(await smf(create), SmfExitCodes.success);

      expect(host.prompter.asked, hasLength(1));
      expect(runner.lines, contains('dart run first'));
      expect(runner.lines, isNot(contains('dart run enable')));
      expect(host.logger.warnings, isEmpty);
      expect(end()[1], leftAlone('you chose to run it later'));
    });

    test('is left for later with --no-input, with the notice', () async {
      host = terminal();

      expect(await smf([...create, '--no-input']), SmfExitCodes.success);

      expect(host.prompter.asked, isEmpty);
      expect(runner.lines, contains('dart run first'));
      expect(runner.lines, isNot(contains('dart run enable')));
      expect(host.logger.warnings, isEmpty);
      expect(end()[1], leftAlone('the run cannot ask the user'));
      expect(created.single.skippedSteps.single.notice, notice);
    });

    test('is left for later with --skip-external-setup, with the notice',
        () async {
      host = terminal();

      expect(
        await smf([...create, '--skip-external-setup']),
        SmfExitCodes.success,
      );

      expect(host.prompter.asked, isEmpty);
      expect(runner.lines, contains('dart run first'));
      expect(runner.lines, isNot(contains('dart run enable')));
      expect(host.logger.warnings, isEmpty);
      expect(end()[1], leftAlone('the run skips external setup'));
    });

    test(
        'is left for later with the step that it continues, with the notice '
        'after its own command', () async {
      host = terminal();
      modules = [
        ...modulesWith([
          const PostGenStep(
            ToolRef('dart'),
            ['run', 'first'],
            id: first,
            description: 'Setting up',
            skippable: true,
            external: true,
          ),
        ]),
        modules.last,
      ];

      expect(
        await smf([...create, '--skip-external-setup']),
        SmfExitCodes.success,
      );

      expect(host.prompter.asked, isEmpty);
      expect(runner.lines, isNot(contains(startsWith('dart run'))));
      expect(host.logger.warnings, isEmpty);
      expect(end(), [
        'success: Created my_app in /work/my_app.',
        equals(
          'info: 2 steps are left for later. Run them in the app, in this '
          'order:\n'
          '  1. Setting up (the run skips external setup):\n'
          '     dart run first\n'
          // It refers to the step by its number in the list.
          '  2. Enabling the methods (it runs after step 1):\n'
          '     dart run enable\n'
          '     $notice',
        ),
        'info: Then run the app:\n  cd /work/my_app\n  flutter run',
      ]);
    });

    test('that fails once the user agreed is left for later, with the notice',
        () async {
      host = terminal([true]);
      runner.onRun = (call) => call.line == 'dart run enable'
          ? const SmfProcessResult(exitCode: 1)
          : const SmfProcessResult(exitCode: 0);

      expect(await smf(create), SmfExitCodes.success);

      expect(host.prompter.asked, hasLength(1));
      expect(runner.lines, contains('dart run enable'));
      expect(host.logger.warnings, [
        'The step "Enabling the methods" failed: it exited with code 1',
        equals(
          'Enabling the methods is not done, because it exited with code 1. '
          'Run it in the app: dart run enable\n'
          '$notice',
        ),
      ]);
      // It is no step that the run left for later.
      expect(end(), [
        'success: Created my_app in /work/my_app.',
        'info: Run it:\n  cd /work/my_app\n  flutter run',
      ]);
      expect(created.single.skippedSteps.single.failed, isTrue);
    });

    test('is shown by --explain under its command', () async {
      host = terminal();

      expect(await smf([...create, '--explain']), SmfExitCodes.success);

      expect(
        host.logger.infos.join('\n'),
        contains(
          'After generation\n'
          '  dart run first (extra)\n'
          '    then dart run enable (auth)\n'
          '      $notice\n'
          '      A run asks before it runs this step, and leaves it for later '
          'when it cannot ask.\n',
        ),
      );
      expect(runner.calls, isEmpty);
    });
  });

  test('says which modules lenient mode left out', () async {
    final other = TestRole<NoDsl>('other');
    modules = [
      ...modulesWith(),
      TestModule(
        'broken',
        contributions: [
          CodegenRequest(when: {other}),
        ],
      ),
      TestModule('uses_other', uses: {other}),
    ];

    expect(
      await smf([
        'create',
        'my_app',
        '-m',
        'extra,broken',
        '--no-input',
      ]),
      SmfExitCodes.success,
    );

    expect(
      host.logger.warnings.last,
      'The app is without broken, which could not work; see above. With '
      '--strict, such a problem stops the run instead.',
    );
    expect(created.single.leftOut.single.module, const ModuleId('broken'));
  });

  test('a failed generation exits with 1 and lists the problems', () async {
    modules = modulesWith([
      BrickContribution(bundle('broken', files: {'lib/b.dart': '{{a}}'})),
    ]);

    expect(
      await smf(['create', 'my_app', '-o', '/work', '-m', 'extra']),
      SmfExitCodes.generationFailed,
    );
    expect(host.logger.errors, [
      'The app cannot be rendered because of an error.',
      startsWith('  error [extra] lib/b.dart: The template lib/b.dart'),
    ]);
  });

  group('a warning about what the app is made of', () {
    setUp(() {
      modules = [
        ...modulesWith(),
        TestModule(
          'watcher',
          providers: [
            RoleProvider.plain(
              TestRole<String>(
                'watch',
                template: TestTemplate(
                  warnings: const [
                    SmfIssue.warning(
                      'No screen to start on.',
                      code: 'watch.no_start',
                      hint: 'Add one.',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ];
    });

    const create = [
      'create',
      'my_app',
      '-o',
      '/work',
      '-m',
      'watcher',
      '--no-input',
    ];

    test('is printed after its origin and without its code', () async {
      expect(await smf(create), SmfExitCodes.success);

      expect(host.logger.warnings, [
        '[role:watch]: No screen to start on. (Add one.)',
      ]);
      expect(created, hasLength(1));
    });

    test(
        'stops a run with --strict, which exits with 1 and names its code, '
        'and creates nothing', () async {
      const stoppedLine = 'Generation stopped because of a warning about '
          'the app. Without --strict, the run goes on after it.';
      const warningLine = '  warning [role:watch] watch.no_start: No screen '
          'to start on. (Add one.)';
      expect(await smf([...create, '--strict']), SmfExitCodes.generationFailed);

      expect(host.logger.errors, [
        // The code tells which --allow-warning would let the run go on.
        stoppedLine,
        warningLine,
      ]);
      expect(host.logger.warnings, isEmpty);
      expect(created, isEmpty);
      expect(host.fileSystem.directory('/work/my_app').existsSync(), isFalse);
    });

    test('does not stop a run with --strict that names its code', () async {
      expect(
        await smf([...create, '--strict', '--allow-warning=watch.no_start']),
        SmfExitCodes.success,
      );

      expect(host.logger.warnings, [
        '[role:watch]: No screen to start on. (Add one.)',
      ]);
      expect(created, hasLength(1));
    });

    test('cannot be allowed with a value that is not a code', () async {
      expect(
        await smf([...create, '--strict', '--allow-warning=no_start']),
        SmfExitCodes.usage,
      );

      expect(
        host.logger.errors.single,
        startsWith('"no_start" is not the code of a warning'),
      );
      expect(host.logger.infos.last, contains('Usage: smf create <app name>'));
      expect(created, isEmpty);
    });
  });

  test('an unexpected error exits with 70', () async {
    host = FakeHost(processRunner: runner, terminal: true);

    // The prompter has no answer for the name of the app.
    expect(await smf(['create']), SmfExitCodes.software);
    expect(
      host.logger.errors.single,
      startsWith('smf stopped because of an unexpected error: Bad state: '
          'Unexpected question'),
    );
    expect(host.logger.details.last, contains('cli_test.dart'));
    expect(
      host.logger.infos.last,
      'Run it again with --verbose for the full log.',
    );
  });

  test('a run the user cancels exits with 130', () async {
    host = FakeHost(
      processRunner: runner,
      terminal: true,
      answers: [const SmfCancelledException()],
    );

    expect(await smf(['create']), SmfExitCodes.cancelled);
    expect(host.logger.infos.last, 'Cancelled. No app was created.');
    expect(host.logger.errors, isEmpty);
    expect(created, isEmpty);
  });

  test('modules that break the rules of the registry exit with 70', () async {
    modules = [...modulesWith(), TestModule('extra')];

    expect(await smf(['create', 'my_app']), SmfExitCodes.software);
    expect(host.logger.errors, [
      'The modules of smf break the rules of the registry, which is a bug:',
      '  Two modules have the id extra.',
    ]);
  });
}
