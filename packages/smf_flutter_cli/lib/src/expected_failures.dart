import 'dart:convert';

/// A test of an app of the matrix that must fail, and a reason that its
/// first failure must give, such as a test of a role in an app whose
/// provider of the role has a known bug.
///
/// A test that passes whatever the provider of its role does checks
/// nothing: an app with a provider that has a bug shows that the test fails
/// on the bug, and on nothing else (see [expectedFailureProblems]).
final class MatrixExpectedFailure {
  /// Expects the test [test] of the test file at [file] of an app to fail
  /// first on an expectation whose message contains [reason].
  const MatrixExpectedFailure(this.file, this.test, this.reason);

  /// The path of the test file in the app, with `/` between its names, such
  /// as `test/router_screens_test.dart`.
  final String file;

  /// The full name of the test, as `flutter test` names it: the
  /// descriptions of its groups and its own, with a space between each.
  final String test;

  /// A text that the message of the first failure of the test contains,
  /// such as the reason of the expectation that the bug fails.
  ///
  /// Any run of whitespace in it and in the message counts as one space,
  /// since flutter_test wraps the long lines of the messages it prints.
  final String reason;

  @override
  String toString() => '"$test" of $file';
}

/// The problems of a run of `flutter test --reporter json` in an app whose
/// tests of [expected] must fail, and whose other tests must pass; [report]
/// is what the run wrote. A problem shows a test file by its path in the
/// app when the report has it in [directory], the directory of the app.
///
/// An expected failure is met when its test ran in the test file that it
/// names, did not pass, and failed first on an expectation, a thrown
/// `TestFailure` such as that of a failed `expect`, whose message contains
/// its reason. package:test reports such a failure as an error of the test
/// that is a failure (`isFailure`). flutter_test reports each failure of a
/// widget test as an error that refers to what it printed before,
/// `Test failed. See exception logs above.`, with the result `error`, so
/// the first failure of such a test is the first thing that flutter_test
/// printed as thrown: `The following TestFailure was thrown …` for a failed
/// expectation.
///
/// The problems are: the tests passed; an expected test did not run, did
/// not finish, passed or was skipped; it failed first on an expectation
/// whose message lacks the reason, or with an error rather than a failed
/// expectation, such as an exception, a timeout or a test file that does
/// not load, each quoting the first line of its message; another test did
/// not pass or did not finish, as when a test file does not compile, a hook
/// such as `setUpAll` fails, or the bug fails a test that it must not; and
/// the run did not finish.
///
/// A test that its declaration skips, with `skip:` of the test or of its
/// group, which the report shows when the test starts, is skipped in every
/// app alike, so it is no problem. A test that skips itself while it runs
/// may do so because of the bug, so it is one.
List<String> expectedFailureProblems(
  String report,
  List<MatrixExpectedFailure> expected, {
  String? directory,
}) {
  final run = _Run.parse(report);
  final problems = [
    if ((run.passed ?? false) && expected.isNotEmpty)
      'The tests passed, but ${expected.join(', ')} must fail.',
  ];
  final matched = <_Test>{};
  for (final failure in expected) {
    final test = run.testOf(failure);
    if (test == null) {
      problems.add('$failure did not run.');
      continue;
    }
    matched.add(test);
    if (_expectedProblem(test, failure) case final problem?) {
      problems.add(problem);
    }
  }
  for (final test in run.tests) {
    if (matched.contains(test)) continue;
    if (_otherProblem(test, directory) case final problem?) {
      problems.add(problem);
    }
  }
  if (run.passed == null) problems.add('The run of the tests did not finish.');
  return problems;
}

/// What a run of `flutter test --reporter json` wrote in [report], for a
/// log: its lines that are no events, such as what `flutter` says before
/// the tests, and a line for each test that it shows, with its result, its
/// test file, by its path in the app when it is in [directory], and its
/// name, followed by the first lines of the message of its first failure
/// if it did not pass; see [expectedFailureProblems].
List<String> testRunSummary(String report, {String? directory}) {
  final run = _Run.parse(report);
  return [
    ...run.other,
    for (final test in run.tests)
      if (!test.hidden) ...[
        '${test.outcome}: ${_shown(test.path, directory)}: ${test.name}',
        if (test.result case final result? when result != _success)
          ..._indented(test.firstFailure?.message ?? result),
      ],
  ];
}

