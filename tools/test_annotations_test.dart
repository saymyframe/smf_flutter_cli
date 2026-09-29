// Tests tools/test_annotations.dart, and checks that the workflows let it
// annotate every test that fails in CI: each run of tests writes a report
// that no other run of its job replaces, and a step after the tests of a job
// runs the tool, even when a step failed or the job was cancelled.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'test_annotations.dart';

/// A report of `dart test --file-reporter json:<file>` with [events], one
/// JSON object on each line.
String _report(List<Map<String, Object?>> events) =>
    [for (final event in events) jsonEncode(event)].join('\n');

Map<String, Object?> _suite(int id, String path) => {
      'type': 'suite',
      'suite': {'id': id, 'platform': 'vm', 'path': path},
    };

/// The start of the test [id] of the suite 0, declared at [line] of [url],
/// or through a helper whose caller is at [rootLine] of [rootUrl].
Map<String, Object?> _start(
  int id,
  String name, {
  int? line,
  String? url,
  int? rootLine,
  String? rootUrl,
}) =>
    {
      'type': 'testStart',
      'test': {
        'id': id,
        'name': name,
        'suiteID': 0,
        'groupIDs': <int>[],
        'metadata': {'skip': false, 'skipReason': null},
        'line': line,
        'column': line == null ? null : 3,
        'url': url,
        if (rootLine != null) 'root_line': rootLine,
        if (rootLine != null) 'root_column': 5,
        if (rootUrl != null) 'root_url': rootUrl,
      },
    };

Map<String, Object?> _error(int test, String error, [String stackTrace = '']) =>
    {
      'type': 'error',
      'testID': test,
      'error': error,
      'stackTrace': stackTrace,
      'isFailure': true,
    };

Map<String, Object?> _done(
  int test, {
  String result = 'success',
  bool skipped = false,
  bool hidden = false,
}) =>
    {
      'type': 'testDone',
      'testID': test,
      'result': result,
      'skipped': skipped,
      'hidden': hidden,
    };

const _url = 'file:///repo/packages/a/test/a_test.dart';

/// The root of this repository.
String _root() {
  final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  expect(top.exitCode, 0, reason: '${top.stderr}');
  return '${top.stdout}'.trim();
}

/// The report that a command of a workflow tells `dart test` to write.
final _reportOption = RegExp(
  r'--file-reporter json:build/test-results/([\w-]+)\.json',
);

/// The commands of [script], the `run` of a step or of a melos script: its
/// lines, with a line that ends with `\` joined to the next, split where
/// `&&`, `||` or `;` separate commands.
List<String> _commandsOf(String script) => script
    .replaceAll(RegExp(r'\\\r?\n'), ' ')
    .split(RegExp(r'&&|\|\||;|\r?\n'))
    .map((command) => command.trim())
    .where((command) => command.isNotEmpty)
    .toList();

/// Whether [command] runs tests of Dart.
bool _runsTests(String command) =>
    command.contains('dart test') || command.contains('test_with_coverage');

/// Whether [step] annotates the tests that failed before it, even when a
/// step failed or the job was cancelled.
bool _annotates(Object? step) =>
    step is YamlMap &&
    '${step['run']}'.contains('dart tools/test_annotations.dart') &&
    '${step['if']}'.contains('always()');

/// The problems of the runs of tests in [workflow], the text of a workflow
/// of GitHub Actions, with the melos [scripts] that its steps may run, by
/// name: a run of tests that writes no report to build/test-results/, two
/// runs of a job that write one report, and a job whose tests no later step
/// annotates.
List<String> reportProblemsOf(String workflow, Map<String, String> scripts) {
  final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
  final problems = <String>[];
  for (final MapEntry(:key, :value) in jobs.entries) {
    // A job that calls a reusable workflow has no steps of its own.
    final steps = (value as YamlMap)['steps'];
    if (steps is! YamlList) continue;
    final reports = <String>{};
    var lastTests = -1;
    for (final (index, step) in steps.cast<YamlMap>().indexed) {
      final commands = <String>[];
      for (final command in _commandsOf('${step['run'] ?? ''}')) {
        commands.add(command);
        for (final run in RegExp(r'melos run ([\w:-]+)').allMatches(command)) {
          commands.addAll(_commandsOf(scripts[run[1]] ?? ''));
        }
      }
      for (final command in commands.where(_runsTests)) {
        lastTests = index;
        final report = _reportOption.firstMatch(command)?[1];
        if (report == null) {
          problems.add(
            '$key: the step "${step['name']}" runs tests without a report '
            'in build/test-results/: $command',
          );
        } else if (!reports.add(report)) {
          problems.add(
            '$key: two runs of tests write build/test-results/$report.json, '
            'and the second replaces the report of the first.',
          );
        }
      }
    }
    if (lastTests >= 0 && !steps.skip(lastTests + 1).any(_annotates)) {
      problems.add(
        '$key: no step after its tests runs dart '
        'tools/test_annotations.dart with if: always(), so the tests that '
        'fail get no annotations.',
      );
    }
  }
  return problems;
}

