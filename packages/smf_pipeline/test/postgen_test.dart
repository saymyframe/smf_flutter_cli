import 'package:smf_contracts/smf_contracts.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A request of [module] for code generation of [outputs].
Collected _codegen(String module, [List<String> outputs = const []]) =>
    Collected(
      CodegenRequest(outputs: outputs),
      ModuleOrigin(ModuleId(module)),
      applies: true,
    );

/// A step of [module].
Collected _step(
  String module,
  PostGenStep step,
) =>
    Collected(step, ModuleOrigin(ModuleId(module)), applies: true);

/// The command of the import cleanup.
final cleanup = 'dart fix --apply --code=${importCleanupCodes.join(',')}';

/// The origin of the contributions of the module `firebase`.
const _firebase = ModuleOrigin(ModuleId('firebase'));

/// A check [id] that looks for [description], whose result the tests give.
final class _Check extends PreflightCheck {
  const _Check(this.id, this.description);

  @override
  final String id;

  @override
  final String description;

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) =>
      throw UnimplementedError('The tests give the result.');
}

void main() {
  late RecordingRunner runner;
  late FakeHost host;
  late PipelineEnvironment environment;

  PipelineEnvironment environmentOf({
    bool interactive = false,
    bool skipExternalSetup = false,
    HostOperatingSystem operatingSystem = HostOperatingSystem.linux,
    List<Object?> answers = const [],
  }) {
    runner = RecordingRunner();
    host = FakeHost(
      processRunner: runner,
      terminal: interactive,
      answers: answers,
      operatingSystem: operatingSystem,
      environment: {
        'PATH': operatingSystem == HostOperatingSystem.windows
            ? r'C:\sdk\bin'
            : '/sdk/bin:/usr/bin',
      },
    );
    host.fileSystem.file('/usr/bin/firebase').createSync(recursive: true);
    final windows = operatingSystem == HostOperatingSystem.windows;
    return host.environment(
      interactive: interactive,
      skipExternalSetup: skipExternalSetup,
    )..sdk = FlutterSdk(
        flutter: windows ? r'C:\sdk\bin\flutter.bat' : '/sdk/bin/flutter',
        dart: windows ? r'C:\sdk\bin\dart.bat' : '/sdk/bin/dart',
      );
  }

  setUp(() => environment = environmentOf());

  test('runs pub get, code generation, the steps, fixes and formatting',
      () async {
    final skipped = await runPostGen(
      directory: '/tmp/app',
      environment: environment,
      codegen: [_codegen('model')],
      steps: [
        _step('a', const PostGenStep(ToolRef('firebase'), ['--version'])),
        _step(
          'b',
          const PostGenStep(
            ToolRef('dart', prefixArgs: ['pub', 'global', 'run', 'x:x']),
            ['go'],
          ),
        ),
      ],
    );

    expect(skipped, isEmpty);
    expect(runner.lines, [
      'flutter pub get',
      'dart run build_runner build --force-jit',
      'firebase --version',
      'dart pub global run x:x go',
      cleanup,
      'dart fix --apply',
      'dart format .',
    ]);
    for (final call in runner.calls) {
      expect(call.workingDirectory, '/tmp/app');
      expect(call.runInShell, isFalse);
      expect(
        call.environment['PATH'],
        allOf(startsWith('/sdk/bin:'), endsWith(':/usr/bin')),
      );
    }
    expect(runner.calls.first.executable, '/sdk/bin/flutter');
    expect(runner.calls[2].executable, '/usr/bin/firebase');
    expect(
      host.logger.details.first,
      'Running /sdk/bin/flutter pub get in /tmp/app',
    );
  });

  test('code generation must generate the outputs it names', () async {
    host.fileSystem.file('/tmp/app/lib/di.config.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync('// generated');

    await runPostGen(
      directory: '/tmp/app',
      environment: environment,
      steps: const [],
      codegen: [
        _codegen('di', ['lib/di.config.dart']),
      ],
    );
    await expectLater(
      runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: const [],
        codegen: [
          _codegen('di', ['lib/di.config.dart']),
          _codegen('assets', ['lib/gen/assets.gen.dart']),
        ],
      ),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          'build_runner did not generate lib/gen/assets.gen.dart, which assets '
              'named as an output of its code generation.',
        ),
      ),
    );
  });

  test('without code generation and the full dart fix', () async {
    await runPostGen(
      directory: '/tmp/app',
      environment: environment,
      steps: const [],
      fullDartFix: false,
    );

    expect(runner.lines, [
      'flutter pub get',
      cleanup,
      'dart format .',
    ]);
  });

  test('on Windows, the batch files of the SDK go to the runner as they are',
      () async {
    environment = environmentOf(operatingSystem: HostOperatingSystem.windows);
    await runPostGen(
      directory: r'C:\tmp\app',
      environment: environment,
      steps: const [],
    );

    expect(runner.calls.first.executable, r'C:\sdk\bin\flutter.bat');
    expect(runner.calls.any((call) => call.runInShell), isFalse);
  });

  test('a failed pub get or code generation stops generation', () async {
    runner.onRun = (call) => call.arguments.contains('get')
        ? const SmfProcessResult(exitCode: 65, stderr: 'no network\n')
        : const SmfProcessResult(exitCode: 0);
    await expectLater(
      runPostGen(directory: '/tmp/app', environment: environment, steps: []),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          'flutter pub get failed: it exited with code 65:\nno network',
        ),
      ),
    );
    expect(host.logger.progresses, [
      'start: Getting the packages of the app',
      'fail: Getting the packages of the app',
    ]);

    runner.onRun = (call) => call.arguments.contains('build_runner')
        ? const SmfProcessResult(exitCode: 1, stdout: 'bad builder')
        : const SmfProcessResult(exitCode: 0);
    await expectLater(
      runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [],
        codegen: [_codegen('model')],
      ),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          contains('dart run build_runner build --force-jit failed'),
        ),
      ),
    );
  });

  test('a failure shows the end of both streams, and --verbose all output',
      () async {
    runner.onRun = (call) => call.arguments.contains('build_runner')
        ? const SmfProcessResult(
            exitCode: 1,
            stderr: 'Building package executable...\n',
            stdout: '[SEVERE] lib/model.g.dart: bad\n',
          )
        : const SmfProcessResult(exitCode: 0, stdout: 'Got dependencies!\n');

    await expectLater(
      runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [],
        codegen: [_codegen('model')],
      ),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          'dart run build_runner build --force-jit failed: it exited with code '
              '1:\n'
              'Building package executable...\n'
              '[SEVERE] lib/model.g.dart: bad',
        ),
      ),
    );
    expect(host.logger.details, [
      'Running /sdk/bin/flutter pub get in /tmp/app',
      'Got dependencies!',
      'Running /sdk/bin/dart run build_runner build --force-jit in /tmp/app',
      'Building package executable...\n[SEVERE] lib/model.g.dart: bad',
    ]);
  });

  test('a failed dart fix or dart format only warns', () async {
    runner.onRun = (call) =>
        call.arguments.first == 'fix' || call.arguments.first == 'format'
            ? const SmfProcessResult(exitCode: 1)
            : const SmfProcessResult(exitCode: 0);

    await runPostGen(
      directory: '/tmp/app',
      environment: environment,
      steps: [],
    );

    expect(host.logger.warnings, [
      startsWith(
        '$cleanup failed, so run it in the app yourself: it exited with code '
        '1',
      ),
      startsWith('dart fix --apply failed, so run it in the app yourself'),
      startsWith('dart format . failed, so run it in the app yourself'),
    ]);
  });

  test('a command that cannot start is a failure', () async {
    runner.onRun = (call) => throw const ProcessStartFailure('no such file');

    await expectLater(
      runPostGen(directory: '/tmp/app', environment: environment, steps: []),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          'flutter pub get failed: it could not start: no such file',
        ),
      ),
    );
    expect(host.logger.progresses, [
      'start: Getting the packages of the app',
      'fail: Getting the packages of the app',
    ]);
  });

  test('a command the user interrupts cancels the run', () async {
    runner.onRun = (call) => throw const SmfCancelledException();

    await expectLater(
      runPostGen(directory: '/tmp/app', environment: environment, steps: []),
      throwsA(isA<SmfCancelledException>()),
    );
    expect(host.logger.progresses, [
      'start: Getting the packages of the app',
      'fail: Getting the packages of the app',
    ]);
  });

  test('flutter waiting for the startup lock shows in the progress', () async {
    runner.onRun = (call) {
      call.onOutput!('Resolving dependencies...');
      for (var i = 0; i < 2; i++) {
        const lock = 'Waiting for another flutter command to release the '
            'startup lock...';
        call.onOutput!(lock);
      }
      call.onOutput!('Got dependencies!');
      return const SmfProcessResult(exitCode: 0);
    };

    await runPostGen(
      directory: '/tmp/app',
      environment: environment,
      steps: [],
      fullDartFix: false,
    );

    expect(host.logger.progresses.take(4), [
      'start: Getting the packages of the app',
      'update: Waiting for another flutter command to finish',
      'update: Getting the packages of the app',
      'complete: Getting the packages of the app',
    ]);
  });

  test('keeps only the last lines of a long output', () async {
    runner.onRun = (call) => SmfProcessResult(
          exitCode: 1,
          stderr: [for (var i = 1; i <= 30; i++) 'line $i'].join('\n'),
        );

    await expectLater(
      runPostGen(directory: '/tmp/app', environment: environment, steps: []),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          allOf(
            contains('…\nline 11\n'),
            endsWith('line 30'),
            isNot(contains('line 10\n')),
          ),
        ),
      ),
    );
  });

  group('the steps of the modules', () {
    const login = PostGenStep(
      ToolRef('firebase'),
      ['login'],
      description: 'Log in to Firebase',
      interactive: true,
      skippable: true,
      external: true,
    );
    const configure = PostGenStep(
      ToolRef('flutterfire'),
      ['configure', '--platforms=android,ios', '--out', 'lib/my options.dart'],
      description: 'Configure Firebase',
      skippable: true,
    );

    test('are skipped without a terminal or external setup', () async {
      environment = environmentOf(skipExternalSetup: true);
      final skipped = await runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [
          _step('firebase', login),
          _step(
            'other',
            const PostGenStep(
              ToolRef('firebase'),
              ['use'],
              interactive: true,
              skippable: true,
            ),
          ),
        ],
      );

      expect(skipped.map((step) => '$step'), [
        'Log in to Firebase: firebase login (the run skips external setup)',
        'firebase use: firebase use (the run cannot ask the user)',
      ]);
      expect(skipped.map((step) => step.failed), [false, false]);
      expect(runner.lines, isNot(contains(startsWith('firebase'))));
    });

    test('run in the terminal when they are interactive', () async {
      environment = environmentOf(interactive: true, answers: [true]);
      final skipped = await runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [_step('firebase', login)],
      );

      expect(skipped, isEmpty);
      final call = runner.calls[1];
      expect(call.interactive, isTrue);
      expect(call.line, 'firebase login');
      expect(
        host.prompter.asked.single.message,
        'Log in to Firebase (firebase login), for firebase. Run it now?',
      );
    });

    test('the user may leave a skippable step for later', () async {
      environment = environmentOf(interactive: true, answers: [false, false]);
      host.fileSystem.file('/usr/bin/flutterfire').createSync();
      final skipped = await runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [
          _step('firebase', configure),
          _step(
            'other',
            const PostGenStep(ToolRef('firebase'), ['use'], skippable: true),
          ),
        ],
      );

      expect(skipped.map((step) => '$step'), [
        equals(
          'Configure Firebase: flutterfire configure --platforms=android,ios '
          "--out 'lib/my options.dart' (you chose to run it later)",
        ),
        'firebase use: firebase use (you chose to run it later)',
      ]);
      expect(skipped.map((step) => step.failed), [false, false]);
      expect(host.prompter.asked.map((prompt) => prompt.message), [
        equals(
          'Configure Firebase (flutterfire configure --platforms=android,ios '
          "--out 'lib/my options.dart'), for firebase. Run it now?",
        ),
        'firebase use, for other. Run it now?',
      ]);
    });

    test('the command for later suits the shell of the user', () async {
      environment = environmentOf(
        operatingSystem: HostOperatingSystem.windows,
        skipExternalSetup: true,
      );
      final windows = await runPostGen(
        directory: r'C:\tmp\app',
        environment: environment,
        steps: [
          _step(
            'firebase',
            const PostGenStep(
              ToolRef('flutterfire'),
              ['configure', '--platforms=android,ios', '--out', 'a b.dart'],
              external: true,
              skippable: true,
            ),
          ),
        ],
      );
      expect(
        windows.single.command,
        'flutterfire configure "--platforms=android,ios" --out "a b.dart"',
      );

      // A tool installed during the run is not on the user's PATH.
      environment = environmentOf(skipExternalSetup: true)
        ..addBinDirs(['/home/me/.npm/bin']);
      host.fileSystem
          .file('/home/me/.npm/bin/firebase')
          .createSync(recursive: true);
      final installed = await runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [_step('firebase', login)],
      );
      expect(installed.single.command, '/home/me/.npm/bin/firebase login');
    });

    test('a skippable step that fails or is missing is left for later',
        () async {
      runner.onRun = (call) => call.arguments.contains('use')
          ? const SmfProcessResult(exitCode: 2)
          : const SmfProcessResult(exitCode: 0);
      final skipped = await runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [
          _step(
            'a',
            const PostGenStep(ToolRef('firebase'), ['use'], skippable: true),
          ),
          _step('b', configure),
        ],
      );

      expect(skipped.map((step) => step.reason), [
        'it exited with code 2',
        'flutterfire was not found',
      ]);
      expect(skipped.map((step) => step.failed), [true, true]);
      expect(host.logger.warnings, [
        'The step "firebase use" failed: it exited with code 2',
      ]);
    });

    test('a missing tool named by its path keeps the path for later', () async {
      final skipped = await runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [
          _step(
            'a',
            const PostGenStep(
              ToolRef('/opt/tidy/bin/tidy'),
              ['--all'],
              skippable: true,
            ),
          ),
        ],
      );

      expect(skipped.single.command, '/opt/tidy/bin/tidy --all');
      expect(skipped.single.reason, '/opt/tidy/bin/tidy was not found');
    });

    test('a missing tool is not offered to run', () async {
      environment = environmentOf(interactive: true);
      final skipped = await runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [_step('firebase', configure)],
      );

      expect(skipped.single.reason, 'flutterfire was not found');
      expect(host.prompter.asked, isEmpty);

      await expectLater(
        runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [
            _step(
              'firebase',
              const PostGenStep(
                ToolRef('flutterfire'),
                ['configure'],
                description: 'Configure Firebase',
              ),
            ),
          ],
        ),
        throwsA(
          isA<GenerationFailedException>().having(
            (e) => e.message,
            'message',
            'The step "Configure Firebase" of firebase cannot run, because '
                'flutterfire was not found.',
          ),
        ),
      );
    });

    test('an interactive step that cannot start is left for later', () async {
      environment = environmentOf(interactive: true, answers: [true]);
      runner.onInteractive =
          (call) => throw const ProcessStartFailure('Permission denied');

      final skipped = await runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [_step('firebase', login)],
      );

      expect(skipped.single.reason, 'it could not start');
      expect(skipped.single.failed, isTrue);
      expect(
        host.logger.warnings.single,
        'The step "Log in to Firebase" failed: it could not start: '
        'Permission denied',
      );
    });

    test('an interactive step in a cancelled run cancels it', () async {
      environment = environmentOf(interactive: true, answers: [true]);
      runner.onInteractive = (call) => throw const SmfCancelledException();

      await expectLater(
        runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [_step('firebase', login)],
        ),
        throwsA(isA<SmfCancelledException>()),
      );
    });

    group('that need checks', () {
      const tool = PlannedCheck(_Check('tool', 'Tool'), _firebase);
      const account = PlannedCheck(_Check('account', 'Account'), _firebase);
      const needsBoth = PostGenStep(
        ToolRef('firebase'),
        ['deploy'],
        description: 'Deploy',
        skippable: true,
        needs: ['tool', 'account'],
      );
      const missing = PreflightMissing(instructions: 'Install it.');

      test('run when the checks passed, asking first', () async {
        environment = environmentOf(interactive: true, answers: [true]);

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [_step('firebase', needsBoth)],
          checks: const [
            CheckResult(tool, PreflightPassed()),
            CheckResult(account, PreflightPassed(), installed: true),
          ],
        );

        expect(skipped, isEmpty);
        expect(host.prompter.asked, hasLength(1));
        expect(runner.lines, contains('firebase deploy'));
      });

      test('are left for later without a question when one did not pass',
          () async {
        environment = environmentOf(interactive: true);

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [_step('firebase', needsBoth)],
          checks: const [
            CheckResult(tool, missing),
            CheckResult(account, PreflightFailed('offline')),
          ],
        );

        expect(
          '${skipped.single}',
          'Deploy: firebase deploy (Tool is missing, and Account could not be '
              'checked)',
        );
        expect(skipped.single.failed, isTrue);
        expect(host.prompter.asked, isEmpty);
        expect(runner.lines, isNot(contains(startsWith('firebase'))));
      });

      test('name every check that is missing', () async {
        environment = environmentOf(interactive: true);

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [_step('firebase', needsBoth)],
          checks: const [
            CheckResult(tool, missing),
            CheckResult(account, missing),
          ],
        );

        expect(skipped.single.reason, 'Tool and Account are missing');
      });

      test('call missing what a failed setup left missing', () async {
        environment = environmentOf(interactive: true);

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [_step('firebase', needsBoth)],
          checks: const [
            CheckResult(tool, PreflightPassed()),
            CheckResult(
              account,
              missing,
              setupFailure: '"firebase login" exited with code 2.',
            ),
          ],
        );

        expect(skipped.single.reason, 'Account is missing');
      });

      test('name what a check found in place of what it looks for', () async {
        environment = environmentOf(interactive: true);
        const older = PreflightMissing(
          instructions: 'Update it.',
          found: 'tool 1.0.0 is active',
        );

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [_step('firebase', needsBoth)],
          checks: const [
            CheckResult(tool, older),
            CheckResult(account, missing),
          ],
        );

        expect(
          skipped.single.reason,
          'Account is missing, and Tool is needed, but tool 1.0.0 is active',
        );
      });

      test('go by the checks of their own module only', () async {
        environment = environmentOf(interactive: true, answers: [true]);
        const other = PlannedCheck(
          _Check('tool', 'Tool'),
          ModuleOrigin(ModuleId('other')),
        );

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [_step('firebase', needsBoth)],
          // The checks of firebase did not run, since they do not apply.
          checks: const [CheckResult(other, missing)],
        );

        expect(skipped, isEmpty);
        expect(runner.lines, contains('firebase deploy'));
      });

      test('keep the reasons of the run first, then name the checks', () async {
        environment = environmentOf(skipExternalSetup: true);

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [
            _step(
              'firebase',
              const PostGenStep(
                ToolRef('firebase'),
                ['login'],
                interactive: true,
                skippable: true,
                external: true,
                needs: ['tool'],
              ),
            ),
          ],
          checks: const [CheckResult(tool, missing)],
        );

        // The user who runs the command later needs the tool too.
        expect(
          skipped.single.reason,
          'the run skips external setup, and Tool is missing',
        );
        expect(skipped.single.failed, isFalse);
      });

      test('left for a run that cannot ask, name the checks too', () async {
        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environmentOf(),
          steps: [
            _step(
              'firebase',
              const PostGenStep(
                ToolRef('firebase'),
                ['login'],
                interactive: true,
                skippable: true,
                needs: ['tool'],
              ),
            ),
          ],
          checks: const [CheckResult(tool, missing)],
        );

        expect(
          skipped.single.reason,
          'the run cannot ask the user, and Tool is missing',
        );
        expect(skipped.single.failed, isFalse);
      });

      test('stop generation when the step is not skippable', () async {
        environment = environmentOf(interactive: true);

        await expectLater(
          runPostGen(
            directory: '/tmp/app',
            environment: environment,
            steps: [
              _step(
                'firebase',
                const PostGenStep(
                  ToolRef('firebase'),
                  ['deploy'],
                  description: 'Deploy',
                  needs: ['tool'],
                ),
              ),
            ],
            checks: const [CheckResult(tool, missing)],
          ),
          throwsA(
            isA<GenerationFailedException>().having(
              (e) => e.message,
              'message',
              'The step "Deploy" of firebase cannot run, because Tool is '
                  'missing.',
            ),
          ),
        );
      });
    });

    group('that continue other steps', () {
      const setUpId = PostGenStepId(ModuleId('firebase'), 'setup');
      const fixId = PostGenStepId(ModuleId('crash'), 'fix');
      const setUp = PostGenStep(
        ToolRef('firebase'),
        ['setup'],
        id: setUpId,
        description: 'Set up Firebase',
        interactive: true,
        skippable: true,
      );
      // Steps of a module that depends on firebase, which knows nothing of
      // them.
      const fix = PostGenStep(
        ToolRef('fix'),
        ['project'],
        id: fixId,
        followUpOf: setUpId,
        description: 'Fix the project',
        skippable: true,
      );
      const check = PostGenStep(
        ToolRef('check'),
        ['project'],
        followUpOf: fixId,
        skippable: true,
      );
      const tidy = PostGenStep(
        ToolRef('tidy'),
        [],
        followUpOf: setUpId,
        skippable: true,
      );
      const tool = PlannedCheck(_Check('tool', 'Tool'), _firebase);

      /// [firebase], the step of the module firebase, and the steps of the
      /// module crash, which continue it, in the order of the pipeline:
      /// crash depends on firebase, so its steps come after.
      List<Collected> stepsOf(PostGenStep firebase) => [
            _step('firebase', firebase),
            _step('crash', fix),
            _step('crash', check),
            _step('crash', tidy),
          ];

      /// Puts the tools of the steps of crash on the PATH.
      void installTools() {
        for (final name in ['fix', 'check', 'tidy']) {
          host.fileSystem.file('/usr/bin/$name').createSync();
        }
      }

      /// The records of [steps], as `description: command (reason)`.
      List<String> records(List<SkippedStep> steps) =>
          [for (final step in steps) '$step'];

      test(
          'run right after the step they continue, in their order, each '
          'before the steps that continue it, once it succeeded, without a '
          'question', () async {
        environment = environmentOf(interactive: true, answers: [true, true]);
        installTools();

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [
            _step('firebase', setUp),
            // A step of its own that comes between in the order.
            _step(
              'other',
              const PostGenStep(ToolRef('firebase'), ['use'], skippable: true),
            ),
            ...stepsOf(setUp).skip(1),
          ],
        );

        expect(skipped, isEmpty);
        expect(runner.lines.sublist(1, 6), [
          'firebase setup',
          'fix project',
          'check project',
          'tidy',
          'firebase use',
        ]);
        expect(host.prompter.asked.map((prompt) => prompt.message), [
          'Set up Firebase (firebase setup), for firebase. Run it now?',
          'firebase use, for other. Run it now?',
        ]);
        // Each runs as it is: the step with the terminal, the step that
        // continues it without, in the directory of the app.
        expect(runner.calls[1].interactive, isTrue);
        expect(runner.calls[2].interactive, isFalse);
        expect(runner.calls[2].workingDirectory, '/tmp/app');
        expect(
          host.logger.progresses,
          containsAllInOrder([
            'start: Fix the project',
            'complete: Fix the project',
          ]),
        );
      });

      test(
          'are left for later after a step that the user leaves for later, '
          'without a question', () async {
        environment = environmentOf(interactive: true, answers: [false]);
        installTools();

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: stepsOf(setUp),
        );

        expect(records(skipped), [
          'Set up Firebase: firebase setup (you chose to run it later)',
          equals(
            'Fix the project: fix project (it runs after "Set up Firebase", '
            'which is not done)',
          ),
          equals(
            'check project: check project (it runs after "Fix the project", '
            'which is not done)',
          ),
          'tidy: tidy (it runs after "Set up Firebase", which is not done)',
        ]);
        expect(skipped.map((step) => step.failed), everyElement(isFalse));
        expect(host.prompter.asked, hasLength(1));
        expect(runner.lines, isNot(contains(startsWith('fix'))));
        expect(runner.lines, isNot(contains(startsWith('check'))));
        expect(runner.lines, isNot(contains(startsWith('tidy'))));
      });

      test('are left for later after a step that fails', () async {
        environment = environmentOf(interactive: true, answers: [true]);
        installTools();
        runner.onInteractive = (call) => 1;

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: stepsOf(setUp),
        );

        expect(skipped.map((step) => step.reason), [
          'it exited with code 1',
          'it runs after "Set up Firebase", which is not done',
          'it runs after "Fix the project", which is not done',
          'it runs after "Set up Firebase", which is not done',
        ]);
        // Only the step failed; its record tells why the rest is not done.
        expect(skipped.map((step) => step.failed), [true, false, false, false]);
        expect(runner.lines, isNot(contains(startsWith('fix'))));
      });

      test(
          'are left for later after a step that the run or a check holds '
          'back', () async {
        for (final (run, checks, reason) in [
          (
            () => environmentOf(interactive: true, skipExternalSetup: true),
            const <CheckResult>[],
            'the run skips external setup',
          ),
          (
            environmentOf,
            const <CheckResult>[],
            'the run cannot ask the user',
          ),
          (
            () => environmentOf(interactive: true),
            const [
              CheckResult(tool, PreflightMissing(instructions: 'Install it.')),
            ],
            'Tool is missing',
          ),
        ]) {
          environment = run();
          installTools();

          final skipped = await runPostGen(
            directory: '/tmp/app',
            environment: environment,
            steps: stepsOf(
              const PostGenStep(
                ToolRef('firebase'),
                ['setup'],
                id: setUpId,
                description: 'Set up Firebase',
                interactive: true,
                skippable: true,
                external: true,
                needs: ['tool'],
              ),
            ),
            checks: checks,
          );

          expect(
            records(skipped),
            [
              'Set up Firebase: firebase setup ($reason)',
              equals(
                'Fix the project: fix project (it runs after "Set up '
                'Firebase", which is not done)',
              ),
              equals(
                'check project: check project (it runs after "Fix the '
                'project", which is not done)',
              ),
              equals(
                'tidy: tidy (it runs after "Set up Firebase", which is not '
                'done)',
              ),
            ],
            reason: reason,
          );
          expect(host.prompter.asked, isEmpty);
          expect(runner.lines, isNot(contains(startsWith('fix'))));
        }
      });

      test(
          'otherwise go by their own needs, of the checks of their own '
          'module, tools and results', () async {
        environment = environmentOf(interactive: true, answers: [true]);
        // The tool of tidy is missing.
        for (final name in ['fix', 'check']) {
          host.fileSystem.file('/usr/bin/$name').createSync();
        }

        final needsTool = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [
            _step('firebase', setUp),
            _step(
              'crash',
              const PostGenStep(
                ToolRef('fix'),
                ['project'],
                id: fixId,
                followUpOf: setUpId,
                description: 'Fix the project',
                skippable: true,
                needs: ['tool'],
              ),
            ),
            _step(
              'crash',
              const PostGenStep(
                ToolRef('check'),
                ['project'],
                followUpOf: fixId,
              ),
            ),
            _step('crash', tidy),
          ],
          checks: const [
            // The check of the module that continues the step, and one of
            // the same id of the module whose step it continues, which has
            // passed.
            CheckResult(
              PlannedCheck(
                _Check('tool', 'Tool'),
                ModuleOrigin(ModuleId('crash')),
              ),
              PreflightMissing(instructions: 'Install it.'),
            ),
            CheckResult(tool, PreflightPassed()),
          ],
        );

        expect(records(needsTool), [
          'Fix the project: fix project (Tool is missing)',
          equals(
            'check project: check project (it runs after "Fix the project", '
            'which is not done)',
          ),
          'tidy: tidy (tidy was not found)',
        ]);
        expect(needsTool.map((step) => step.failed), [true, false, true]);
        expect(runner.lines, contains('firebase setup'));
        expect(runner.lines, isNot(contains(startsWith('fix'))));

        // A check of the module whose step it continues holds nothing of
        // the module crash back.
        environment = environmentOf(interactive: true, answers: [true]);
        installTools();

        final otherModule = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [
            _step('firebase', setUp),
            _step(
              'crash',
              const PostGenStep(
                ToolRef('fix'),
                ['project'],
                followUpOf: setUpId,
                needs: ['tool'],
              ),
            ),
          ],
          checks: const [
            CheckResult(tool, PreflightMissing(instructions: 'Install it.')),
          ],
        );

        expect(otherModule, isEmpty);
        expect(
          runner.lines,
          containsAllInOrder(['firebase setup', 'fix project']),
        );

        environment = environmentOf(interactive: true, answers: [true]);
        installTools();
        runner.onRun = (call) => call.line == 'fix project'
            ? const SmfProcessResult(exitCode: 2, stderr: 'no phase\n')
            : const SmfProcessResult(exitCode: 0);

        final fails = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: stepsOf(setUp),
        );

        expect(records(fails), [
          'Fix the project: fix project (it exited with code 2)',
          equals(
            'check project: check project (it runs after "Fix the project", '
            'which is not done)',
          ),
        ]);
        expect(fails.map((step) => step.failed), [true, false]);
        expect(
          host.logger.warnings.single,
          'The step "Fix the project" failed: it exited with code 2:\n'
          'no phase',
        );
        expect(runner.lines, containsAllInOrder(['firebase setup', 'tidy']));
      });

      test('that need a terminal are left for later in a run without one',
          () async {
        installTools();

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [
            _step(
              'firebase',
              const PostGenStep(ToolRef('firebase'), ['setup'], id: setUpId),
            ),
            _step(
              'crash',
              const PostGenStep(
                ToolRef('fix'),
                ['project'],
                followUpOf: setUpId,
                interactive: true,
                skippable: true,
              ),
            ),
          ],
        );

        expect(records(skipped), [
          'fix project: fix project (the run cannot ask the user)',
        ]);
        expect(runner.lines, contains('firebase setup'));
      });

      test(
          'that are not skippable stop generation when they fail, as a step '
          'of their own module', () async {
        installTools();
        runner.onRun = (call) => call.line == 'fix project'
            ? const SmfProcessResult(exitCode: 4)
            : const SmfProcessResult(exitCode: 0);

        await expectLater(
          runPostGen(
            directory: '/tmp/app',
            environment: environment,
            steps: [
              _step(
                'firebase',
                const PostGenStep(ToolRef('firebase'), ['setup'], id: setUpId),
              ),
              _step(
                'crash',
                const PostGenStep(
                  ToolRef('fix'),
                  ['project'],
                  followUpOf: setUpId,
                  description: 'Fix the project',
                ),
              ),
            ],
          ),
          throwsA(
            isA<GenerationFailedException>().having(
              (e) => e.message,
              'message',
              'The step "Fix the project" of crash failed: it exited with '
                  'code 4',
            ),
          ),
        );
      });

      test('do not run without the step they continue', () async {
        installTools();

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          // The step of firebase does not apply, so validation left it
          // out.
          steps: stepsOf(setUp).skip(1).toList(),
        );

        expect(skipped, isEmpty);
        expect(runner.lines, isNot(contains(startsWith('fix'))));
        expect(runner.lines, isNot(contains(startsWith('check'))));
        expect(runner.lines, isNot(contains(startsWith('tidy'))));
      });
    });

    group('with a notice', () {
      const setUpId = PostGenStepId(ModuleId('firebase'), 'setup');
      const enableId = PostGenStepId(ModuleId('auth'), 'enable');
      const notice = 'The tool also registers a web app in the project.';
      // It needs no terminal and the app is not complete without it, so no
      // run asks about it.
      const setUp = PostGenStep(
        ToolRef('firebase'),
        ['setup'],
        id: setUpId,
        description: 'Set up Firebase',
      );
      // Steps of a module that depends on firebase, which knows nothing of
      // them.
      const enable = PostGenStep(
        ToolRef('enable'),
        ['methods'],
        id: enableId,
        followUpOf: setUpId,
        description: 'Enable the methods',
        notice: notice,
        skippable: true,
      );
      const verify = PostGenStep(
        ToolRef('verify'),
        [],
        followUpOf: enableId,
        skippable: true,
      );
      const tidy = PostGenStep(
        ToolRef('tidy'),
        [],
        followUpOf: setUpId,
        skippable: true,
      );
      const question =
          'Enable the methods (enable methods), for auth. $notice Run it now?';
      const afterEnable = 'verify: verify (it runs after "Enable the methods", '
          'which is not done)';

      /// [firebase], the step of the module firebase, and the steps of the
      /// module auth: [auth], which continues it and has a notice, the step
      /// that continues [auth], and another that continues [firebase].
      List<Collected> stepsOf(
        PostGenStep firebase, [
        PostGenStep auth = enable,
      ]) =>
          [
            _step('firebase', firebase),
            _step('auth', auth),
            _step('auth', verify),
            _step('auth', tidy),
          ];

      /// Puts the tools of the steps of auth on the PATH.
      void installTools() {
        for (final name in ['enable', 'verify', 'tidy']) {
          host.fileSystem.file('/usr/bin/$name').createSync();
        }
      }

      /// The records of [steps], as `description: command (reason)`.
      List<String> records(List<SkippedStep> steps) =>
          [for (final step in steps) '$step'];

      /// The questions that the run asked.
      List<String> questions() =>
          [for (final prompt in host.prompter.asked) prompt.message];

      test(
          'that continue another step are asked about once that step '
          'succeeded, with the notice in the question, and run when the user '
          'agrees', () async {
        // The user presses Enter, which answers yes, as for every step.
        environment = environmentOf(interactive: true, answers: [null]);
        installTools();

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: stepsOf(setUp),
        );

        expect(skipped, isEmpty);
        expect(questions(), [question]);
        expect(runner.lines.sublist(1, 5), [
          'firebase setup',
          'enable methods',
          'verify',
          'tidy',
        ]);
      });

      test(
          'that the user declines are left for later, and so are the steps '
          'that continue them, while the other steps go on', () async {
        environment = environmentOf(interactive: true, answers: [false]);
        installTools();

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: stepsOf(setUp),
        );

        expect(records(skipped), [
          'Enable the methods: enable methods (you chose to run it later)',
          afterEnable,
        ]);
        // The notice goes with the command for later.
        expect(skipped.map((step) => step.notice), [notice, null]);
        expect(skipped.map((step) => step.failed), everyElement(isFalse));
        expect(questions(), [question]);
        // The step that they continue ran, and so did the other step that
        // continues it.
        expect(runner.lines, containsAllInOrder(['firebase setup', 'tidy']));
        expect(runner.lines, isNot(contains('enable methods')));
        expect(runner.lines, isNot(contains('verify')));
      });

      test(
          'are left for later in a run that cannot ask, after the step that '
          'they continue ran', () async {
        installTools();

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: stepsOf(setUp),
        );

        expect(records(skipped), [
          'Enable the methods: enable methods (the run cannot ask the user)',
          afterEnable,
        ]);
        expect(skipped.map((step) => step.notice), [notice, null]);
        expect(skipped.map((step) => step.failed), everyElement(isFalse));
        expect(runner.lines, containsAllInOrder(['firebase setup', 'tidy']));
        expect(runner.lines, isNot(contains('enable methods')));
        expect(runner.lines, isNot(contains('verify')));
      });

      test(
          'that need external setup are left for later in a run that skips '
          'it, without a question', () async {
        environment = environmentOf(interactive: true, skipExternalSetup: true);
        installTools();

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: stepsOf(
            setUp,
            const PostGenStep(
              ToolRef('enable'),
              ['methods'],
              id: enableId,
              followUpOf: setUpId,
              description: 'Enable the methods',
              notice: notice,
              skippable: true,
              external: true,
            ),
          ),
        );

        expect(records(skipped), [
          'Enable the methods: enable methods (the run skips external setup)',
          afterEnable,
        ]);
        expect(skipped.first.notice, notice);
        expect(questions(), isEmpty);
        expect(runner.lines, containsAllInOrder(['firebase setup', 'tidy']));
        expect(runner.lines, isNot(contains('enable methods')));
      });

      test(
          'are left for later with the step that they continue, without a '
          'question', () async {
        // A step like one that configures an external service in the
        // terminal.
        const configure = PostGenStep(
          ToolRef('firebase'),
          ['setup'],
          id: setUpId,
          description: 'Set up Firebase',
          interactive: true,
          skippable: true,
          external: true,
        );
        const aboutSetUp =
            'Set up Firebase (firebase setup), for firebase. Run it now?';
        for (final (run, exitCode, reason, asked) in [
          (
            () => environmentOf(interactive: true, skipExternalSetup: true),
            0,
            'the run skips external setup',
            const <String>[],
          ),
          (environmentOf, 0, 'the run cannot ask the user', const <String>[]),
          (
            () => environmentOf(interactive: true, answers: [false]),
            0,
            'you chose to run it later',
            const [aboutSetUp],
          ),
          (
            () => environmentOf(interactive: true, answers: [true]),
            1,
            'it exited with code 1',
            const [aboutSetUp],
          ),
        ]) {
          environment = run();
          installTools();
          runner.onInteractive = (call) => exitCode;

          final skipped = await runPostGen(
            directory: '/tmp/app',
            environment: environment,
            steps: stepsOf(configure),
          );

          expect(
            records(skipped),
            [
              'Set up Firebase: firebase setup ($reason)',
              equals(
                'Enable the methods: enable methods (it runs after "Set up '
                'Firebase", which is not done)',
              ),
              afterEnable,
              equals(
                'tidy: tidy (it runs after "Set up Firebase", which is not '
                'done)',
              ),
            ],
            reason: reason,
          );
          expect(
            skipped.map((step) => step.notice),
            [null, notice, null, null],
            reason: reason,
          );
          expect(questions(), asked, reason: reason);
          expect(runner.lines, isNot(contains('enable methods')));
        }
      });

      test(
          'that continue no other step have the notice in the question about '
          'them, and are left for later in a run that cannot ask, which runs '
          'a step without a notice', () async {
        final steps = [
          _step(
            'auth',
            const PostGenStep(
              ToolRef('enable'),
              ['methods'],
              description: 'Enable the methods',
              notice: notice,
              skippable: true,
            ),
          ),
          _step(
            'auth',
            const PostGenStep(ToolRef('tidy'), [], skippable: true),
          ),
        ];
        environment = environmentOf(interactive: true, answers: [true, true]);
        installTools();

        final asked = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: steps,
        );

        expect(asked, isEmpty);
        expect(questions(), [question, 'tidy, for auth. Run it now?']);
        expect(runner.lines, containsAllInOrder(['enable methods', 'tidy']));

        environment = environmentOf();
        installTools();

        final unasked = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: steps,
        );

        expect(records(unasked), [
          'Enable the methods: enable methods (the run cannot ask the user)',
        ]);
        expect(unasked.single.notice, notice);
        expect(unasked.single.failed, isFalse);
        expect(runner.lines, contains('tidy'));
        expect(runner.lines, isNot(contains('enable methods')));
      });

      test(
          'are each asked about in their turn: one that continues a step with '
          'a notice, once the user agreed to that step and it succeeded',
          () async {
        environment = environmentOf(interactive: true, answers: [true, false]);
        installTools();

        final skipped = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [
            _step('firebase', setUp),
            _step('auth', enable),
            _step(
              'auth',
              const PostGenStep(
                ToolRef('verify'),
                [],
                followUpOf: enableId,
                notice: 'It reads the users of the project.',
                skippable: true,
              ),
            ),
          ],
        );

        expect(questions(), [
          question,
          'verify, for auth. It reads the users of the project. Run it now?',
        ]);
        expect(
          records(skipped),
          ['verify: verify (you chose to run it later)'],
        );
        expect(skipped.single.notice, 'It reads the users of the project.');
        expect(
          runner.lines,
          containsAllInOrder(['firebase setup', 'enable methods']),
        );
        expect(runner.lines, isNot(contains('verify')));
      });

      test(
          'that need a check which has not passed are left for later without '
          'a question', () async {
        const needsTool = PostGenStep(
          ToolRef('enable'),
          ['methods'],
          id: enableId,
          followUpOf: setUpId,
          description: 'Enable the methods',
          notice: notice,
          skippable: true,
          needs: ['tool'],
        );
        const missing = [
          CheckResult(
            PlannedCheck(
              _Check('tool', 'Tool'),
              ModuleOrigin(ModuleId('auth')),
            ),
            PreflightMissing(instructions: 'Install it.'),
          ),
        ];
        for (final (interactive, reason, failed) in [
          (true, 'Tool is missing', true),
          // The user who runs the command later needs the tool too.
          (false, 'the run cannot ask the user, and Tool is missing', false),
        ]) {
          environment = environmentOf(interactive: interactive);
          installTools();

          final skipped = await runPostGen(
            directory: '/tmp/app',
            environment: environment,
            steps: stepsOf(setUp, needsTool),
            checks: missing,
          );

          expect(records(skipped), [
            'Enable the methods: enable methods ($reason)',
            afterEnable,
          ]);
          expect(skipped.first.notice, notice);
          expect(skipped.first.failed, failed);
          expect(questions(), isEmpty);
          expect(runner.lines, isNot(contains('enable methods')));
        }
      });

      test(
          'that fail, or whose tool is missing, are left for later as any '
          'step, with their notice', () async {
        environment = environmentOf(interactive: true, answers: [true]);
        installTools();
        runner.onRun = (call) => call.line == 'enable methods'
            ? const SmfProcessResult(exitCode: 2)
            : const SmfProcessResult(exitCode: 0);

        final fails = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: stepsOf(setUp),
        );

        expect(records(fails), [
          'Enable the methods: enable methods (it exited with code 2)',
          afterEnable,
        ]);
        expect(fails.map((step) => step.notice), [notice, null]);
        expect(fails.map((step) => step.failed), [true, false]);
        expect(questions(), [question]);

        // The user is not asked about a step that cannot run.
        environment = environmentOf(interactive: true);
        for (final name in ['verify', 'tidy']) {
          host.fileSystem.file('/usr/bin/$name').createSync();
        }

        final noTool = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: stepsOf(setUp),
        );

        expect(records(noTool), [
          'Enable the methods: enable methods (enable was not found)',
          afterEnable,
        ]);
        expect(noTool.map((step) => step.notice), [notice, null]);
        expect(noTool.map((step) => step.failed), [true, false]);
        expect(questions(), isEmpty);

        // A run that cannot ask leaves the step for later for that reason,
        // whether its tool is there or not: nothing failed.
        environment = environmentOf();
        for (final name in ['verify', 'tidy']) {
          host.fileSystem.file('/usr/bin/$name').createSync();
        }

        final unasked = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: stepsOf(setUp),
        );

        expect(records(unasked), [
          'Enable the methods: enable methods (the run cannot ask the user)',
          afterEnable,
        ]);
        expect(unasked.map((step) => step.notice), [notice, null]);
        expect(unasked.map((step) => step.failed), [false, false]);
      });
    });

    group('for some systems', () {
      const macos = {HostOperatingSystem.macos};
      const setUpId = PostGenStepId(ModuleId('firebase'), 'setup');
      const fix = PostGenStep(
        ToolRef('fix'),
        ['project'],
        followUpOf: setUpId,
        description: 'Fix the project',
        skippable: true,
        hosts: macos,
      );

      /// Puts the tool of [fix] on the PATH.
      void installFix() =>
          host.fileSystem.file('/usr/bin/fix').createSync(recursive: true);

      test(
          'run on those systems and not elsewhere, where they are not left '
          'for later, nor are the steps that continue them', () async {
        final steps = [
          _step(
            'firebase',
            const PostGenStep(
              ToolRef('firebase'),
              ['setup'],
              id: setUpId,
              skippable: true,
              hosts: macos,
            ),
          ),
          _step(
            'crash',
            const PostGenStep(
              ToolRef('firebase'),
              ['check'],
              followUpOf: setUpId,
              skippable: true,
            ),
          ),
        ];

        final elsewhere = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: steps,
        );

        expect(elsewhere, isEmpty);
        expect(runner.lines, isNot(contains(startsWith('firebase'))));

        environment = environmentOf(operatingSystem: HostOperatingSystem.macos);
        final there = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: steps,
        );

        expect(there, isEmpty);
        expect(
          runner.lines,
          containsAllInOrder(['firebase setup', 'firebase check']),
        );
      });

      test(
          'as steps that continue others, run after their step on those '
          'systems, and are not left for later with it elsewhere', () async {
        installFix();
        final steps = [
          _step(
            'firebase',
            const PostGenStep(
              ToolRef('firebase'),
              ['setup'],
              id: setUpId,
              description: 'Set up Firebase',
              skippable: true,
              external: true,
            ),
          ),
          _step('crash', fix),
        ];

        final ran = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: steps,
        );

        expect(ran, isEmpty);
        expect(runner.lines, contains('firebase setup'));
        expect(runner.lines, isNot(contains('fix project')));

        environment = environmentOf(skipExternalSetup: true);
        final held = await runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: steps,
        );

        expect(held.map((step) => '$step'), [
          'Set up Firebase: firebase setup (the run skips external setup)',
        ]);

        for (final skip in [false, true]) {
          environment = environmentOf(
            operatingSystem: HostOperatingSystem.macos,
            skipExternalSetup: skip,
          );
          installFix();

          final skipped = await runPostGen(
            directory: '/tmp/app',
            environment: environment,
            steps: steps,
          );

          if (skip) {
            expect(skipped.map((step) => step.description), [
              'Set up Firebase',
              'Fix the project',
            ]);
          } else {
            expect(skipped, isEmpty);
            expect(
              runner.lines,
              containsAllInOrder(['firebase setup', 'fix project']),
            );
          }
        }
      });
    });

    test('a step that a signal stopped says so', () async {
      environment = environmentOf(interactive: true, answers: [true]);
      runner.onInteractive = (call) => -2;

      final skipped = await runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [_step('firebase', login)],
      );

      expect(skipped.single.reason, 'it was stopped by signal 2');
    });

    test('a negative exit code on Windows is no signal', () async {
      environment = environmentOf(
        interactive: true,
        operatingSystem: HostOperatingSystem.windows,
        answers: [true],
      );
      // STATUS_CONTROL_C_EXIT, 0xC000013A, as a signed 32-bit exit code.
      runner.onInteractive = (call) => -1073741510;

      final skipped = await runPostGen(
        directory: r'C:\tmp\app',
        environment: environment,
        steps: [
          _step(
            'firebase',
            const PostGenStep(
              ToolRef('dart', prefixArgs: ['pub', 'global', 'run', 'x:x']),
              ['login'],
              description: 'Log in',
              interactive: true,
              skippable: true,
              external: true,
            ),
          ),
        ],
      );

      expect(skipped.single.reason, 'it exited with code -1073741510');
    });

    test('a step that is not skippable stops generation when it fails',
        () async {
      environment = environmentOf(interactive: true);
      runner.onInteractive = (call) => 3;

      await expectLater(
        runPostGen(
          directory: '/tmp/app',
          environment: environment,
          steps: [
            _step(
              'firebase',
              const PostGenStep(
                ToolRef('firebase'),
                ['login'],
                interactive: true,
              ),
            ),
          ],
        ),
        throwsA(
          isA<GenerationFailedException>().having(
            (e) => e.message,
            'message',
            'The step "firebase login" of firebase failed: it exited with '
                'code 3',
          ),
        ),
      );
    });
  });

  test('pub get in the place of the app only warns when it is interrupted',
      () async {
    runner.onRun = (call) => throw const SmfCancelledException();

    await getPackagesInPlace(environment, '/work/app');

    expect(
      host.logger.warnings.single,
      'The app is complete, but getting its packages was interrupted; run '
      '"flutter pub get" in it.',
    );
  });

  test('pub get in the place of the app only warns when it fails', () async {
    runner.onRun = (call) => const SmfProcessResult(exitCode: 1);

    await getPackagesInPlace(environment, '/work/app');

    expect(runner.calls.single.workingDirectory, '/work/app');
    expect(
      host.logger.warnings.single,
      startsWith('flutter pub get failed, so run it in the app yourself'),
    );
  });
}

/// A command that could not start, as `Process.run` reports it.
final class ProcessStartFailure implements Exception {
  const ProcessStartFailure(this.message);

  final String message;

  @override
  String toString() => message;
}
