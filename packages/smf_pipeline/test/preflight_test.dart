import 'package:smf_contracts/lego_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

const _module = ModuleOrigin(ModuleId('firebase'));

const _missing = PreflightMissing(
  instructions: 'Run npm install -g firebase-tools.',
  installable: true,
);

void main() {
  group('the Flutter SDK check', () {
    test('finds flutter and the dart next to it', () async {
      final host = FakeHost();
      host.fileSystem.file('/other/dart').createSync(recursive: true);
      final check = FlutterSdkCheck();

      final status = await check.check(host.environment());

      expect(status, isA<PreflightPassed>());
      expect(check.found!.flutter, '/sdk/bin/flutter');
      expect(check.found!.dart, '/sdk/bin/dart');
      expect(check.id, 'flutter_sdk');
      expect(check.description, 'Flutter SDK');
      expect(check.required, isTrue);
    });

    test('falls back to the dart on the PATH', () async {
      final host = FakeHost(
        flutter: false,
        environment: {
          'PATH': '/flutter/bin:/dart/bin',
        },
      );
      host.fileSystem.file('/flutter/bin/flutter').createSync(recursive: true);
      host.fileSystem.file('/dart/bin/dart').createSync(recursive: true);
      final check = FlutterSdkCheck();

      await check.check(host.environment());

      expect(check.found!.dart, '/dart/bin/dart');
    });

    test('reports a missing flutter or dart', () async {
      final noFlutter = FlutterSdkCheck();
      expect(
        await noFlutter.check(FakeHost(flutter: false).environment()),
        isA<PreflightMissing>(),
      );
      expect(noFlutter.found, isNull);

      final host = FakeHost(flutter: false);
      host.fileSystem.file('/sdk/bin/flutter').createSync(recursive: true);
      final noDart = FlutterSdkCheck();
      final status = await noDart.check(host.environment());
      expect(
        (status as PreflightMissing).instructions,
        contains('has no dart'),
      );
    });

    test('on Windows takes dart.bat', () async {
      final host = FakeHost(operatingSystem: HostOperatingSystem.windows);
      final check = FlutterSdkCheck();

      await check.check(host.environment());

      expect(check.found!.flutter, r'C:\sdk\bin\flutter.bat');
      expect(check.found!.dart, r'C:\sdk\bin\dart.bat');
    });
  });

  group('runPreflight', () {
    test('passes checks that pass', () async {
      final host = FakeHost();
      final check = TestCheck('tool', status: const PreflightPassed());

      final report = await runPreflight(
        [PlannedCheck(check, _module)],
        host.environment(),
      );

      expect(report.issues, isEmpty);
      expect(report.results.single.passed, isTrue);
      expect(host.logger.details, ['✓ Tool tool']);
    });

    test('installs after the user agrees, and adds its directories', () async {
      final host = FakeHost(answers: [true], terminal: true);
      final environment = host.environment();
      final check = TestCheck(
        'firebase_cli',
        status: _missing,
        afterInstall: const PreflightPassed(),
        binDirs: ['/npm/bin'],
      );

      final report = await runPreflight(
        [PlannedCheck(check, _module)],
        environment,
      );

      expect(check.installs, 1);
      expect(check.checks, 2);
      expect(report.results.single.installed, isTrue);
      expect(report.results.single.passed, isTrue);
      expect(report.issues, isEmpty);
      expect(environment.binDirs, ['/npm/bin']);
      expect(
        host.prompter.asked.single.message,
        'Tool firebase_cli is missing (needed by firebase). Install it now?',
      );
    });

    test('does not install when the user declines', () async {
      final host = FakeHost(answers: [false], terminal: true);
      final check = TestCheck('firebase_cli', status: _missing);

      final report = await runPreflight(
        [PlannedCheck(check, _module)],
        host.environment(),
      );

      expect(check.installs, 0);
      expect(report.issues.single.isError, isFalse);
      expect(
        report.issues.single.message,
        'Tool firebase_cli is missing. Run npm install -g firebase-tools.',
      );
      expect(report.issues.single.origin, _module);
    });

    test('only prints instructions without a terminal', () async {
      final host = FakeHost();
      final check = TestCheck('firebase_cli', status: _missing);

      final report = await runPreflight(
        [PlannedCheck(check, _module)],
        host.environment(),
      );

      expect(check.installs, 0);
      expect(host.prompter.asked, isEmpty);
      expect(report.issues, hasLength(1));
    });

    test('never installs with --skip-external-setup or --explain', () async {
      for (final (skip, explain) in [(true, false), (false, true)]) {
        final host = FakeHost(terminal: true);
        final check = TestCheck('firebase_cli', status: _missing);

        await runPreflight(
          [PlannedCheck(check, _module)],
          host.environment(skipExternalSetup: skip),
          explain: explain,
        );

        expect(check.installs, 0);
        expect(host.prompter.asked, isEmpty);
      }
    });

    test('a failed required check is an error; the pipeline has no origin',
        () async {
      final host = FakeHost();
      final report = await runPreflight(
        [
          PlannedCheck(
            TestCheck(
              'login',
              status: const PreflightFailed('no network'),
              required: true,
            ),
            _module,
          ),
          PlannedCheck(
            TestCheck('sdk', status: _missing, required: true),
            const PipelineOrigin(),
          ),
        ],
        host.environment(),
      );

      expect(report.issues.map((issue) => issue.isError), [true, true]);
      expect(
        report.issues.first.message,
        'Tool login could not be checked: no network',
      );
      expect(report.issues.first.origin, _module);
      expect(report.issues.last.origin, isNull);
    });

    test('a check or an installation that throws fails', () async {
      final host = FakeHost(answers: [true], terminal: true);
      final report = await runPreflight(
        [
          PlannedCheck(_ThrowingCheck(installs: true), _module),
        ],
        host.environment(),
      );

      expect(
        report.issues.single.message,
        contains('The installation failed: Bad state: no npm'),
      );

      final checkFails = await runPreflight(
        [PlannedCheck(_ThrowingCheck(), _module)],
        FakeHost().environment(),
      );
      expect(checkFails.issues.single.message, contains('cannot check'));
    });

    test('skips checks that passed before and remembers new ones', () async {
      final host = FakeHost();
      final old = TestCheck('old', status: _missing);
      final fresh = TestCheck('fresh', status: const PreflightPassed());
      final passed = {'firebase/old'};

      final report = await runPreflight(
        [PlannedCheck(old, _module), PlannedCheck(fresh, _module)],
        host.environment(),
        passed: passed,
      );

      expect(old.checks, 0);
      expect(report.issues, isEmpty);
      expect(passed, {'firebase/old', 'firebase/fresh'});
    });
  });

  test('plannedChecks puts the SDK first, then the modules in order', () {
    final first = TestCheck('a', status: const PreflightPassed());
    final second = TestCheck('b', status: const PreflightPassed());
    final sdk = FlutterSdkCheck();
    final collection = Collection([
      Collected(Preflight([first, second]), _module, applies: true),
      Collected(
        Preflight([TestCheck('c', status: _missing)]),
        _module,
        applies: false,
      ),
    ]);

    final planned = plannedChecks(collection, sdk);

    expect(planned.map((p) => p.check), [sdk, first, second]);
    expect(planned.map((p) => p.key), [
      'pipeline/flutter_sdk',
      'firebase/a',
      'firebase/b',
    ]);
  });
}

final class _ThrowingCheck extends PreflightCheck {
  _ThrowingCheck({this.installs = false});

  final bool installs;

  @override
  String get id => 'throwing';

  @override
  String get description => 'Throwing';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    if (installs) {
      return const PreflightMissing(instructions: 'Install', installable: true);
    }
    throw StateError('cannot check');
  }

  @override
  Future<ToolInstall> install(SmfEnvironment environment) async =>
      throw StateError('no npm');
}
