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

  test('says which steps to run later', () async {
    modules = modulesWith([
      const PostGenStep(
        ToolRef('firebase'),
        ['login'],
        description: 'Log in to Firebase',
        external: true,
        skippable: true,
      ),
    ]);

    await smf([
      'create',
      'my_app',
      '-o',
      '/work',
      '-m',
      'extra',
      '--skip-external-setup',
    ]);

    expect(
      host.logger.warnings.last,
      'Log in to Firebase is not done, because the run skips external '
      'setup. Run it in the app: firebase login',
    );
    expect(created.single.skippedSteps.single.command, 'firebase login');
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
      expect(
        host.logger.warnings.single,
        'Enabling the methods is not done, because you chose to run it '
        'later. Run it in the app: dart run enable\n'
        '$notice',
      );
    });

    test('is left for later with --no-input, with the notice', () async {
      host = terminal();

      expect(await smf([...create, '--no-input']), SmfExitCodes.success);

      expect(host.prompter.asked, isEmpty);
      expect(runner.lines, contains('dart run first'));
      expect(runner.lines, isNot(contains('dart run enable')));
      expect(
        host.logger.warnings.single,
        'Enabling the methods is not done, because the run cannot ask the '
        'user. Run it in the app: dart run enable\n'
        '$notice',
      );
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
      expect(
        host.logger.warnings.single,
        'Enabling the methods is not done, because the run skips external '
        'setup. Run it in the app: dart run enable\n'
        '$notice',
      );
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
