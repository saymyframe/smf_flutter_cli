// Prints the tests that failed in CI as annotations of GitHub Actions. The
// page of a run lists them at the top, with the name of each test, its
// message and the line of its file; otherwise a failed test is one line
// among thousands in the log of a step that tests several packages at once.
//
// Every `dart test` of the workflows writes a report with
// `--file-reporter json:build/test-results/<name>.json` in the directory it
// runs in, and the last step of each job with tests runs this tool, even
// when a step failed or the job was cancelled:
// `dart tools/test_annotations.dart`. It reads the reports in
// build/test-results/ of the root of the repository, where the tests of
// tools/ run, and of each member of the workspace in the root pubspec.yaml.
// It reads the pubspec with package:yaml, so it needs the packages of the
// workspace, which each job gets before its tests.
// tools/test_annotations_test.dart checks that the workflows write the
// reports and run the tool.
import 'dart:convert';
import 'dart:io';

import 'workspace_members.dart';

/// The reports of tests in build/test-results/ of the repository at [root]
/// and of each member of its workspace, by the directory they are in from
/// [root], `''` for the root itself; a directory without reports is left
/// out.
Map<String, List<String>> reportsOf(String root) {
  final pubspec = File('$root/pubspec.yaml').readAsStringSync();
  final reports = <String, List<String>>{};
  for (final directory in ['', ...workspaceMembers(pubspec)]) {
    final texts = _reportsIn(
      Directory(_join(_join(root, directory), 'build/test-results')),
    );
    if (texts.isNotEmpty) reports[directory] = texts;
  }
  return reports;
}

/// The text of each report in [directory], in the order of their names.
List<String> _reportsIn(Directory directory) {
  if (!directory.existsSync()) return const [];
  final files = directory
      .listSync()
      .whereType<File>()
      .where((file) => file.path.endsWith('.json'))
      .toList()
    ..sort((a, b) => a.path.compareTo(b.path));
  return [for (final file in files) file.readAsStringSync()];
}

/// The annotations of GitHub Actions for the tests that failed in [report],
/// what `dart test --file-reporter json:<file>` writes, from tests that ran
/// in [directory] from the root of the repository: one for each test with
/// an error, and one for each test that started but did not finish, as when
/// the tests stopped while it ran.
List<String> annotationsOf(String report, {String directory = ''}) {
  final suites = <Object?, String>{};
  final tests = <Object?, _Test>{};
  for (final line in const LineSplitter().convert(report)) {
    final Object? event;
    try {
      event = jsonDecode(line);
    } on FormatException {
      // The last line of a report whose tests stopped may be cut off.
      continue;
    }
    switch (event) {
      case {
          'type': 'suite',
          'suite': {'id': final id, 'path': final String path},
        }:
        suites[id] = _slashed(path);
      case {'type': 'testStart', 'test': final Map<String, Object?> test}:
        tests[test['id']] = _Test(test, suite: suites[test['suiteID']]);
      case {
          'type': 'error',
          'testID': final id,
          'error': final String error,
          'stackTrace': final String stackTrace,
        }:
        tests[id]?.errors.add((error, stackTrace));
      case {'type': 'testDone', 'testID': final id}:
        tests[id]?.done = true;
    }
  }
  return [
    for (final test in tests.values)
      if (test.errors.isNotEmpty || !test.done) test.annotation(directory),
  ];
}

/// The lines of a message that an annotation keeps; the log of the tests
/// has the rest.
const messageLines = 20;

/// A test of a report, with the errors it reported.
final class _Test {
  _Test(Map<String, Object?> test, {required this.suite})
      : name = '${test['name']}',
        declaredLine = _declaredIn(test, suite);

  /// The name of the test, with the names of its groups.
  final String name;

  /// The path of the file of the test from the directory the tests ran in,
  /// or `null` if the report does not give it.
  final String? suite;

  /// The line of [suite] where the test is declared, if it is there.
  final int? declaredLine;

  /// The message and the stack trace of each error of the test.
  final errors = <(String, String)>[];

  /// Whether the test finished.
  bool done = false;

  /// The annotation of the test that failed, with its file from the root
  /// of the repository, the tests having run in [directory], and the line
  /// where its first error came from in that file, or else where the test
  /// is declared.
  String annotation(String directory) {
    final properties = [
      if (suite case final suite?) ...[
        'file=${_property(_join(directory, suite))}',
        if (_lineOfError(suite) ?? declaredLine case final line?) 'line=$line',
      ],
      'title=${_property(name)}',
    ];
    return '::error ${properties.join(',')}::${_data(_message())}';
  }

  /// The line of [suite] in the stack trace of the first error that is
  /// closest to where the error came from.
  int? _lineOfError(String suite) {
    if (errors.isEmpty) return null;
    final frame = RegExp('^${RegExp.escape(suite)} (\\d+)', multiLine: true);
    return switch (frame.firstMatch(_slashed(errors.first.$2))) {
      final match? => int.parse(match[1]!),
      null => null,
    };
  }

  /// The message of the first error, with at most [messageLines] of its
  /// lines, and how many more errors the test had.
  String _message() {
    if (errors.isEmpty) {
      return 'The test did not finish: the tests stopped while it ran.';
    }
    final lines = const LineSplitter().convert(errors.first.$1.trimRight());
    final more = errors.length - 1;
    final errorsMore = more == 1 ? '1 more error' : '$more more errors';
    return [
      ...lines.take(messageLines),
      if (lines.length > messageLines)
        '… ${lines.length - messageLines} more lines in the log of the tests',
      if (more > 0) '… $errorsMore in the log of the tests',
    ].join('\n');
  }

  /// The line where [test] is declared, if that is in [suite], the file of
  /// the test; a test declared by a helper in another file gives the line
  /// in its own file as its root.
  static int? _declaredIn(Map<String, Object?> test, String? suite) {
    final url = test['root_url'] ?? test['url'];
    final line = test['root_line'] ?? test['line'];
    if (suite == null || url is! String || line is! int) return null;
    final path = Uri.decodeFull(Uri.parse(url).path);
    return path.endsWith('/$suite') ? line : null;
  }
}

/// [path] with `/` between its parts.
String _slashed(String path) => path.replaceAll(r'\', '/');

/// [path] in [directory], or [path] itself when [directory] is `''`.
String _join(String directory, String path) =>
    directory.isEmpty ? path : '$directory/$path';

/// [text] as the message of a workflow command of GitHub Actions.
String _data(String text) =>
    text.replaceAll('%', '%25').replaceAll('\r', '%0D').replaceAll('\n', '%0A');

/// [text] as the value of a property of a workflow command, such as its
/// title.
String _property(String text) =>
    _data(text).replaceAll(':', '%3A').replaceAll(',', '%2C');

void main() {
  final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  if (top.exitCode != 0) {
    stderr.writeln('Run the tool in the repository: ${top.stderr}');
    exit(2);
  }
  var reports = 0;
  var failed = 0;
  final all = reportsOf('${top.stdout}'.trim());
  for (final MapEntry(key: directory, value: texts) in all.entries) {
    for (final text in texts) {
      reports++;
      for (final annotation in annotationsOf(text, directory: directory)) {
        failed++;
        stdout.writeln(annotation);
      }
    }
  }
  stdout.writeln(
    '${_count(failed, 'test')} failed or did not finish, in '
    '${_count(reports, 'report')} of tests.',
  );
}

/// [count] and [noun], in the plural unless [count] is 1.
String _count(int count, String noun) =>
    count == 1 ? '1 $noun' : '$count ${noun}s';
