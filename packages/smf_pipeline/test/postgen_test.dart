import 'package:smf_contracts/lego.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A step of [module].
Collected _step(
  String module,
  PostGenStep step,
) =>
    Collected(step, ModuleOrigin(ModuleId(module)), applies: true);

/// The command of the import cleanup.
final cleanup = 'dart fix --apply --code=${importCleanupCodes.join(',')}';

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
      codegen: true,
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
      'dart run build_runner build',
      'firebase --version',
      'dart pub global run x:x go',
      cleanup,
      'dart fix --apply',
      'dart format .',
    ]);
    for (final call in runner.calls) {
      expect(call.workingDirectory, '/tmp/app');
      expect(call.runInShell, isFalse);
      expect(call.environment['PATH'], '/sdk/bin:/sdk/bin:/usr/bin');
    }
    expect(runner.calls.first.executable, '/sdk/bin/flutter');
    expect(runner.calls[2].executable, '/usr/bin/firebase');
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

  test('batch files of the SDK run in a shell on Windows', () async {
    environment = environmentOf(operatingSystem: HostOperatingSystem.windows);
    await runPostGen(
      directory: r'C:\tmp\app',
      environment: environment,
      steps: const [],
    );

    expect(runner.calls.first.executable, r'C:\sdk\bin\flutter.bat');
    expect(runner.calls.every((call) => call.runInShell), isTrue);
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

    runner.onRun = (call) => call.arguments.contains('build_runner')
        ? const SmfProcessResult(exitCode: 1, stdout: 'bad builder')
        : const SmfProcessResult(exitCode: 0);
    await expectLater(
      runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [],
        codegen: true,
      ),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          contains('dart run build_runner build failed'),
        ),
      ),
    );
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
        'firebase use: firebase use (it needs a terminal)',
      ]);
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
      environment = environmentOf(interactive: true, answers: [false]);
      final skipped = await runPostGen(
        directory: '/tmp/app',
        environment: environment,
        steps: [_step('firebase', configure)],
      );

      expect(
        '${skipped.single}',
        'Configure Firebase: flutterfire configure --platforms=android,ios '
            "--out 'lib/my options.dart' (you chose to run it later)",
      );
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
        'it failed: it exited with code 2',
        'it failed: The executable flutterfire was not found.',
      ]);
      expect(host.logger.warnings, [
        'The step "firebase use" failed; run it later: firebase use',
        equals(
          'The step "Configure Firebase" failed; run it later: flutterfire '
          "configure --platforms=android,ios --out 'lib/my options.dart'",
        ),
      ]);
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
