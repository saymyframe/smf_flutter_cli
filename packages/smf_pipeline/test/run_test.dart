import 'package:file/file.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

/// A check that finds its tool missing.
final class _Missing extends PreflightCheck {
  const _Missing();

  @override
  String get id => 'tool';

  @override
  String get description => 'Tool';

  @override
  Future<PreflightStatus> check(SmfEnvironment environment) async =>
      const PreflightMissing(instructions: 'Install the tool.');
}

void main() {
  late RecordingRunner runner;
  late FakeHost host;

  /// The modules of a small app, with [contributions] of a module `extra`.
  List<SmfModule> modulesWith([List<Contribution> contributions = const []]) =>
      [
        scaffold(),
        TestModule('extra', contributions: contributions),
      ];

  CreatePipeline pipeline(List<SmfModule> modules) =>
      CreatePipeline(registry: ModuleRegistry(modules), host: host.host);

  CreateRequest request({
    List<String> modules = const ['extra'],
    OnConflict onConflict = OnConflict.prompt,
    bool explain = false,
    bool dartFix = true,
  }) =>
      CreateRequest(
        appName: 'my_app',
        outputDirectory: '/work',
        modules: [for (final id in modules) ModuleId(id)],
        onConflict: onConflict,
        explain: explain,
        dartFix: dartFix,
        skipExternalSetup: true,
      );

  setUp(() {
    runner = RecordingRunner(
      // `pub get` writes files with the path of the app, as Flutter does.
      onRun: (call) {
        if (call.arguments.contains('get')) {
          host.fileSystem.file('${call.workingDirectory}/.dart_tool/path')
            ..createSync(recursive: true)
            ..writeAsStringSync('${call.workingDirectory}');
        }
        return const SmfProcessResult(exitCode: 0);
      },
    );
    host = FakeHost(processRunner: runner);
  });

  String temporaryOf(RecordedCall call) =>
      host.fileSystem.path.dirname(call.workingDirectory!);

  test('generates the app in a temporary directory and moves it', () async {
    final app = (await pipeline(
      modulesWith([
        const CodegenRequest(),
        const PostGenStep(ToolRef('dart'), ['run', 'tool']),
      ]),
    ).run(request()))!;

    expect(app.name, 'my_app');
    expect(app.path, '/work/my_app');
    expect(app.leftOut, isEmpty);
    expect(app.skippedSteps, isEmpty);
    expect(runner.lines, [
      'flutter pub get',
      'dart run build_runner build --force-jit',
      'dart run tool',
      'dart fix --apply --code=${importCleanupCodes.join(',')}',
      'dart fix --apply',
      'dart format .',
      'flutter pub get',
    ]);
    final temporary = runner.calls.first.workingDirectory!;
    expect(temporary, isNot(startsWith('/work')));
    expect(temporary, endsWith('/my_app'));
    for (final call in runner.calls.take(6)) {
      expect(call.workingDirectory, temporary);
    }
    expect(runner.calls.last.workingDirectory, '/work/my_app');

    final files = host.fileSystem;
    expect(files.file('/work/my_app/lib/main.dart').existsSync(), isTrue);
    expect(
      files.file('/work/my_app/pubspec.yaml').readAsStringSync(),
      contains('build_runner: "^2.10.0"'),
    );
    // Written again by pub get in the app's place, not moved.
    expect(
      files.file('/work/my_app/.dart_tool/path').readAsStringSync(),
      '/work/my_app',
    );
    expect(
      files.directory(temporaryOf(runner.calls.first)).existsSync(),
      isFalse,
    );
  });

  test('--no-dart-fix leaves out the full dart fix only', () async {
    await pipeline(modulesWith()).run(request(dartFix: false));

    expect(runner.lines, [
      'flutter pub get',
      'dart fix --apply --code=${importCleanupCodes.join(',')}',
      'dart format .',
      'flutter pub get',
    ]);
  });

  test('lists the steps that did not run', () async {
    final app = await pipeline(
      modulesWith([
        const PostGenStep(
          ToolRef('firebase'),
          ['login'],
          description: 'Log in',
          external: true,
          skippable: true,
        ),
      ]),
    ).run(request());

    expect(
      app!.skippedSteps.map((step) => '$step'),
      ['Log in: firebase login (the run skips external setup)'],
    );
  });

  test('leaves a step for later when a check it needs did not pass', () async {
    final app = await pipeline(
      modulesWith([
        const Preflight([_Missing()]),
        const PostGenStep(
          ToolRef('tool'),
          ['go'],
          description: 'Go',
          skippable: true,
          needs: ['tool'],
        ),
      ]),
    ).run(request());

    expect(
      app!.skippedSteps.map((step) => '$step'),
      ['Go: tool go (Tool is missing)'],
    );
    expect(runner.lines, isNot(contains(startsWith('tool'))));
  });

  test('replaces the directory of the app when asked to', () async {
    host.fileSystem.file('/work/my_app/old.txt').createSync(recursive: true);

    final app = await pipeline(modulesWith())
        .run(request(onConflict: OnConflict.replace));

    expect(app!.path, '/work/my_app');
    expect(host.fileSystem.file('/work/my_app/old.txt').existsSync(), isFalse);
    expect(
      host.fileSystem.file('/work/my_app/lib/main.dart').existsSync(),
      isTrue,
    );
  });

  test('keeps the app in the temporary directory when a step fails', () async {
    runner.onRun = (call) => call.arguments.first == 'pub'
        ? const SmfProcessResult(exitCode: 69, stderr: 'offline')
        : const SmfProcessResult(exitCode: 0);

    late GenerationFailedException failure;
    try {
      await pipeline(modulesWith()).run(request());
      fail('The generation succeeded.');
    } on GenerationFailedException catch (error) {
      failure = error;
    }

    final kept = runner.calls.single.workingDirectory!;
    expect(
      failure.message,
      'flutter pub get failed: it exited with code 69:\noffline\n'
      'The app so far is in $kept.',
    );
    expect(host.fileSystem.file('$kept/lib/main.dart').existsSync(), isTrue);
    expect(host.fileSystem.directory('/work/my_app').existsSync(), isFalse);
  });

  test('a run the user cancels leaves nothing behind', () async {
    host.fileSystem.directory('/work/my_app/old').createSync(recursive: true);
    final temporary = host.fileSystem.systemTempDirectory;
    final before = temporary.listSafely().length;
    runner.onRun = (call) => throw const SmfCancelledException();

    await expectLater(
      pipeline(modulesWith()).run(request(onConflict: OnConflict.replace)),
      throwsA(isA<SmfCancelledException>()),
    );
    expect(temporary.listSafely(), hasLength(before));
    expect(
      host.fileSystem.directory('/work/my_app/old').existsSync(),
      isTrue,
    );
    expect(host.logger.warnings, [
      '/work/my_app will be replaced once the app has been generated.',
    ]);
  });

  test('an interrupted pub get in the place of the app still creates it',
      () async {
    final onRun = runner.onRun!;
    runner.onRun = (call) => call.workingDirectory == '/work/my_app'
        ? throw const SmfCancelledException()
        : onRun(call);

    final app = await pipeline(modulesWith()).run(request());

    expect(app?.path, '/work/my_app');
    expect(host.logger.warnings.single, contains('was interrupted'));
    expect(
      host.fileSystem.file('/work/my_app/lib/main.dart').existsSync(),
      isTrue,
    );
  });

  test('a directory that appears meanwhile keeps the app where it is',
      () async {
    final onRun = runner.onRun!;
    runner.onRun = (call) {
      host.fileSystem.file('/work/my_app/mine.txt').createSync(recursive: true);
      return onRun(call);
    };

    await expectLater(
      pipeline(modulesWith()).run(request()),
      throwsA(
        isA<GenerationFailedException>().having(
          (e) => e.message,
          'message',
          allOf(
            startsWith('/work/my_app appeared while the app was being '
                'generated, so the app stays in '),
            isNot(contains('The app so far')),
          ),
        ),
      ),
    );
    expect(
      host.fileSystem.directory('/work/my_app').listSync().single.path,
      '/work/my_app/mine.txt',
    );
  });

  test('an unexpected error after rendering says where the app is', () async {
    host = FakeHost(processRunner: runner, terminal: true);

    await expectLater(
      pipeline(
        modulesWith([
          const PostGenStep(ToolRef('dart'), ['run', 'x'], skippable: true),
        ]),
      ).run(
        const CreateRequest(
          appName: 'my_app',
          org: 'com.example',
          outputDirectory: '/work',
          modules: [ModuleId('extra')],
        ),
      ),
      // The prompter has no answer for the step.
      throwsA(isA<StateError>()),
    );

    final kept = runner.calls.first.workingDirectory!;
    expect(host.logger.warnings.last, 'The app so far is in $kept.');
    expect(host.fileSystem.file('$kept/lib/main.dart').existsSync(), isTrue);
  });

  test('--explain generates nothing', () async {
    expect(await pipeline(modulesWith()).run(request(explain: true)), isNull);

    expect(runner.calls, isEmpty);
    expect(host.fileSystem.directory('/work/my_app').existsSync(), isFalse);
  });

  test('an app that cannot be rendered leaves nothing behind', () async {
    final temporary = host.fileSystem.systemTempDirectory;
    final before = temporary.listSafely().length;

    await expectLater(
      pipeline(
        modulesWith([
          BrickContribution(bundle('broken', files: {'lib/b.dart': '{{a}}'})),
        ]),
      ).run(request()),
      throwsA(isA<GenerationFailedException>()),
    );
    expect(temporary.listSafely(), hasLength(before));
    expect(runner.calls, isEmpty);
  });
}

extension on Directory {
  /// The entities in the directory, which may not exist.
  List<FileSystemEntity> listSafely() =>
      existsSync() ? listSync(recursive: true) : const [];
}
