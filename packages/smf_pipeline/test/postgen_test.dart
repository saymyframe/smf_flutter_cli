import 'package:smf_contracts/lego.dart';
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

      test('keep the reasons of the run first', () async {
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

        expect(skipped.single.reason, 'the run skips external setup');
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
