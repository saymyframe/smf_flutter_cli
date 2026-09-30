// Tests --add-app-tests of tool/matrix.dart, which CI runs in the jobs
// that start an app with every module on a device: with --app, the tool
// adds the start check to the app that --create --app generated as the app
// of that name, with the probes of the tests of the roles of the app and
// the files that those tests generate for it.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/matrix_app_tests.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:test/test.dart';

void main() {
  late Directory temp;
  late String kernel;
  late String packages;
  late List<MatrixAppTest> appTests;

  // The kernel of the tool, compiled once for the runs of the tests.
  setUpAll(() async {
    temp = Directory.systemTemp.createTempSync('matrix_tool_');
    kernel = p.join(temp.path, 'matrix.dill');
    packages = (await Isolate.packageConfig)!.toFilePath();
    appTests = (await smfAppTests()).tests;
    final result = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      '--packages=$packages',
      p.join('tool', 'matrix.dart'),
      '-o',
      kernel,
    ]);
    if (result.exitCode != 0) {
      throw StateError('The tool does not compile: ${result.stderr}');
    }
  });
  tearDownAll(() => temp.deleteSync(recursive: true));

  Future<ProcessResult> run(List<String> arguments) => Process.run(
        Platform.resolvedExecutable,
        ['--packages=$packages', kernel, ...arguments],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

  /// The directory of a new app of `smf create` whose package is
  /// start_app, as far as the tool reads it.
  String newApp() {
    final app = temp.createTempSync('start_app_');
    File(p.join(app.path, 'pubspec.yaml')).writeAsStringSync(
      'name: start_app\n',
    );
    return app.path;
  }

  /// The text of the file at [path] of the app in [app].
  String read(String app, String path) =>
      File(p.joinAll([app, ...path.split('/')])).readAsStringSync();

  /// The app test whose files are in the directory [name].
  MatrixAppTest named(String name) =>
      appTests.singleWhere((test) => p.basename(test.directory) == name);

  test(
      'with --app, adds the start check to the app with every module of '
      'that name, one without the modules whose steps need an external '
      'service with --without-external-steps, with the probes of the tests '
      'of its roles and the files that they generate for it', () async {
    final generated = <bool, Map<String, String>>{};
    for (final withoutExternalSteps in [true, false]) {
      final (:apps, :failed) = await everyModuleAppsOf(
        smfModules,
        withoutExternalSteps: withoutExternalSteps,
      );
      expect(failed, isEmpty);
      final matrixApp = apps.last;
      final app = newApp();

      final result = await run([
        '--add-app-tests',
        if (withoutExternalSteps) '--without-external-steps',
        '--app',
        matrixApp.name,
        app,
        named('start').directory,
      ]);

      final reason = '${matrixApp.name}: ${result.stdout}${result.stderr}';
      expect(result.exitCode, 0, reason: reason);
      expect(
        read(app, 'integration_test/start_check.dart'),
        contains("import 'package:start_app/main.dart' as app;"),
      );
      final list = read(app, startProbesFile);
      expect(list, contains("('di_role', probe0.probeServices),"));
      expect(list, contains("('router_walk', probe1.probeRoutes),"));
      final files = generated[withoutExternalSteps] = {
        for (final test in [named('di_role'), named('router_walk')])
          ...test.generatedFiles!(matrixApp, 'start_app'),
      };
      for (final MapEntry(key: path, value: text) in files.entries) {
        expect(read(app, path), text, reason: '$path of ${matrixApp.name}');
      }
    }
    // The modules whose steps need an external service register services
    // of their own, so the files of the two apps tell them apart.
    expect(
      generated[true]![registeredServicesFile],
      isNot(generated[false]![registeredServicesFile]),
    );
  });

  test(
      'without --app, adds the start check without probes, and fails on '
      'tests that generate files for an app of the matrix', () async {
    final app = newApp();

    final start = await run(['--add-app-tests', app, named('start').directory]);

    expect(start.exitCode, 0, reason: '${start.stdout}${start.stderr}');
    expect(read(app, startProbesFile), contains('startProbes = [\n];\n'));

    final walk = named('router_walk');
    final result = await run(['--add-app-tests', newApp(), walk.directory]);

    expect(result.exitCode, 1);
    expect(
      '${result.stdout}',
      contains(
        'The tests of ${walk.directory} generate files for an app of the '
        'matrix, but the app is none.',
      ),
    );
  });

  test(
      'fails on --without-external-steps without --app, on an app with '
      'every module that the matrix does not have, and on tests that do not '
      'apply to the app', () async {
    final start = named('start').directory;

    final alone = await run([
      '--add-app-tests',
      '--without-external-steps',
      newApp(),
      start,
    ]);
    expect(alone.exitCode, 64);
    expect('${alone.stderr}', contains('--add-app-tests'));

    final unknown = await run([
      '--add-app-tests',
      '--app',
      'every module (nothing)',
      newApp(),
      start,
    ]);
    expect(unknown.exitCode, 64);
    expect(
      '${unknown.stderr}',
      contains('No app with every module is every module (nothing).'),
    );

    final (:apps, failed: _) = await everyModuleAppsOf(
      smfModules,
      withoutExternalSteps: true,
    );
    final matrixApp = apps.first;
    final other = appTests.firstWhere((test) => !test.appliesTo(matrixApp));
    final app = newApp();
    final result = await run([
      '--add-app-tests',
      '--without-external-steps',
      '--app',
      matrixApp.name,
      app,
      start,
      other.directory,
    ]);
    expect(result.exitCode, 1);
    expect(
      '${result.stderr}',
      contains(
        'The tests of ${other.directory} do not apply to ${matrixApp.name}.',
      ),
    );
    expect(File(p.join(app, startProbesFile)).existsSync(), isFalse);
  });
}
