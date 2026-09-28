import 'package:smf_contracts/core.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _MissingTool extends PreflightCheck {
  const _MissingTool();

  @override
  String get id => 'tool';

  @override
  String get description => 'A tool';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    final path = await environment.findExecutable('tool');
    return path == null
        ? const PreflightMissing(instructions: 'Install the tool.')
        : const PreflightPassed();
  }
}

void main() {
  test('SmfProcessResult succeeds on exit code 0', () {
    const result = SmfProcessResult(exitCode: 0);

    expect(result.succeeded, isTrue);
    expect(result.stdout, isEmpty);
    expect(result.stderr, isEmpty);
    expect(
      const SmfProcessResult(exitCode: 1, stderr: 'boom').succeeded,
      isFalse,
    );
    expect(result.timedOut, isFalse);
  });

  test('SmfProcessResult of a command stopped at its timeout did not succeed',
      () {
    // Whatever its exit code once stopped.
    const stopped =
        SmfProcessResult(exitCode: 0, stdout: 'so far', timedOut: true);

    expect(stopped.timedOut, isTrue);
    expect(stopped.succeeded, isFalse);
    expect(stopped.stdout, 'so far');
  });

  test('SmfCancelledException says that the user cancelled the run', () {
    expect(
      '${const SmfCancelledException()}',
      'SmfCancelledException: the user cancelled the run.',
    );
  });

  test('ToolRef puts its prefix arguments first', () {
    const flutterfire = ToolRef(
      'dart',
      prefixArgs: ['pub', 'global', 'run', 'flutterfire_cli:flutterfire'],
      environment: {'CI': 'true'},
    );

    expect(flutterfire.executable, 'dart');
    expect(flutterfire.environment, {'CI': 'true'});
    expect(flutterfire.argumentsFor(['configure']), [
      'pub',
      'global',
      'run',
      'flutterfire_cli:flutterfire',
      'configure',
    ]);
    expect(const ToolRef('flutter').argumentsFor(['pub', 'get']), [
      'pub',
      'get',
    ]);
  });

  group('PreflightCheck', () {
    test('is optional and cannot install by default', () async {
      const check = _MissingTool();
      final environment = FakeEnvironment();

      expect(check.required, isFalse);
      final status = await check.check(environment);
      expect(
        status,
        isA<PreflightMissing>()
            .having((s) => s.instructions, 'instructions', 'Install the tool.')
            .having((s) => s.installable, 'installable', isFalse),
      );
      expect(() => check.install(environment), throwsUnsupportedError);
    });
  });

  test('preflight statuses describe the result', () {
    const failed = PreflightFailed('The tool crashed.');
    const missing = PreflightMissing(instructions: 'Run x.', installable: true);
    const older = PreflightMissing(
      instructions: 'Update x.',
      found: 'x 1.0.0 is active',
    );

    expect(failed.message, 'The tool crashed.');
    expect(missing.installable, isTrue);
    expect(missing.found, isNull);
    expect(older.found, 'x 1.0.0 is active');
    expect(older.installable, isFalse);
    expect(const PreflightPassed(), isA<PreflightStatus>());
  });

  test('ToolInstall reports where the tool is', () {
    const nothing = ToolInstall();
    const firebase = ToolInstall(
      binDirs: ['/usr/local/lib/node_modules/.bin'],
      tool: ToolRef('/usr/local/bin/firebase'),
    );

    expect(nothing.binDirs, isEmpty);
    expect(nothing.tool, isNull);
    expect(firebase.binDirs, hasLength(1));
    expect(firebase.tool?.executable, '/usr/local/bin/firebase');
  });

  test('the fake environment is a complete SmfEnvironment', () async {
    final environment = FakeEnvironment(interactive: true);

    expect(environment.interactive, isTrue);
    expect(environment.skipExternalSetup, isFalse);
    expect(environment.operatingSystem, HostOperatingSystem.linux);
    expect(await environment.writeTempFile('a.sh', ''), '/tmp/a.sh');
    expect(() => environment.processRunner, throwsUnimplementedError);
    expect(() => environment.prompter, throwsUnimplementedError);
    expect(() => environment.logger, throwsUnimplementedError);
  });
}
