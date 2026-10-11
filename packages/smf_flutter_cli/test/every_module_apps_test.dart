// Tests tool/every_module_apps.dart, which CI runs in a package of its own
// that depends on the release of smf_flutter_cli that it activates from
// pub.dev, to generate with that smf the apps with every module of the
// release. No module of smf create has to provide a role with a mode option
// for the test of the apps of such an option: a copy of the tool lists the
// apps of a synthetic registry with one.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:test/test.dart';

import 'mode_registry.dart';

void main() {
  // The time of a test that lists the apps of a registry, in the tool and
  // again in the test: on a busy Windows runner that takes most of the
  // default 30 seconds, and more with each module that the CLI offers.
  const timeout = Timeout(Duration(minutes: 2));
  late Directory temp;
  late String kernel;

  // The kernel of the tool, compiled once for the runs of the tests.
  setUpAll(() async {
    temp = Directory.systemTemp.createTempSync('every_module_apps_');
    kernel = p.join(temp.path, 'every_module_apps.dill');
    final packageConfig = await Isolate.packageConfig;
    final result = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      '--packages=${packageConfig!.toFilePath()}',
      p.join('tool', 'every_module_apps.dart'),
      '-o',
      kernel,
    ]);
    if (result.exitCode != 0) {
      throw StateError('The tool does not compile: ${result.stderr}');
    }
  });
  tearDownAll(() => temp.deleteSync(recursive: true));

  Future<ProcessResult> run(List<String> arguments, {String? tool}) =>
      Process.run(
        Platform.resolvedExecutable,
        [tool ?? kernel, ...arguments],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

  /// Compiles a copy of the tool that lists the apps of [modules], a
  /// registry of the library at [library], in place of those of the
  /// modules of `smf create`, and returns the path of its kernel.
  Future<String> compiledFor(String library, String modules) async {
    const import = "import 'package:smf_flutter_cli/smf_flutter_cli.dart';";
    const call = 'matrixOf(smfModules)';
    final source = File(p.join('tool', 'every_module_apps.dart'))
        .readAsStringSync()
        // Git may check the tool out with Windows line endings.
        .replaceAll('\r\n', '\n');
    expect(import.allMatches(source), hasLength(1));
    expect(call.allMatches(source), hasLength(1));
    expect('smfModules'.allMatches(source), hasLength(1));
    final copy = File(p.join(temp.path, 'every_module_apps_of_$modules.dart'))
      ..writeAsStringSync(
        source
            .replaceFirst(import, "import '${Uri.file(p.absolute(library))}';")
            .replaceFirst(call, 'matrixOf($modules)'),
      );
    final compiled = p.setExtension(copy.path, '.dill');
    final packageConfig = await Isolate.packageConfig;
    final result = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      '--packages=${packageConfig!.toFilePath()}',
      copy.path,
      '-o',
      compiled,
    ]);
    expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
    return compiled;
  }

  test(
    'prints the arguments of smf create of each app with every module, '
    'one for each combination of the providers of the roles that take '
    'one, as the matrix generates it but with the full dart fix, as '
    'app_1, app_2 and so on',
    () async {
      const directory = '/tmp/SMF apps from pub.dev';

      final result = await run([directory]);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      final (:apps, :failed) = await everyModuleAppsOf(smfModules);
      expect(failed, isEmpty);
      expect(apps, hasLength(greaterThan(1)));
      expect(jsonDecode('${result.stdout}'), [
        for (final (index, app) in apps.indexed)
          {
            'name': app.name,
            'arguments': [
              for (final argument
                  in app.createArguments('app_${index + 1}', directory))
                if (argument != '--no-dart-fix') argument,
            ],
          },
      ]);
    },
    timeout: timeout,
  );

  // This test also compiles a copy of the tool.
  test(
    'prints no app with every module of another value of a mode option '
    'of a role: each app gets no value of the option, as an app that a '
    'user generates without it',
    () async {
      const directory = '/tmp/SMF apps from pub.dev';
      final tool = await compiledFor(
        p.join('test', 'mode_registry.dart'),
        'doorsOfWood',
      );

      final result = await run([directory], tool: tool);

      expect(result.exitCode, 0, reason: '${result.stderr}');
      // The matrix of the registry has each of its two apps with every
      // module twice more, for the other values of the option.
      final (:apps, :failed) = await matrixOf(doorsOfWood);
      expect(failed, isEmpty);
      expect(
        apps.where((app) => app.everyModuleWith != null),
        hasLength(6),
      );
      final listed = jsonDecode('${result.stdout}') as List<Object?>;
      expect(
        [for (final app in listed) (app! as Map<String, Object?>)['name']],
        ['every module (oak)', 'every module (pine)'],
      );
      expect(
        [
          for (final app in listed)
            ...(app! as Map<String, Object?>)['arguments']! as List<Object?>,
        ],
        allOf(
          containsAll(['app_1', 'app_2', 'flutter_core,lock,pine']),
          isNot(contains('app_3')),
          isNot(contains(startsWith('--access'))),
        ),
      );
    },
    timeout: timeout,
  );

  test('fails with its usage without a directory, or with more', () async {
    for (final arguments in [
      <String>[],
      ['/tmp/apps', 'bloc'],
    ]) {
      final result = await run(arguments);
      expect(result.exitCode, 64, reason: '$arguments');
      expect(
        '${result.stderr}',
        startsWith('Usage: dart run tool/every_module_apps.dart <directory>'),
        reason: '$arguments',
      );
    }
  });
}
