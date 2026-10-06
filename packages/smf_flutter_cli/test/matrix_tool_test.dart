// Tests --add-app-tests of tool/matrix.dart, which CI runs in the jobs
// that start an app with every module on a device: with --app, the tool
// adds the start check to the app that --create --app generated as the app
// of that name, with the probes of the tests of the app, the files that
// those tests generate for it, and their dev dependencies, which it adds
// with flutter. A command that stands in for flutter is first on the path
// of the tool here, so the tests need no Flutter SDK.
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

/// Writes a command that stands in for `flutter` into [bin]: it writes its
/// arguments and its working directory to `calls.log` next to it, and
/// succeeds. On Windows it is a batch file, `flutter.bat`, as in a Flutter
/// SDK there.
void _fakeFlutter(String bin) {
  Directory(bin).createSync(recursive: true);
  if (Platform.isWindows) {
    File(p.join(bin, 'flutter.bat')).writeAsStringSync(
      '@echo off\r\n>> "%~dp0calls.log" echo flutter %* in %CD%\r\n',
    );
    return;
  }
  final file = File(p.join(bin, 'flutter'))
    ..writeAsStringSync(
      '#!/bin/sh\n'
      'echo "flutter \$* in \$PWD" >> "${p.join(bin, 'calls.log')}"\n',
    );
  Process.runSync('chmod', ['+x', file.path]);
}

/// The directory [path] with links resolved, as the stand-in for flutter
/// names its working directory: the shell of macOS resolves them, and
/// Windows may name a directory by its short name, such as `RUNNER~1`.
String _resolved(String path) => Directory(path).resolveSymbolicLinksSync();

void main() {
  late Directory temp;
  late String kernel;
  late String packages;
  late String bin;
  late List<MatrixAppTest> appTests;

  // The kernel of the tool, compiled once for the runs of the tests.
  setUpAll(() async {
    temp = Directory.systemTemp.createTempSync('matrix_tool_');
    kernel = p.join(temp.path, 'matrix.dill');
    bin = p.join(temp.path, 'bin');
    _fakeFlutter(bin);
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

  /// Runs the tool with the stand-in for flutter before the commands of
  /// the machine on its path.
  Future<ProcessResult> run(List<String> arguments) {
    // The name of the variable as the machine has it: `Path` on Windows.
    final path = Platform.environment.keys.firstWhere(
      (name) => name.toUpperCase() == 'PATH',
      orElse: () => 'PATH',
    );
    final separator = Platform.isWindows ? ';' : ':';
    return Process.run(
      Platform.resolvedExecutable,
      ['--packages=$packages', kernel, ...arguments],
      environment: {
        path: '$bin$separator${Platform.environment[path] ?? ''}',
      },
      stdoutEncoding: utf8,
      stderrEncoding: utf8,
    );
  }

  /// What the tool ran flutter with, and where, since [clearCalls].
  List<String> calls() {
    final log = File(p.join(bin, 'calls.log'));
    return log.existsSync() ? log.readAsLinesSync() : const [];
  }

  /// Forgets the calls of flutter so far.
  void clearCalls() {
    final log = File(p.join(bin, 'calls.log'));
    if (log.existsSync()) log.deleteSync();
  }

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
      'of the app, the files that they generate for it and their dev '
      'dependencies', () async {
    final generated = <bool, Map<String, String>>{};
    for (final withoutExternalSteps in [true, false]) {
      final (:apps, :failed) = await everyModuleAppsOf(
        smfModules,
        withoutExternalSteps: withoutExternalSteps,
      );
      expect(failed, isEmpty);
      final matrixApp = apps.last;
      final app = newApp();
      clearCalls();

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
      // The probes of the tests of the app, those of the preferences and
      // of the onboarding among them: the apps without external steps have
      // their modules too.
      final list = read(app, startProbesFile);
      expect(list, contains("('onboarding', probe0.probeOnboarding),"));
      expect(
        list,
        contains("('shared_preferences', probe1.probeSharedPreferences),"),
      );
      expect(list, contains("('di_role', probe2.probeServices),"));
      expect(
        list,
        contains("('preferences_role', probe3.probePreferences),"),
      );
      expect(list, contains("('router_walk', probe4.probeRoutes),"));
      const status = 'features/onboarding/onboarding_status.dart';
      expect(
        read(app, 'integration_test/onboarding/probe.dart'),
        contains("import 'package:start_app/$status';"),
      );
      expect(
        read(app, 'integration_test/preferences_role/probe.dart'),
        contains(
          "import 'package:start_app/core/preferences/app_preferences.dart';",
        ),
      );
      const implementation = 'core/preferences/shared_app_preferences.dart';
      expect(
        read(app, 'integration_test/shared_preferences/probe.dart'),
        contains("import 'package:start_app/$implementation';"),
      );
      // The test of shared_preferences, which comes with its probe, needs a
      // dev dependency, which the tool adds with flutter in the app.
      const pubAdd =
          'flutter pub add dev:shared_preferences_platform_interface in ';
      final call = calls().single;
      expect(call, startsWith(pubAdd), reason: reason);
      expect(_resolved(call.substring(pubAdd.length).trim()), _resolved(app));
      final files = generated[withoutExternalSteps] = {
        for (final test in [
          named('di_role'),
          named('router_walk'),
          // The test of the onboarding comes with its probe.
          named('onboarding'),
        ])
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
