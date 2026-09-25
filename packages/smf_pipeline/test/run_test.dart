import 'package:file/file.dart';
import 'package:smf_contracts/lego.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

import 'support.dart';

void main() {
  late RecordingRunner runner;
  late FakeHost host;

  /// The modules of a small app, with [contributions] of a module `extra`.
  List<SmfModule> modulesWith([List<Contribution> contributions = const []]) =>
      [
        scaffold(contributions: [entryBrick()]),
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
      'dart run build_runner build',
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
      contains('build_runner: "^2.7.0"'),
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
          BrickContribution(bundle('broken', files: {'lib/b.dart': '{{#a}}'})),
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
