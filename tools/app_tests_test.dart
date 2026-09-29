// Checks that the tests that packages keep for the apps of the matrix in
// `app_tests/` run in CI. The matrix tools copy the files of a directory of
// app tests into the apps they generate only when the directory is the
// directory of one of their MatrixAppTests, so the tests of a directory
// that no tool lists would never run, and no other check would say so.
//
// A directory of app tests is a directory right in the `app_tests` of a
// package of the workspace; each is the directory of one MatrixAppTest.
// Hidden files and directories, whose names start with `.`, stay out, as
// they stay out of the apps.
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';

import 'package:test/test.dart';

/// The matrix tools, by path from the root of the repository. Each prints
/// the directories of its MatrixAppTests with `--app-tests`.
const _tools = [
  'packages/smf_flutter_cli/tool/matrix.dart',
  'packages/smf_pipeline/fixture_registry/tool/matrix.dart',
];

/// The problems of the tests of the apps in the repository at [root], whose
/// packages are at the paths [packages] from it: a directory of app tests
/// that no tool of [listed] lists, a file right in `app_tests`, which is in
/// no directory of app tests, and a directory that a tool lists but that
/// does not exist or is not a directory of app tests. [listed] holds the
/// directories of the MatrixAppTests of each matrix tool, by the path of
/// the tool.
List<String> problemsOf(
  String root,
  List<String> packages,
  Map<String, List<String>> listed,
) {
  // The directories of app tests by their real path, which the paths that
  // the tools print resolve to, whatever their separators, and their paths
  // from the root.
  final directories = <String, String>{};
  final files = <String>[];
  for (final package in packages) {
    final appTests = Directory('$root/$package/app_tests');
    if (!appTests.existsSync()) continue;
    final entities = appTests.listSync()
      ..sort((a, b) => a.path.compareTo(b.path));
    for (final entity in entities) {
      final name = entity.path.split(RegExp(r'[/\\]')).last;
      if (name.startsWith('.')) continue;
      if (entity is Directory) {
        directories[entity.resolveSymbolicLinksSync()] =
            '$package/app_tests/$name';
      } else {
        files.add(
          '$package/app_tests/$name: this file is in no directory of app '
          'tests, so no matrix tool copies it into an app.',
        );
      }
    }
  }
  final unlisted = {...directories.keys};
  final wrong = <String>[];
  for (final MapEntry(key: tool, value: paths) in listed.entries) {
    for (final path in paths) {
      final directory = Directory(path);
      if (!directory.existsSync()) {
        wrong.add('$tool lists $path, which does not exist.');
        continue;
      }
      final real = directory.resolveSymbolicLinksSync();
      if (directories.containsKey(real)) {
        unlisted.remove(real);
      } else {
        wrong.add(
          '$tool lists $path, which is not a directory right in the '
          'app_tests of a package of the workspace.',
        );
      }
    }
  }
  return [
    ...unlisted.map(
      (path) => '${directories[path]}: no matrix tool lists this directory '
          'of app tests, so its tests never run. Add a MatrixAppTest for it '
          'to ${listed.keys.join(' or ')}.',
    ),
    ...files,
    ...wrong,
  ];
}

/// The paths of the packages of the workspace at [root] from it.
List<String> _workspacePackages(String root) {
  final packages = <String>[];
  var inWorkspace = false;
  for (final line in File('$root/pubspec.yaml').readAsLinesSync()) {
    if (RegExp(r'^\S').hasMatch(line)) inWorkspace = line == 'workspace:';
    if (!inWorkspace) continue;
    if (RegExp(r'^  - (\S+)').firstMatch(line) case final match?) {
      packages.add(match[1]!);
    }
  }
  return packages;
}

/// The directories of the MatrixAppTests of the matrix [tool] of the
/// repository at [root], which it prints with `--app-tests`.
Future<List<String>> _listedBy(String root, String tool) async {
  final packageConfig = await Isolate.packageConfig;
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['--packages=${packageConfig!.toFilePath()}', tool, '--app-tests'],
    workingDirectory: root,
    // The tools write UTF-8, on Windows too.
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  expect(
    result.exitCode,
    0,
    reason: '$tool --app-tests: ${result.stdout}${result.stderr}',
  );
  return [
    for (final line in const LineSplitter().convert('${result.stdout}'))
      if (line.isNotEmpty) line,
  ];
}

void main() {
  test(
      'finds the directories of app tests that no tool lists, the files in '
      'no such directory, and the directories that a tool lists that are '
      'none', () {
    final temp = Directory.systemTemp.createTempSync('smf_app_tests_');
    addTearDown(() => temp.deleteSync(recursive: true));
    final root = temp.path;
    for (final path in [
      'a/app_tests/listed/test/listed_test.dart',
      'a/app_tests/twice/test/twice_test.dart',
      'a/app_tests/unlisted/test/unlisted_test.dart',
      'a/app_tests/stray_test.dart',
      'a/app_tests/.hidden/test/hidden_test.dart',
      'a/app_tests/.DS_Store',
      'a/lib/a.dart',
      'b/lib/b.dart',
      'other/app_tests/other/test/other_test.dart',
    ]) {
      File('$root/$path').createSync(recursive: true);
    }

    // Absolute paths, with names joined with `/` as the tools join them,
    // which on Windows follow a path with `\`.
    final listed = {
      'one.dart': ['$root/a/app_tests/listed', '$root/a/app_tests/twice'],
      'two.dart': [
        '$root/a/app_tests/twice',
        '$root/a/app_tests/gone',
        '$root/a/lib',
        '$root/other/app_tests/other',
      ],
    };
    const unlisted = 'a/app_tests/unlisted: no matrix tool lists this '
        'directory of app tests, so its tests never run. Add a MatrixAppTest '
        'for it to one.dart or two.dart.';
    const stray = 'a/app_tests/stray_test.dart: this file is in no '
        'directory of app tests, so no matrix tool copies it into an app.';
    const notOne = 'which is not a directory right in the app_tests of a '
        'package of the workspace.';

    expect(problemsOf(root, ['a', 'b'], listed), [
      unlisted,
      stray,
      'two.dart lists $root/a/app_tests/gone, which does not exist.',
      'two.dart lists $root/a/lib, $notOne',
      'two.dart lists $root/other/app_tests/other, $notOne',
    ]);
  });

  test(
    'every directory of app tests in the packages of the workspace is the '
    'directory of a MatrixAppTest of a matrix tool, and every directory '
    'that a tool lists is one',
    () async {
      final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
      expect(top.exitCode, 0, reason: '${top.stderr}');
      final root = '${top.stdout}'.trim();
      final listed = await Future.wait(
        [for (final tool in _tools) _listedBy(root, tool)],
      );

      expect(
        problemsOf(root, _workspacePackages(root), {
          for (final (index, tool) in _tools.indexed) tool: listed[index],
        }),
        isEmpty,
      );
    },
    // Each tool loads the modules of its matrix first, which takes a while
    // on the runners of CI.
    timeout: const Timeout(Duration(minutes: 5)),
  );
}
