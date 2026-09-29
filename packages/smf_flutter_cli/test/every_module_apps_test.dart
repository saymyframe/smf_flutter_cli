// Tests tool/every_module_apps.dart, which CI runs in a package of its own
// that depends on the release of smf_flutter_cli that it activates from
// pub.dev, to generate with that smf the apps with every module of the
// release.
@TestOn('vm')
library;

import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_cli/smf_flutter_cli.dart';
import 'package:test/test.dart';

void main() {
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

  Future<ProcessResult> run(List<String> arguments) => Process.run(
        Platform.resolvedExecutable,
        [kernel, ...arguments],
        stdoutEncoding: utf8,
        stderrEncoding: utf8,
      );

  test(
      'prints the arguments of smf create of each app with every module, '
      'one for each combination of the providers of the roles that take '
      'one, as the matrix generates it but with the full dart fix, as '
      'app_1, app_2 and so on', () async {
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
  });

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