/// The melos scripts of the root [pubspec], by name, with what each runs.
Map<String, String> _scriptsOf(String pubspec) {
  final melos = (loadYaml(pubspec) as YamlMap)['melos'] as YamlMap;
  return {
    for (final MapEntry(:key, :value) in (melos['scripts'] as YamlMap).entries)
      '$key': switch (value) {
        final YamlMap script => '${script['run']}',
        _ => '$value',
      },
  };
}

void main() {
  group('annotationsOf', () {
    test('annotates a failed test at the line of its file where it failed', () {
      final report = _report([
        _suite(0, 'test/a_test.dart'),
        _start(1, 'a group passes', line: 5, url: _url),
        _done(1),
        _start(2, 'a group fails', line: 7, url: _url),
        _error(
          2,
          'Expected: <2>\n  Actual: <1>\n',
          'package:matcher                 expect\n'
              'test/a_test.dart 9:5          main.<fn>.<fn>\n',
        ),
        _done(2, result: 'failure'),
      ]);

      const annotation =
          '::error file=packages/a/test/a_test.dart,line=9,title=a group '
          'fails::Expected: <2>%0A  Actual: <1>';
      expect(annotationsOf(report, directory: 'packages/a'), [annotation]);
    });

    test(
        'takes the line from the first frame in the file of the test, past '
        'its helpers in other files', () {
      final report = _report([
        _suite(0, 'test/a_test.dart'),
        _start(1, 'throws', line: 7, url: _url),
        _error(
          1,
          'Bad state: no',
          'test/helpers.dart 3:26        check\n'
              'test/a_test.dart 12:35        main.<fn>\n'
              'test/a_test.dart 30:3         main\n',
        ),
        _done(1, result: 'error'),
      ]);

      expect(annotationsOf(report), [
        '::error file=test/a_test.dart,line=12,title=throws::Bad state: no',
      ]);
    });

    test(
        'takes the line where the test is declared when no frame is in its '
        'file, through a helper too', () {
      String annotation(Map<String, Object?> start) => annotationsOf(
            _report([
              _suite(0, 'test/a_test.dart'),
              start,
              _error(1, 'no', 'package:a/a.dart 3:5  a\n'),
              _done(1, result: 'error'),
            ]),
          ).single;

      expect(
        annotation(_start(1, 'a', line: 7, url: _url)),
        '::error file=test/a_test.dart,line=7,title=a::no',
      );
      expect(
        annotation(
          _start(
            1,
            'a',
            line: 3,
            url: 'file:///repo/packages/a/test/helpers.dart',
            rootLine: 20,
            rootUrl: _url,
          ),
        ),
        '::error file=test/a_test.dart,line=20,title=a::no',
      );
      // Declared in another file, which the report gives no root of.
      expect(
        annotation(
          _start(
            1,
            'a',
            line: 3,
            url: 'file:///repo/packages/a/test/helpers.dart',
          ),
        ),
        '::error file=test/a_test.dart,title=a::no',
      );
    });

    test('annotates a test file that failed to load, at the file', () {
      final report = _report([
        _suite(0, 'test/b_test.dart'),
        _start(1, 'loading test/b_test.dart'),
        _error(
          1,
          'Failed to load "test/b_test.dart":\n'
              "test/b_test.dart:1:23: Error: A value of type 'String' can't "
              "be assigned to a variable of type 'int'.",
          'package:test_core/src/runner/vm/platform.dart 334:7  '
              'VMPlatform._compileToKernel\n',
        ),
        _done(1, result: 'error'),
      ]);

      const annotation =
          '::error file=packages/a/test/b_test.dart,title=loading '
          'test/b_test.dart::Failed to load "test/b_test.dart":%0Atest/b_test.dart:1:23: '
          "Error: A value of type 'String' can't be assigned to a variable of "
          "type 'int'.";
      expect(annotationsOf(report, directory: 'packages/a'), [annotation]);
    });

    test(
        'annotates the tests that started and did not finish, in a report '
        'that the end of the tests cut off', () {
      final report = '${_report([
            _suite(0, 'test/a_test.dart'),
            _start(1, 'finished', line: 5, url: _url),
            _done(1),
            _start(2, 'hangs', line: 7, url: _url),
          ])}\n{"type":"testDo';

      const annotation =
          '::error file=test/a_test.dart,line=7,title=hangs::The test did not '
          'finish: the tests stopped while it ran.';
      expect(annotationsOf(report), [annotation]);
    });

    test('passes over the tests that passed, were skipped or were hidden', () {
      final report = _report([
        _suite(0, 'test/a_test.dart'),
        _start(1, 'loading test/a_test.dart'),
        _done(1, hidden: true),
        _start(2, 'passes', line: 5, url: _url),
        _done(2),
        _start(3, 'skipped', line: 6, url: _url),
        _done(3, skipped: true),
        {'type': 'done', 'success': true, 'time': 10},
      ]);

      expect(annotationsOf(report), isEmpty);
      expect(annotationsOf(''), isEmpty);
    });

    test('escapes what workflow commands read in their properties and text',
        () {
      final report = _report([
        _suite(0, 'test/a,b_test.dart'),
        _start(1, 'a: 1, 2%\nb'),
        _error(1, '50% of\r\nit'),
        _done(1, result: 'failure'),
      ]);

      expect(annotationsOf(report), [
        '::error file=test/a%2Cb_test.dart,title=a%3A 1%2C 2%25%0Ab::50%25 of%0Ait',
      ]);
    });

    test('keeps the first lines of a long message, and counts the others', () {
      final long = [for (var line = 1; line <= 25; line++) 'line $line'];
      List<String> message(List<String> errors) {
        final annotation = annotationsOf(
          _report([
            _suite(0, 'test/a_test.dart'),
            _start(1, 'a'),
            for (final error in errors) _error(1, error),
            _done(1, result: 'failure'),
          ]),
        ).single;
        return annotation.substring(annotation.indexOf('::', 2) + 2).split(
              '%0A',
            );
      }

      expect(message([long.join('\n'), 'two', 'three']), [
        ...long.take(messageLines),
        '… 5 more lines in the log of the tests',
        '… 2 more errors in the log of the tests',
      ]);
      expect(message(['one', 'two']), [
        'one',
        '… 1 more error in the log of the tests',
      ]);
    });

    test('reads the paths of a report that dart test wrote on Windows', () {
      const windows = 'file:///C:/repo/packages/a/test/a_test.dart';
      final report = _report([
        _suite(0, r'test\a_test.dart'),
        _start(1, 'a', line: 7, url: windows),
        _error(1, 'no', 'test\\a_test.dart 9:5  main.<fn>\n'),
        _done(1, result: 'failure'),
        _start(2, 'b', line: 11, url: windows),
        _error(2, 'no'),
        _done(2, result: 'failure'),
      ]);

      expect(annotationsOf(report, directory: 'packages/a'), [
        '::error file=packages/a/test/a_test.dart,line=9,title=a::no',
        '::error file=packages/a/test/a_test.dart,line=11,title=b::no',
      ]);
    });

    test(
      'annotates what a failed run of dart test reports',
      () async {
        final root = _root();
        // In build/ of the root, which git ignores, so that the test can
        // import package:test, and with a name that dart test finds only when
        // it gets it.
        final directory = Directory('$root/build')..createSync(recursive: true);
        final tests = directory.createTempSync('test_annotations_');
        final reports =
            Directory.systemTemp.createTempSync('test_annotations_');
        addTearDown(() {
          tests.deleteSync(recursive: true);
          reports.deleteSync(recursive: true);
        });
        final name =
            tests.path.substring(root.length + 1).replaceAll(r'\', '/');
        File('${tests.path}/failing.dart').writeAsStringSync('''
import 'package:test/test.dart';

void main() {
  test('passes', () {});
  group('a group', () {
    test('fails', () {
      expect(1, 2);
    });
  });
  test('throws', () => throw StateError('no'));
}
''');

        final run = await Process.run(
          Platform.resolvedExecutable,
          [
            'test',
            '$name/failing.dart',
            '--file-reporter',
            'json:${reports.path}/failing.json',
          ],
          workingDirectory: root,
        );

        expect(run.exitCode, isNot(0), reason: '${run.stdout}${run.stderr}');
        final report = File('${reports.path}/failing.json').readAsStringSync();
        final fails = '::error file=$name/failing.dart,line=7,title=a group '
            'fails::Expected: <2>%0A  Actual: <1>';
        final throws =
            '::error file=$name/failing.dart,line=10,title=throws::Bad state: no';
        expect(annotationsOf(report), [fails, throws]);
      },
      timeout: const Timeout(Duration(minutes: 3)),
    );
  });

  test('reads the reports of the root and of the members of the workspace', () {
    final root = Directory.systemTemp.createTempSync('test_annotations_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
      'workspace:\n'
      '  - packages/a\n'
      '  - packages/b\n'
      '  - packages/c\n',
    );
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
    write('build/test-results/tools.json', 'tools');
    write('packages/a/build/test-results/test.json', 'test');
    write('packages/a/build/test-results/archive_test.json', 'archive');
    write('packages/a/build/test-results/notes.txt', 'notes');
    // Tests that wrote no report.
    Directory('${root.path}/packages/c/build/test-results')
        .createSync(recursive: true);

    expect(reportsOf(root.path), {
      '': ['tools'],
      'packages/a': ['archive', 'test'],
    });
  });

  test(
      'reads the reports of every member that the root pubspec lists, with '
      'comments and quotes', () {
    final root = Directory.systemTemp.createTempSync('test_annotations_');
    addTearDown(() => root.deleteSync(recursive: true));
    File('${root.path}/pubspec.yaml').writeAsStringSync(
      'name: root\n'
      'workspace: # The packages of the repository.\n'
      '  - packages/a\n'
      '  - "packages/b"\n',
    );
    void write(String path, String text) => File('${root.path}/$path')
      ..createSync(recursive: true)
      ..writeAsStringSync(text);
    write('packages/a/build/test-results/test.json', 'a');
    write('packages/b/build/test-results/test.json', 'b');

    expect(reportsOf(root.path), {
      'packages/a': ['a'],
      'packages/b': ['b'],
    });
  });

  group('the workflows', () {
    test('find a run of tests that writes no report', () {
      String withoutReport(String step, String command) =>
          'a: the step "$step" runs tests without a report in '
          'build/test-results/: $command';

      expect(
        reportProblemsOf(
          '''
jobs:
  a:
    steps:
      - name: Test
        run: |
          dart pub get
          dart test --reporter expanded
      - name: Test with coverage
        run: melos run test:coverage
      - name: Annotate
        if: always()
        run: dart tools/test_annotations.dart
''',
          {
            'test:coverage': 'melos exec -- dart pub global run '
                'coverage:test_with_coverage \\\n'
                '  -- --file-reporter json:build/test-results/test.json && \\\n'
                'dart test tools',
          },
        ),
        [
          withoutReport('Test', 'dart test --reporter expanded'),
          withoutReport('Test with coverage', 'dart test tools'),
        ],
      );
    });

    test('find two runs of a job that write one report', () {
      const problem =
          'a: two runs of tests write build/test-results/test.json, '
          'and the second replaces the report of the first.';
      expect(
        reportProblemsOf(
          r'''
jobs:
  a:
    steps:
      - run: dart test --file-reporter json:build/test-results/test.json
      - run: dart test tools --file-reporter json:build/test-results/tools.json
      - run: dart test test/a_test.dart --file-reporter json:build/test-results/test.json
      - if: ${{ always() }}
        run: dart tools/test_annotations.dart
''',
          const {},
        ),
        [problem],
      );
    });

    test('find a job whose tests no later step annotates', () {
      const problem = 'a: no step after its tests runs dart '
          'tools/test_annotations.dart with if: always(), so the tests that '
          'fail get no annotations.';
      String job(String steps) => 'jobs:\n  a:\n    steps:\n$steps';
      const tests = '      - run: dart test '
          '--file-reporter json:build/test-results/test.json\n';

      expect(reportProblemsOf(job(tests), const {}), [problem]);
      expect(
        reportProblemsOf(
          job(
            '      - if: always()\n'
            '        run: dart tools/test_annotations.dart\n'
            '$tests',
          ),
          const {},
        ),
        [problem],
      );
      expect(
        reportProblemsOf(
          job(
            '$tests'
            r'      - if: ${{ !cancelled() }}'
            '\n'
            '        run: dart tools/test_annotations.dart\n',
          ),
          const {},
        ),
        [problem],
      );
      expect(
        reportProblemsOf(
          job(
            '$tests'
            '      - run: echo\n'
            r"      - if: ${{ always() && steps.dart.outcome == 'success' }}"
            '\n'
            '        run: dart tools/test_annotations.dart\n',
          ),
          const {},
        ),
        isEmpty,
      );
    });

    test('pass the jobs without tests and those that call a workflow', () {
      expect(
        reportProblemsOf(
          '''
jobs:
  a:
    steps:
      - run: flutter test
  b:
    uses: ./.github/workflows/apps.yml
''',
          const {},
        ),
        isEmpty,
      );
    });

    test(
        'of this repository annotate every test they run, with a report of '
        'its own', () {
      final root = _root();
      final scripts = _scriptsOf(File('$root/pubspec.yaml').readAsStringSync());
      final workflows = Directory('$root/.github/workflows')
          .listSync()
          .whereType<File>()
          .where((file) => file.path.endsWith('.yml'))
          .toList();

      expect(scripts, contains('test:coverage'));
      expect(workflows, isNotEmpty);
      final problems = [
        for (final workflow in workflows)
          for (final problem in reportProblemsOf(
            workflow.readAsStringSync(),
            scripts,
          ))
            '${workflow.uri.pathSegments.last}: $problem',
      ];
      expect(problems, isEmpty);
    });
  });
}