/// The result of a test that passed, or that was skipped.
const _success = 'success';

/// The lines of the message of a failure that a log keeps.
const _keptLines = 20;

/// The lines of [message] for a log, indented: at most [_keptLines] of them,
/// and how many more there are.
List<String> _indented(String message) {
  final lines = const LineSplitter().convert(message.trimRight());
  return [
    for (final line in lines.take(_keptLines)) '  $line',
    if (lines.length > _keptLines)
      '  … ${lines.length - _keptLines} more lines',
  ];
}

/// The problem of [test], which must fail as [failure] expects, or `null`
/// if it does.
String? _expectedProblem(_Test test, MatrixExpectedFailure failure) {
  final result = test.result;
  if (result == null) return '$failure did not finish.';
  if (result == _success) {
    return '$failure ${test.skipped ? 'was skipped' : 'passed'}, but it must '
        'fail with "${failure.reason}".';
  }
  final failed = test.firstFailure;
  if (failed == null || !failed.expectation) {
    return '$failure failed first with an error rather than a failed '
        'expectation: ${_firstLine(failed?.message ?? result)}';
  }
  if (!_collapsed(failed.message).contains(_collapsed(failure.reason))) {
    return '$failure failed first with another message than '
        '"${failure.reason}": ${_firstLine(failed.message)}';
  }
  return null;
}

/// The problem of [test], which must pass, or `null` if it passed, or if
/// its declaration skips it; with its test file by its path in the app in
/// [directory].
String? _otherProblem(_Test test, String? directory) {
  final where = '"${test.name}" of ${_shown(test.path, directory)}';
  final result = test.result;
  if (result == null) return '$where did not finish.';
  if (result != _success) {
    return '$where did not pass: '
        '${_firstLine(test.firstFailure?.message ?? result)}';
  }
  if (test.skipped && !test.declaredSkip) {
    return '$where skipped itself: only a test that its declaration skips '
        'may be skipped, as it is in every app.';
  }
  return null;
}

/// [path], a test file of a report, from [directory] if it is in it, or as
/// it is; `an unknown file` for `null`.
String _shown(String? path, String? directory) {
  if (path == null) return 'an unknown file';
  if (directory == null) return path;
  final prefix = '${directory.replaceAll(r'\', '/')}/';
  return path.startsWith(prefix) ? path.substring(prefix.length) : path;
}

/// The first line of [message].
String _firstLine(String message) => '${message.trim()}\n'.split('\n').first;

/// [text] with each run of whitespace as one space.
String _collapsed(String text) => text.replaceAll(RegExp(r'\s+'), ' ').trim();

/// A run of `flutter test --reporter json`, as its report shows it.
final class _Run {
  _Run._(this.tests, this.other, this.passed);

  /// Reads [report], one JSON object on each line. A line that is not JSON
  /// is one of the [other] lines, but for one that starts as JSON and is cut
  /// off, as the last line of a run that stopped; an event of a test that
  /// did not start is left out.
  factory _Run.parse(String report) {
    final suites = <Object?, String>{};
    final tests = <Object?, _Test>{};
    final other = <String>[];
    bool? passed;
    for (final line in const LineSplitter().convert(report)) {
      final Object? event;
      try {
        event = jsonDecode(line);
      } on FormatException {
        if (!line.startsWith('{')) other.add(line);
        continue;
      }
      switch (event) {
        case {
            'type': 'suite',
            'suite': {'id': final id, 'path': final String path},
          }:
          suites[id] = path.replaceAll(r'\', '/');
        case {'type': 'testStart', 'test': final Map<String, Object?> test}:
          tests[test['id']] = _Test(
            '${test['name']}',
            suites[test['suiteID']],
            declaredSkip: switch (test['metadata']) {
              {'skip': true} => true,
              _ => false,
            },
          );
        case {
            'type': 'print',
            'testID': final id,
            'message': final String text
          }:
          tests[id]?.output.add((text: text, error: false, isFailure: false));
        case {
            'type': 'error',
            'testID': final id,
            'error': final String text,
            'isFailure': final bool isFailure,
          }:
          tests[id]
              ?.output
              .add((text: text, error: true, isFailure: isFailure));
        case {
            'type': 'testDone',
            'testID': final id,
            'result': final String result,
            'skipped': final bool skipped,
            'hidden': final bool hidden,
          }:
          tests[id]
            ?..result = result
            ..skipped = skipped
            ..hidden = hidden;
        case {'type': 'done', 'success': final bool success}:
          passed = success;
      }
    }
    return _Run._([...tests.values], other, passed);
  }

  /// The tests that started, in the order they started.
  final List<_Test> tests;

  /// The lines of the report that are no events.
  final List<String> other;

  /// Whether the run passed, or `null` if it did not finish.
  final bool? passed;

  /// The test that [failure] expects to fail, if it started: the test of
  /// its name in the test file whose path in the app is that of [failure],
  /// whatever the directory of the app and the separators of the paths of
  /// the report.
  _Test? testOf(MatrixExpectedFailure failure) {
    for (final test in tests) {
      final path = test.path;
      if (test.name == failure.test &&
          path != null &&
          (path == failure.file || path.endsWith('/${failure.file}'))) {
        return test;
      }
    }
    return null;
  }
}

/// What a test printed, or an error of it, a failed expectation with
/// `isFailure`.
typedef _Output = ({String text, bool error, bool isFailure});

/// A failure of a test: whether it is a failed expectation, and its
/// message.
typedef _Failure = ({bool expectation, String message});

/// A test of a run, as the report shows it.
final class _Test {
  _Test(this.name, this.path, {required this.declaredSkip});

