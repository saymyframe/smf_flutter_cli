import 'package:pub_semver/pub_semver.dart';
import 'package:smf_contracts/lego_core.dart';
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
      final check = FlutterSdkCheck(host.fileSystem);

      final status = await check.check(host.environment());

      expect(status, isA<PreflightPassed>());
      expect(check.found!.flutter, '/sdk/bin/flutter');
      expect(check.found!.dart, '/sdk/bin/dart');
      expect(check.id, 'flutter_sdk');
      expect(check.description, 'Flutter SDK');
      expect(check.required, isTrue);
    });

    test('follows a link to flutter, not another dart on the PATH', () async {
      final host = FakeHost(
        flutter: false,
        environment: {
          'PATH': '/usr/local/bin',
        },
      );
      final fs = host.fileSystem;
      fs.file('/opt/flutter/bin/flutter').createSync(recursive: true);
      fs.file('/opt/flutter/bin/dart').createSync();
      fs.directory('/opt/flutter/bin/internal').createSync();
      fs.directory('/usr/local/bin').createSync(recursive: true);
      fs.link('/usr/local/bin/flutter').createSync('/opt/flutter/bin/flutter');
      fs.file('/usr/local/bin/dart').createSync();
      final check = FlutterSdkCheck(fs);

      await check.check(host.environment());

      expect(check.found!.flutter, '/usr/local/bin/flutter');
      expect(check.found!.dart, '/opt/flutter/bin/dart');
    });

    test('asks a launcher of flutter for its SDK', () async {
      final runner = ScriptedProcessRunner({
        '/snap/bin/flutter': const SmfProcessResult(
          exitCode: 0,
          stdout: 'Waiting for another command...\n'
              '{"flutterRoot": "/home/me/snap/flutter/common/flutter"}',
        ),
      });
      final host = FakeHost(
        flutter: false,
        environment: {'PATH': '/snap/bin:/usr/bin'},
        processRunner: runner,
      );
      final fs = host.fileSystem;
      // The snap links every app to its launcher, next to which may lie a
      // dart of another SDK.
      fs.file('/usr/bin/snap').createSync(recursive: true);
      fs.file('/usr/bin/dart').createSync();
      fs.directory('/snap/bin').createSync(recursive: true);
      fs.link('/snap/bin/flutter').createSync('/usr/bin/snap');
      fs
          .file('/home/me/snap/flutter/common/flutter/bin/dart')
          .createSync(recursive: true);
      fs
          .directory('/home/me/snap/flutter/common/flutter/bin/cache/dart-sdk')
          .createSync(recursive: true);
      final check = FlutterSdkCheck(fs);

      await check.check(host.environment());

      expect(
        runner.calls.single,
        ['/snap/bin/flutter', '--version', '--machine'],
      );
      expect(
        check.found!.dart,
        '/home/me/snap/flutter/common/flutter/bin/dart',
      );
      expect(check.launcher, isNull);

      final explaining = FlutterSdkCheck(fs, explain: true);
      expect(
        await explaining.check(host.environment()),
        isA<PreflightPassed>(),
      );
      expect(explaining.launcher, '/snap/bin/flutter');
      expect(explaining.found, isNull);
      expect(runner.calls, hasLength(1));
    });

    test('reports a missing flutter or dart', () async {
      final none = FakeHost(flutter: false);
      final noFlutter = FlutterSdkCheck(none.fileSystem);
      expect(
        await noFlutter.check(none.environment()),
        isA<PreflightMissing>(),
      );
      expect(noFlutter.found, isNull);

      for (final result in [
        const SmfProcessResult(exitCode: 1),
        const SmfProcessResult(exitCode: 0, stdout: 'no json'),
        const SmfProcessResult(exitCode: 0, stdout: '{"flutterRoot": 1}'),
        const SmfProcessResult(exitCode: 0, stdout: '{broken'),
        const SmfProcessResult(exitCode: 0, stdout: '{"flutterRoot": "/x"}'),
      ]) {
        final host = FakeHost(
          flutter: false,
          processRunner: ScriptedProcessRunner({'/sdk/bin/flutter': result}),
        );
        host.fileSystem.file('/sdk/bin/flutter').createSync(recursive: true);
        host.fileSystem.file('/usr/bin/dart').createSync(recursive: true);
        final check = FlutterSdkCheck(host.fileSystem);
        final status = await check.check(host.environment());
        expect(
          (status as PreflightMissing).instructions,
          contains('has no dart'),
          reason: result.stdout,
        );
      }
    });

    test('reads the versions the SDK records', () async {
      final host = FakeHost();
      host.fileSystem.file('/sdk/bin/cache/flutter.version.json')
        ..createSync(recursive: true)
        ..writeAsStringSync(
          '{"flutterVersion": "3.44.2", "dartSdkVersion": "3.12.2 (stable)"}',
        );
      final check = FlutterSdkCheck(host.fileSystem);

      await check.check(host.environment());

      expect(check.found!.flutterVersion, '3.44.2');
      expect(check.found!.dartVersion, '3.12.2');

      host.fileSystem
          .file('/sdk/bin/cache/flutter.version.json')
          .writeAsStringSync('[]');
      await check.check(host.environment());
      expect(check.found!.flutterVersion, isNull);
    });

    test('compares the versions with the constraints of the pubspec', () {
      const sdk = FlutterSdk(
        flutter: '/f/flutter',
        dart: '/f/dart',
        flutterVersion: '3.44.2',
        dartVersion: '3.12.2',
      );

      expect(
        sdkVersionIssues(
          sdk,
          MergedPubspec(
            sdk: VersionConstraint.parse('^3.8.0'),
            flutter: VersionConstraint.parse('>=3.32.0'),
          ),
        ),
        isEmpty,
      );
      final issues = sdkVersionIssues(
        sdk,
        MergedPubspec(
          sdk: VersionConstraint.parse('^3.13.0'),
          flutter: VersionConstraint.parse('>=3.47.0'),
          sdkOrigins: const [_module],
          flutterOrigins: const [_module, ModuleOrigin(ModuleId('other'))],
        ),
      );
      expect(issues.map((issue) => issue.message), [
        equals(
          'firebase needs Dart ^3.13.0, but the Flutter SDK at /f/flutter has '
          'Dart 3.12.2.',
        ),
        equals(
          'firebase, other need Flutter >=3.47.0, but the Flutter SDK at '
          '/f/flutter has Flutter 3.44.2.',
        ),
      ]);
      // One module's constraint is its problem; lenient mode can drop it.
      expect(issues.first.origin, _module);
      expect(issues.first.hint, 'Upgrade Flutter, or leave out firebase.');
      expect(issues.last.origin, isNull);
      expect(
        sdkVersionIssues(
          sdk,
          MergedPubspec(sdk: VersionConstraint.parse('^3.13.0')),
        ).single.message,
        startsWith('The app needs Dart'),
      );
      expect(sdkVersionIssues(null, const MergedPubspec()), isEmpty);
      expect(
        sdkVersionIssues(
          const FlutterSdk(flutter: 'f', dart: 'd', dartVersion: 'dev'),
          MergedPubspec(sdk: VersionConstraint.parse('^3.8.0')),
        ),
        isEmpty,
      );
    });

    test('on Windows takes dart.bat', () async {
      final host = FakeHost(operatingSystem: HostOperatingSystem.windows);
      final check = FlutterSdkCheck(host.fileSystem);

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

    test('checks after the SDK check find the SDK', () async {
      final host = FakeHost();
      final environment = host.environment();
      final sdk = FlutterSdkCheck(host.fileSystem);
      String? dart;
      final probe = _Probe((environment) async {
        dart = await environment.findExecutable('dart');
      });

      await runPreflight(
        [
          PlannedCheck(sdk, const PipelineOrigin()),
          PlannedCheck(probe, _module),
        ],
        environment,
      );

      expect(environment.sdk, same(sdk.found));
      expect(dart, '/sdk/bin/dart');
    });

    test('installs nothing when generation cannot go on', () async {
      for (final (strict, origin) in [
        (false, const PipelineOrigin() as ContributionOrigin),
        (true, _module as ContributionOrigin),
      ]) {
        final host = FakeHost(terminal: true);
        final cli = TestCheck('cli', status: _missing);
        final report = await runPreflight(
          [
            PlannedCheck(
              TestCheck(
                'sdk',
                status: const PreflightMissing(instructions: 'Get it.'),
                required: true,
              ),
              origin,
            ),
            PlannedCheck(cli, const ModuleOrigin(ModuleId('other'))),
          ],
          host.environment(),
          strict: strict,
        );

        expect(host.prompter.asked, isEmpty);
        expect(cli.installs, 0);
        expect(report.issues, hasLength(2));
      }
    });

    test('offers no installation to a module lenient mode leaves out',
        () async {
      final host = FakeHost(answers: [true], terminal: true);
      final doomedTool = TestCheck('tool', status: _missing);
      final otherTool = TestCheck(
        'tool',
        status: _missing,
        afterInstall: const PreflightPassed(),
      );
      await runPreflight(
        [
          PlannedCheck(
            TestCheck(
              'needed',
              status: const PreflightFailed('broken'),
              required: true,
            ),
            _module,
          ),
          PlannedCheck(doomedTool, _module),
          PlannedCheck(otherTool, const ModuleOrigin(ModuleId('other'))),
        ],
        host.environment(),
      );

      expect(doomedTool.installs, 0);
      expect(otherTool.installs, 1);
      expect(host.prompter.asked.single.message, contains('needed by other'));
    });

    test('checks again what comes after an installation', () async {
      final host = FakeHost(answers: [true], terminal: true);
      final cli = TestCheck(
        'cli',
        status: _missing,
        afterInstall: const PreflightPassed(),
      );
      final login = TestCheck(
        'login',
        status: const PreflightFailed('no firebase'),
        required: true,
      );

      final report = await runPreflight(
        [PlannedCheck(cli, _module), PlannedCheck(login, _module)],
        host.environment(),
      );

      // A required check after an installable one is not doomed: the
      // installation may fix it.
      expect(cli.installs, 1);
      expect(login.checks, 2);
      expect(report.issues.single.message, contains('no firebase'));
    });

    test('installs nothing when the SDK is too old for the app', () async {
      final host = FakeHost(terminal: true);
      host.fileSystem.file('/sdk/bin/cache/flutter.version.json')
        ..createSync(recursive: true)
        ..writeAsStringSync('{"dartSdkVersion": "3.0.0"}');
      final cli = TestCheck('cli', status: _missing);

      final report = await runPreflight(
        [
          PlannedCheck(
            FlutterSdkCheck(host.fileSystem),
            const PipelineOrigin(),
          ),
          PlannedCheck(cli, _module),
        ],
        host.environment(),
        pubspec: MergedPubspec(sdk: VersionConstraint.parse('^3.8.0')),
      );

      expect(cli.installs, 0);
      expect(host.prompter.asked, isEmpty);
      expect(report.versionIssues.single.message, contains('Dart ^3.8.0'));
      expect(report.issues, containsAll(report.versionIssues));
    });

    test('reuses known results, so the user is asked once', () async {
      final host = FakeHost(answers: [false], terminal: true);
      final environment = host.environment();
      final declined = TestCheck('cli', status: _missing);
      final fresh = TestCheck('fresh', status: const PreflightPassed());
      final known = <String, CheckResult>{};
      final checks = [
        PlannedCheck(declined, _module),
        PlannedCheck(fresh, _module),
      ];

      final first = await runPreflight(checks, environment, known: known);
      final second = await runPreflight(checks, environment, known: known);

      expect(host.prompter.asked, hasLength(1));
      expect(declined.checks, 1);
      expect(fresh.checks, 1);
      expect(known.keys, {'firebase/cli', 'firebase/fresh'});
      expect(second.issues.single.message, first.issues.single.message);
      expect(second.issues.single.isError, isFalse);
    });
  });

  test('plannedChecks puts the SDK first, then the modules in order', () {
    final first = TestCheck('a', status: const PreflightPassed());
    final second = TestCheck('b', status: const PreflightPassed());
    final sdk = FlutterSdkCheck(FakeHost().fileSystem);
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

final class _Probe extends PreflightCheck {
  _Probe(this._probe);

  final Future<void> Function(SmfEnvironment environment) _probe;

  @override
  String get id => 'probe';

  @override
  String get description => 'Probe';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async {
    await _probe(environment);
    return const PreflightPassed();
  }
}
