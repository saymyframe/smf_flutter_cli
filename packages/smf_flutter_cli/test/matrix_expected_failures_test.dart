// Tests the check that the tests of an app of the matrix fail as expected,
// such as the tests of a role in an app whose provider of the role has a
// known bug: on reports of `flutter test --reporter json` written by hand,
// in the forms that package:test and flutter_test give them, and on the runs
// of such apps with the commands of the matrix replaced.
import 'dart:convert';

import 'package:file/memory.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/matrix.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:test/test.dart';

/// The directory of the app whose tests the reports report.
const _app = '/apps/app_1';

/// A report of `flutter test --reporter json`, one JSON object on each line:
/// the start of the run, [events], and the end of the run with [success],
/// unless it is `null`, as when the run stopped.
String _report(List<Map<String, Object?>> events, {bool? success = false}) => [
      jsonEncode({'protocolVersion': '0.1.1', 'type': 'start', 'time': 0}),
      for (final event in events) jsonEncode(event),
      if (success != null)
        jsonEncode({'success': success, 'type': 'done', 'time': 1}),
    ].join('\n');

/// The suite [id], the test file at [file] of the app.
Map<String, Object?> _suite(int id, String file) => {
      'type': 'suite',
      'suite': {'id': id, 'platform': 'vm', 'path': '$_app/$file'},
    };

/// The start of the test [id] named [name] of the suite [suite], which its
/// declaration skips with [skip].
Map<String, Object?> _start(
  int id,
  String name, {
  int suite = 0,
  bool skip = false,
}) =>
    {
      'type': 'testStart',
      'test': {
        'id': id,
        'name': name,
        'suiteID': suite,
        'groupIDs': <int>[],
        'metadata': {'skip': skip, 'skipReason': null},
      },
    };

/// What the test [test] printed.
Map<String, Object?> _print(int test, String message) => {
      'type': 'print',
      'testID': test,
      'messageType': 'print',
      'message': message,
    };

/// An error of the test [test], a failed expectation with [isFailure].
Map<String, Object?> _error(int test, String error, {bool isFailure = false}) =>
    {
      'type': 'error',
      'testID': test,
      'error': error,
      'stackTrace': '',
      'isFailure': isFailure,
    };

/// The end of the test [test].
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

/// What flutter_test prints when [thrown] was thrown with [message] while
/// a widget test ran, or while it built a widget for [library].
String _dump(
  String thrown,
  String message, {
  String library = 'FLUTTER TEST FRAMEWORK',
}) =>
    [
      '══╡ EXCEPTION CAUGHT BY $library ╞${'═' * 52}',
      'The following $thrown was thrown running a test:',
      message,
      '',
      'When the exception was thrown, this was the stack:',
      '#4      main.<anonymous closure> (file://$_app/test/a_test.dart:7:5)',
      '',
      'This was caught by the test expectation on the following line:',
      '  file://$_app/test/a_test.dart line 7',
      'The test description was:',
      '  a test',
      '═' * 100,
    ].join('\n');

/// A failed expectation with [reason], as matcher describes it.
String _expectation(String reason) =>
    "Expected: ['home']\n  Actual: ['home', 'home']\n"
    "   Which: at location [1] is 'home' instead of 'details'\n$reason";

/// The first line of the message of [_expectation].
const _firstLine = "Expected: ['home']";

/// The lines of the message of [_expectation] of [_reason] in a log.
const _indented = [
  "  Expected: ['home']",
  "    Actual: ['home', 'home']",
  "     Which: at location [1] is 'home' instead of 'details'",
  '  $_reason',
];

/// The events of the widget test [id] that fails as flutter_test reports
/// it: it prints each of [dumps], what was thrown, and then fails the test
/// with an error that refers to them.
List<Map<String, Object?>> _widgetFailure(int id, List<String> dumps) => [
      for (final dump in dumps) _print(id, dump),
      _error(
        id,
        'Test failed. See exception logs above.\n'
        'The test description was: a test',
      ),
      _done(id, result: 'error'),
    ];

/// The reason of the expectation that the expected test fails.
const _reason = 'Each screen the user sees is heard of once.';

/// The test that must fail.
const _expected = MatrixExpectedFailure('test/a_test.dart', 'a test', _reason);