  /// The full name of the test.
  final String name;

  /// The path of its test file, with `/` between its names, or `null` if the
  /// report does not give it.
  final String? path;

  /// Whether its declaration skips it.
  final bool declaredSkip;

  /// Its result, `success`, `failure` or `error`, or `null` if it did not
  /// finish.
  String? result;

  /// Whether it was skipped.
  bool skipped = false;

  /// Whether the report hides it, as it hides a test that loads a test file
  /// when it passes.
  bool hidden = false;

  /// What it printed and its errors, in order.
  final List<_Output> output = [];

  /// Its result, `skipped` for a test that was skipped and `did not finish`
  /// for one that did not finish.
  String get outcome => switch (result) {
        null => 'did not finish',
        _success when skipped => 'skipped',
        final String result => result,
      };

  /// Its first failure: its first error, or, for an error with which
  /// flutter_test fails a widget test after it printed what was thrown, the
  /// first thing that it printed as thrown; `null` without an error.
  _Failure? get firstFailure {
    final index = output.indexWhere((output) => output.error);
    if (index < 0) return null;
    final (:text, error: _, :isFailure) = output[index];
    if (isFailure) return (expectation: true, message: text);
    if (text.startsWith(_reportedAbove)) {
      for (final printed in output.take(index)) {
        if (_thrownIn(printed.text) case final failure?) return failure;
      }
    }
    return (expectation: false, message: text);
  }
}

/// How the error with which flutter_test fails a widget test starts: it
/// printed what was thrown before.
const _reportedAbove = 'Test failed. See exception logs above.';

/// What flutter_test printed as thrown in [text], or `null` if [text] is no
/// such report. Its message is what follows the header, `══╡ EXCEPTION
/// CAUGHT BY … ╞`, and the line of what was thrown, such as `The following
/// TestFailure was thrown running a test:` for a failed expectation, up to
/// the stack or to the end of the report. Without that line, it is no
/// failed expectation.
_Failure? _thrownIn(String text) {
  if (!text.startsWith('══╡ EXCEPTION CAUGHT BY ')) return null;
  final lines = const LineSplitter().convert(text);
  final thrown = _thrown.firstMatch(lines.skip(1).join('\n'));
  return (
    expectation: thrown?[1] == 'TestFailure',
    message: lines
        .skip(thrown == null ? 1 : 2)
        .takeWhile((line) => !_endsMessage(line))
        .join('\n')
        .trim(),
  );
}

/// The line of what was thrown, right after the header of what flutter_test
/// printed, with what was thrown, such as `TestFailure` or `StateError`.
final _thrown = RegExp('^The following (.+?) was thrown');

/// Whether [line] of what flutter_test printed as thrown ends its message.
bool _endsMessage(String line) =>
    line.startsWith('═') ||
    line.startsWith('When the exception was thrown, this was the stack') ||
    line.startsWith('The relevant error-causing widget was') ||
    line.startsWith('This was caught by the test expectation') ||
    line.startsWith('The test description was');