/// A report in which the widget test `a test` of `test/a_test.dart` fails
/// with [dumps], and [others] follow.
String _failing(
  List<String> dumps, {
  List<Map<String, Object?>> others = const [],
}) =>
    _report([
      _suite(0, 'test/a_test.dart'),
      _start(1, 'loading $_app/test/a_test.dart'),
      _done(1, hidden: true),
      _start(2, 'a test'),
      ..._widgetFailure(2, dumps),
      ...others,
    ]);

/// A module whose contributions cannot be collected, so the case of an app
/// with it has errors.
final class _Broken extends SmfModule {
  const _Broken();

  static const id = ModuleId('broken');

  @override
  ModuleDescriptor get descriptor => const ModuleDescriptor(
        id: id,
        description: 'Broken',
        kind: ModuleKinds.infrastructure,
      );

  @override
  List<Contribution> contribute(ModuleContext context) =>
      throw StateError('broken');
}

void main() {
  group('expectedFailureProblems', () {
    test(
        'finds nothing when the expected test fails first on an expectation '
        'with the reason and the other tests pass, those that their '
        'declaration skips too', () {
      final others = [
        _start(3, 'another test'),
        _done(3),
        _start(4, 'a skipped test', skip: true),
        _done(4, skipped: true),
        _suite(5, 'test/b_test.dart'),
        _start(6, '(setUpAll)', suite: 5),
        _done(6, hidden: true),
        _start(7, 'a test', suite: 5),
        _print(7, 'A line that the test printed.'),
        _done(7),
        _start(8, '(tearDownAll)', suite: 5),
        _done(8, hidden: true),
      ];

      // A widget test, whose failure flutter_test prints before it fails
      // the test with an error.
      expect(
        expectedFailureProblems(
          _failing(
            [_dump('TestFailure', _expectation(_reason))],
            others: others,
          ),
          [_expected],
        ),
        isEmpty,
      );

      // A test of package:test, which fails with the failed expectation.
      expect(
        expectedFailureProblems(
          _report([
            _suite(0, 'test/a_test.dart'),
            _start(2, 'a test'),
            _error(2, _expectation(_reason), isFailure: true),
            _done(2, result: 'failure'),
            ...others,
          ]),
          [_expected],
        ),
        isEmpty,
      );

      // flutter_test wraps the long lines of what it prints; whitespace
      // counts as one space.
      expect(
        expectedFailureProblems(
          _failing([
            _dump(
              'TestFailure',
              _expectation('Each screen the user sees\n  is heard of  once.'),
            ),
          ]),
          [_expected],
        ),
        isEmpty,
      );
    });

    test('finds the tests that passed or were skipped, though they must fail',
        () {
      const other = MatrixExpectedFailure('test/b_test.dart', 'b test', 'B.');

      expect(
        expectedFailureProblems(
          _report(
            [
              _suite(0, 'test/a_test.dart'),
              _start(1, 'a test'),
              _done(1),
              _suite(2, 'test/b_test.dart'),
              _start(3, 'b test', suite: 2, skip: true),
              _done(3, skipped: true),
            ],
            success: true,
          ),
          [_expected, other],
        ),
        [
          equals(
            'The tests passed, but "a test" of test/a_test.dart, "b test" of '
            'test/b_test.dart must fail.',
          ),
          '"a test" of test/a_test.dart passed, but it must fail with "$_reason".',
          '"b test" of test/b_test.dart was skipped, but it must fail with "B.".',
        ],
      );
    });

    test(
        'finds the expected test that failed first on an expectation without '
        'the reason, and quotes the first line of its message', () {
      const problem = '"a test" of test/a_test.dart failed first with another '
          'message than "$_reason": $_firstLine';

      expect(
        expectedFailureProblems(
          _failing([_dump('TestFailure', _expectation('Another reason.'))]),
          [_expected],
        ),
        [problem],
      );

      // Its first failure counts, not one that came after it.
      expect(
        expectedFailureProblems(
          _failing([
            _dump('TestFailure', _expectation('Another reason.')),
            _dump('TestFailure', _expectation(_reason)),
          ]),
          [_expected],
        ),
        [problem],
      );
      expect(
        expectedFailureProblems(
          _report([
            _suite(0, 'test/a_test.dart'),
            _start(2, 'a test'),
            _error(2, _expectation('Another reason.'), isFailure: true),
            _error(2, _expectation(_reason), isFailure: true),
            _done(2, result: 'failure'),
          ]),
          [_expected],
        ),
        [problem],
      );

      // The description of the test that flutter_test prints after the
      // message is no part of it.
      expect(
        expectedFailureProblems(
          _failing([_dump('TestFailure', _expectation('Another reason.'))]),
          [const MatrixExpectedFailure('test/a_test.dart', 'a test', 'a test')],
        ),
        [
          equals(
            '"a test" of test/a_test.dart failed first with another message '
            'than "a test": $_firstLine',
          ),
        ],
      );
    });

    test(
        'finds the expected test that failed first with an error rather than '
        'a failed expectation: an exception, a timeout, or an error that '
        'flutter_test did not print', () {
      String problem(String firstLine) => '"a test" of test/a_test.dart '
          'failed first with an error rather than a failed expectation: '
          '$firstLine';

      // An exception of the test, with a failed expectation after it.
      expect(
        expectedFailureProblems(
          _failing([
            _dump('StateError', 'Bad state: thrown\nmore'),
            _dump('TestFailure', _expectation(_reason)),
          ]),
          [_expected],
        ),
        [problem('Bad state: thrown')],
      );
      // An exception while the app built a widget, which the test does not
      // throw itself.
      expect(
        expectedFailureProblems(
          _failing([
            _dump(
              'StateError',
              'Bad state: in build',
              library: 'WIDGETS LIBRARY',
            ),
          ]),
          [_expected],
        ),
        [problem('Bad state: in build')],
      );
      for (final (error, firstLine) in [
        // A test of package:test that throws.
        ('Bad state: thrown', 'Bad state: thrown'),
        // A widget test that times out, which prints nothing.
        (
          'TimeoutException after 0:02:00.000000: Test timed out after 2 '
              'minutes.',
          'TimeoutException after 0:02:00.000000: Test timed out after 2 '
              'minutes.',
        ),
        // A failure that refers to what flutter_test printed, which it did
        // not print.
        (
          'Test failed. See exception logs above.\nThe test description was: '
              'a test',
          'Test failed. See exception logs above.',
        ),
      ]) {
        expect(
          expectedFailureProblems(
            _report([
              _suite(0, 'test/a_test.dart'),
              _start(2, 'a test'),
              _print(2, 'Not what was thrown.'),
              _error(2, error),
              _done(2, result: 'error'),
            ]),
            [_expected],
          ),
          [problem(firstLine)],
          reason: error,
        );
      }

      // What flutter_test printed, but not what was thrown.
      expect(
        expectedFailureProblems(
          _failing([
            '══╡ EXCEPTION CAUGHT BY FLUTTER TEST FRAMEWORK ╞═══\n$_reason',
          ]),
          [_expected],
        ),
        [problem(_reason)],
      );
      // An error without a message.
      expect(
        expectedFailureProblems(
          _report([
            _suite(0, 'test/a_test.dart'),
            _start(2, 'a test'),
            _done(2, result: 'error'),
          ]),
          [_expected],
        ),
        [problem('error')],
      );
    });

    test(
        'finds the expected test that did not run or did not finish, and the '
        'run that did not finish', () {
      // A test of the name in another file is another test.
      expect(
        expectedFailureProblems(
          _report(
            [
              _suite(0, 'test/b_test.dart'),
              _start(1, 'a test'),
              _done(1),
            ],
            success: true,
          ),
          [_expected],
        ),
        [
          'The tests passed, but "a test" of test/a_test.dart must fail.',
          '"a test" of test/a_test.dart did not run.',
        ],
      );
      // A test file that does not compile, whose tests do not run.
      expect(
        expectedFailureProblems(
          _report([
            _suite(0, 'test/a_test.dart'),
            _start(1, 'loading $_app/test/a_test.dart'),
            _error(1, 'Failed to load "$_app/test/a_test.dart":\nError.'),
            _done(1, result: 'error'),
          ]),
          [_expected],
          directory: _app,
        ),
        [
          '"a test" of test/a_test.dart did not run.',
          equals(
            '"loading $_app/test/a_test.dart" of test/a_test.dart did not '
            'pass: Failed to load "$_app/test/a_test.dart":',
          ),
        ],
      );
      // A run that stopped while the test ran.
      expect(
        expectedFailureProblems(
          _report(
            [_suite(0, 'test/a_test.dart'), _start(2, 'a test')],
            success: null,
          ),
          [_expected],
        ),
        [
          '"a test" of test/a_test.dart did not finish.',
          'The run of the tests did not finish.',
        ],
      );
    });

    test(
        'finds every other test that did not pass or did not finish, and '
        'each that skipped itself, which the bug may make it do', () {
      expect(
        expectedFailureProblems(
          _failing(
            [_dump('TestFailure', _expectation(_reason))],
            others: [
              _start(3, 'another test'),
              ..._widgetFailure(3, [
                _dump('TestFailure', _expectation('Another reason.')),
              ]),
              _start(4, '(setUpAll)'),
              _error(4, 'Bad state: set up'),
              _done(4, result: 'error'),
              _start(5, 'a test that skips itself'),
              _done(5, skipped: true),
              _start(6, 'a test that does not finish'),
            ],
          ),
          [_expected],
          directory: _app,
        ),
        [
          '"another test" of test/a_test.dart did not pass: $_firstLine',
          '"(setUpAll)" of test/a_test.dart did not pass: Bad state: set up',
          equals(
            '"a test that skips itself" of test/a_test.dart skipped itself: '
            'only a test that its declaration skips may be skipped, as it is '
            'in every app.',
          ),
          '"a test that does not finish" of test/a_test.dart did not finish.',
        ],
      );
    });

    test(
        'reads what it can of a report, and finds a test file by its path in '
        'the app, whatever the directory of the app and the separators of the '
        'paths of the report', () {
      Map<String, Object?> suite(int id, String path) => {
            'type': 'suite',
            'suite': {'id': id, 'path': path},
          };
      final report = [
        'Resolving dependencies...',
        jsonEncode(suite(0, r'C:\apps\app_1\test\a_test.dart')),
        jsonEncode(suite(1, 'test/b_test.dart')),
        jsonEncode(suite(2, '/elsewhere/test/c_test.dart')),
        // A test of a suite that the report does not give.
        jsonEncode(_start(1, 'a test', suite: 7)),
        jsonEncode(_done(1)),
        // Events of a test that did not start.
        jsonEncode(_print(9, 'Printed.')),
        jsonEncode(_error(9, 'Bad state: 9')),
        jsonEncode(_done(9, result: 'error')),
        jsonEncode(_start(2, 'a test')),
        jsonEncode(_print(2, '')),
        jsonEncode(_error(2, _expectation(_reason), isFailure: true)),
        jsonEncode(_done(2, result: 'failure')),
        jsonEncode(_start(3, 'b test', suite: 1)),
        jsonEncode(_error(3, _expectation('B.'), isFailure: true)),
        jsonEncode(_done(3, result: 'failure')),
        jsonEncode(_start(4, 'c test', suite: 2)),
        jsonEncode(_error(4, 'Bad state: c')),
        jsonEncode(_done(4, result: 'error')),
        // The last line of a run that stopped.
        '{"type":"done","succ',
      ].join('\n');

      expect(
        expectedFailureProblems(
          report,
          [
            _expected,
            const MatrixExpectedFailure('test/b_test.dart', 'b test', 'B.'),
          ],
          directory: _app,
        ),
        [
          '"c test" of /elsewhere/test/c_test.dart did not pass: Bad state: c',
          'The run of the tests did not finish.',
        ],
      );
    });

    test('finds nothing when the tests pass and none must fail', () {
      expect(
        expectedFailureProblems(
          _report(
            [_suite(0, 'test/a_test.dart'), _start(1, 'a test'), _done(1)],
            success: true,
          ),
          const [],
        ),
        isEmpty,
      );
    });
  });

  group('testRunSummary', () {
    test(
        'has a line for each test that the report shows, with its result, its '
        'file in the app and its name, and the first lines of the first '
        'failure of each test that failed', () {
      final long = [for (var line = 1; line <= 25; line++) 'Line $line.'];

      expect(
        testRunSummary(
          [
            'Resolving dependencies...',
            _failing(
              [_dump('TestFailure', _expectation(_reason))],
              others: [
                _start(3, 'another test'),
                _done(3),
                _start(4, 'a skipped test', skip: true),
                _done(4, skipped: true),
                _start(5, 'a long failure'),
                _error(5, long.join('\n'), isFailure: true),
                _done(5, result: 'failure'),
                _start(6, 'a test that does not finish'),
              ],
            ),
          ].join('\n'),
          directory: _app,
        ),
        [
          'Resolving dependencies...',
          'error: test/a_test.dart: a test',
          ..._indented,
          'success: test/a_test.dart: another test',
          'skipped: test/a_test.dart: a skipped test',
          'failure: test/a_test.dart: a long failure',
          for (final line in long.take(20)) '  $line',
          '  … 5 more lines',
          'did not finish: test/a_test.dart: a test that does not finish',
        ],
      );
    });
  });

  group('the apps whose tests must fail', () {
    late MemoryFileSystem fileSystem;
    late List<String> commands;
    late List<String> log;
    const generated = GeneratedApp(name: 'app_1', path: _app);
    const app = MatrixApp('core', [FlutterCoreModule.id]);
    final core = MatrixAppTest('/tests/core', appliesTo: (_) => true);
    const expected = MatrixExpectedFailure(
      'test/core_test.dart',
      'a test',
      _reason,
    );

    /// A report in which `a test` of `test/core_test.dart` fails with the
    /// failed expectation [reason].
    String failingWith(String reason) => _report([
          _suite(0, 'test/core_test.dart'),
          _start(1, 'a test'),
          _error(1, _expectation(reason), isFailure: true),
          _done(1, result: 'failure'),
        ]);

    /// A `flutter` that records its commands, exits with [codes] of each,
    /// or 0, and gives [report] for `flutter test --reporter json`.
    MatrixFlutter flutter({
      required String report,
      Map<String, int> codes = const {},
    }) =>
        (arguments, directory) async {
          final command = arguments.join(' ');
          commands.add('$directory: $command');
          return (
            codes[command] ?? 0,
            command == 'test --reporter json' ? report : '[$command]',
          );
        };

    setUp(() {
      fileSystem = MemoryFileSystem();
      fileSystem.file('/tests/core/test/core_test.dart')
        ..createSync(recursive: true)
        ..writeAsStringSync('// {{app_name}}\n');
      commands = [];
      log = [];
    });

    group('runFailingAppTests', () {
      test(
          'adds the tests and their dev dependencies, analyzes the app with '
          'them, runs them, and finds nothing when they fail as expected',
          () async {
        final (problems, output) = await runFailingAppTests(
          generated,
          app,
          [
            MatrixAppTest(
              '/tests/core',
              appliesTo: (_) => true,
              devDependencies: const ['mocks'],
            ),
          ],
          [expected],
          flutter: flutter(report: failingWith(_reason)),
          fileSystem: fileSystem,
        );

        expect(problems, isEmpty);
        expect(commands, [
          '$_app: pub add dev:mocks',
          '$_app: analyze',
          '$_app: test --reporter json',
        ]);
        expect(
          output,
          [
            'Added the tests test/core_test.dart.',
            '[pub add dev:mocks][analyze]',
            'failure: test/core_test.dart: a test',
            ..._indented,
          ].join('\n'),
        );
        expect(
          fileSystem.file('$_app/test/core_test.dart').readAsStringSync(),
          '// app_1\n',
        );
      });

      test('finds the tests that do not fail as expected', () async {
        final (problems, _) = await runFailingAppTests(
          generated,
          app,
          [core],
          [expected],
          flutter: flutter(report: failingWith('Another reason.')),
          fileSystem: fileSystem,
        );

        expect(problems, [
          equals(
            '"a test" of test/core_test.dart failed first with another '
            'message than "$_reason": $_firstLine',
          ),
        ]);
      });

      test(
          'runs no test when the app with the tests has issues, or the files '
          'of the tests have a problem', () async {
        final (problems, output) = await runFailingAppTests(
          generated,
          app,
          [core],
          [expected],
          flutter: flutter(report: '', codes: {'analyze': 3}),
          fileSystem: fileSystem,
        );

        expect(problems, ['flutter analyze exited with 3.']);
        expect(commands, ['$_app: analyze']);
        expect(output, endsWith('\nflutter analyze exited with 3.'));

        final (unfilled, _) = await runFailingAppTests(
          generated,
          app,
          [
            MatrixAppTest(
              '/tests/core',
              appliesTo: (_) => true,
              values: (_) => {'app_name': '{{name}}'},
            ),
          ],
          [expected],
          flutter: flutter(report: ''),
          fileSystem: fileSystem,
        );

        expect(unfilled, [
          equals(
            'The tests of /tests/core keep {{name}} in test/core_test.dart: '
            'no value fills it.',
          ),
        ]);
        expect(commands, hasLength(1));
      });
    });

    group('runFailingApps', () {
      /// Runs [apps] with the tests of [core], whose report is [report],
      /// generating each app as `smf create` with [createCode] does.
      Future<int> run(
        List<MatrixFailingApp> apps, {
        required String report,
        int createCode = 0,
      }) =>
          runFailingApps(
            apps,
            directory: '/apps',
            appTests: MatrixAppTests([core]),
            commands: MatrixCommands(
              log: log.add,
              create: (arguments, onCreated) async {
                commands.add(arguments.take(4).join(' '));
                if (createCode == 0) {
                  onCreated(
                    GeneratedApp(
                      name: arguments[1],
                      path: '/apps/${arguments[1]}',
                    ),
                  );
                }
                return createCode;
              },
            ),
            flutter: flutter(report: report),
            fileSystem: fileSystem,
          );

      const failing = MatrixFailingApp(
        'core with a bug',
        modules: [FlutterCoreModule()],
        requested: [FlutterCoreModule.id],
        failures: [expected],
      );

      test(
          'generates the app of the case of each, with the modules of its '
          'registry, and passes when its tests fail as expected', () async {
        expect(await run([failing], report: failingWith(_reason)), 0);

        expect(commands, [
          'create app_1 -m flutter_core',
          '$_app: analyze',
          '$_app: test --reporter json',
        ]);
        expect(log.first, '\n=== app_1: core with a bug (flutter_core)');
        expect(log.last, '\n1 apps generated in /apps.');
      });

      test('fails when the tests of an app do not fail as expected', () async {
        expect(await run([failing], report: failingWith('Other.')), 1);

        expect(log.sublist(log.indexOf('Problems:') + 1), [
          equals(
            'app_1 (core with a bug (flutter_core)): "a test" of '
            'test/core_test.dart failed first with another message than '
            '"$_reason": $_firstLine',
          ),
        ]);
      });

      test(
          'fails when the case of an app has errors, or smf create fails, '
          'and generates it no further', () async {
        const broken = MatrixFailingApp(
          'broken',
          modules: [FlutterCoreModule(), _Broken()],
          requested: [_Broken.id],
          failures: [expected],
        );

        expect(await run([broken, failing], report: '', createCode: 1), 1);

        expect(commands, ['create app_2 -m flutter_core']);
        final problems = log.sublist(log.indexOf('Problems:') + 1);
        expect(problems, hasLength(2));
        expect(problems.first, startsWith('broken: '));
        expect(
          problems.last,
          'app_2 (core with a bug (flutter_core)): smf create exited with 1.',
        );
      });
    });

    test(
        'the app of a case whose tests must fail is the app of the matrix that '
        'the contract harness builds for it, with the data and roles of its '
        'case', () async {
      const failing = MatrixFailingApp(
        'core with a bug',
        modules: [FlutterCoreModule()],
        requested: [FlutterCoreModule.id],
        failures: [expected],
      );

      final (:result, app: built) = await failing.check();

      expect(result.errors, isEmpty);
      expect('$built', 'core with a bug (flutter_core)');
      expect(built!.hook, isNotNull);
      expect(
        built.createArguments('app_1', '/apps').take(4),
        ['create', 'app_1', '-m', 'flutter_core'],
      );

      final (result: broken, app: none) = await const MatrixFailingApp(
        'broken',
        modules: [_Broken()],
        requested: [_Broken.id],
        failures: [],
      ).check();

      expect(broken.errors, isNotEmpty);
      expect(none, isNull);
    });
  });
}
