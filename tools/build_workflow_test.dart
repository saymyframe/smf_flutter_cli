// Checks that the job CI of .github/workflows/build.yml needs every other
// job of the workflow, and runs when one of them failed. The ruleset of
// main requires CI rather than each job, and CI fails only when a job it
// needs fails: a job added to the workflow but not to the needs of CI could
// fail, and the pull request could still be merged. Without its condition,
// CI would be skipped when a job it needs failed, and a ruleset takes a
// skipped check as passed.
//
// It runs the step of CI that sums up the results too: CI passes only when
// every job it needs succeeded, or was skipped in a run that does not run
// every job. GitHub has more results than failure and cancelled, such as
// abandoned for the jobs of a called workflow when no runner took one of
// them, and CI fails on each.
//
// It also checks that a run of Build of a pull request that is merged or
// closed stops, as nobody needs its checks any more: a workflow that runs
// when a pull request is closed joins the concurrency group of the runs of
// Build of the pull request with cancel-in-progress, and GitHub cancels a
// run in the group that is still in progress. Concurrency groups are shared
// by the workflows of a repository.
//
// And it checks that only the runs of pull requests and of main scan the
// code with SonarCloud. The scanner tells SonarCloud the pull request of the
// run of a pull request, and SonarCloud stores the scan of a run by hand on
// another branch as the analysis of main: until the next push to main, the
// issues of main would be those of that branch.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The problems of the [workflow], the text of a workflow of GitHub Actions:
/// it has no job named CI, or more than one, or the job CI does not need
/// another job of the workflow, or does not run when one of them failed.
List<String> problemsOf(String workflow) {
  final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
  final ci = [
    for (final MapEntry(:key, :value) in jobs.entries)
      if ((value as YamlMap)['name'] == 'CI') key as String,
  ];
  if (ci.length != 1) {
    return ['The workflow has ${ci.length} jobs named CI rather than one.'];
  }
  final job = jobs[ci.single] as YamlMap;
  final needs = switch (job['needs']) {
    final String job => {job},
    final YamlList list => {...list},
    _ => const <Object?>{},
  };
  final condition = '${job['if'] ?? ''}';
  return [
    for (final other in jobs.keys)
      if (other != ci.single && !needs.contains(other)) _notNeeded(other),
    if (!condition.contains('!cancelled()') && !condition.contains('always()'))
      _skipped,
  ];
}

String _notNeeded(Object? job) =>
    'CI does not need the job $job, so it would not fail when $job does.';

const _skipped = r'CI has no if: ${{ !cancelled() }}, so it would be skipped '
    'when a job it needs failed, and a ruleset takes a skipped check as '
    'passed.';

/// The problems of the cancelling of the runs of Build, [workflows] by the
/// name of their file: no workflow that runs when a pull request is closed
/// joins the concurrency group of the runs of Build of the pull request, in
/// `build.yml`, with cancel-in-progress.
List<String> cancelProblemsOf(Map<String, String> workflows) {
  final build = loadYaml(workflows['build.yml']!) as YamlMap;
  final group = _groupOf(build, 'pull_request');
  final joining = [
    for (final MapEntry(key: file, value: text) in workflows.entries)
      if (file != 'build.yml')
        if (loadYaml(text) as YamlMap case final workflow
            when _runsWhenClosed(workflow) &&
                _groupOf(workflow, 'pull_request') == group &&
                (workflow['concurrency'] as YamlMap?)?['cancel-in-progress'] ==
                    true)
          file,
  ];
  return [if (joining.isEmpty) _notCancelled(group)];
}

/// The problem that no workflow cancels the runs of Build in [group].
String _notCancelled(String? group) =>
    'No workflow that runs when a pull request is closed joins the '
    'concurrency group of the runs of Build of the pull request, $group, '
    'with cancel-in-progress, so a run of Build goes on after the pull '
    'request is merged or closed, though nobody needs its checks.';

/// Whether [workflow] runs when a pull request is closed.
bool _runsWhenClosed(YamlMap workflow) => switch (workflow['on']) {
      final YamlMap on => switch (on['pull_request']) {
          final YamlMap event =>
            (event['types'] as YamlList?)?.contains('closed') ?? false,
          _ => false,
        },
      _ => false,
    };

/// The concurrency group of [workflow] for the event [event] of the pull
/// request 42, with the expressions of the contexts of GitHub that a group
/// takes evaluated: `github.workflow`, the name of the workflow,
/// `github.ref`, the ref of the merge of the pull request, and
/// `github.event.pull_request.number`, the number of the pull request, or
/// the first of several with a value, such as in `a || b`; `null` without a
/// group.
String? _groupOf(YamlMap workflow, String event) {
  final group = (workflow['concurrency'] as YamlMap?)?['group'];
  if (group is! String) return null;
  String valueOf(String name) => switch (name.trim()) {
        'github.workflow' => '${workflow['name']}',
        'github.ref' => 'refs/pull/42/merge',
        'github.event.pull_request.number' =>
          event == 'pull_request' ? '42' : '',
        'github.event_name' => event,
        final other => throw ArgumentError('No value for $other.'),
      };
  return group.replaceAllMapped(
    RegExp(r'\$\{\{(.*?)\}\}'),
    (match) => match[1]!
        .split('||')
        .map(valueOf)
        .firstWhere((value) => value.isNotEmpty, orElse: () => ''),
  );
}

/// The problems of the scans of SonarCloud in [workflows], the texts of the
/// workflows of GitHub Actions by the names of their files: a step that
/// scans in a run that is neither the run of a pull request nor a run on
/// main, by the conditions of its job and of the step in each run of
/// [_runsOf] its workflow, and no step that scans a push to main or the run
/// of a pull request.
List<String> sonarProblemsOf(Map<String, String> workflows) {
  final problems = <String>[];
  var main = false;
  var pullRequest = false;
  for (final MapEntry(key: file, value: text) in workflows.entries) {
    final workflow = loadYaml(text) as YamlMap;
    for (final MapEntry(key: id, value: job)
        in (workflow['jobs'] as YamlMap? ?? YamlMap()).entries) {
      final steps = (job as YamlMap)['steps'] as List? ?? const [];
      for (final step in steps.cast<YamlMap>()) {
        if (!_scan.hasMatch('${step['uses'] ?? ''}')) continue;
        for (final run in _runsOf(workflow)) {
          if (!_holds(job['if'], run) || !_holds(step['if'], run)) continue;
          if (run.event == 'pull_request') {
            pullRequest = true;
          } else if (run.ref == _mainRef) {
            main = main || run.event == 'push';
          } else {
            problems.add(_scansBranch(file, id, step['name'], run));
          }
        }
      }
    }
  }
  return [
    ...problems,
    if (!main) _mainUnscanned,
    if (!pullRequest) _pullRequestsUnscanned,
  ];
}

/// The `uses` of a step that scans the code with SonarCloud.
final _scan = RegExp(
  '^SonarSource/(sonarqube-scan-action|sonarcloud-github-action)@',
  caseSensitive: false,
);

const _mainRef = 'refs/heads/main';

/// A run of a workflow: the event that started it, the ref it runs on, and
/// for a pull request the branch that the pull request goes into.
typedef _Run = ({String event, String ref, String baseRef});

/// The runs of [workflow] that tell where SonarCloud stores a scan: for each
/// event that starts it, a run on main and a run on another branch,
/// `feature`, as far as the event has them. A push runs on the branches that
/// the workflow lists, all of them when it lists none or a pattern, and a
/// schedule on main only. The run of a pull request has the ref of its
/// merge, and goes into main or into another branch.
List<_Run> _runsOf(YamlMap workflow) {
  final events = switch (workflow['on']) {
    final String event => {event: null},
    final YamlList events => {for (final event in events) '$event': null},
    final YamlMap events => {
        for (final MapEntry(:key, :value) in events.entries) '$key': value,
      },
    _ => const <String, Object?>{},
  };
  const branches = [_mainRef, 'refs/heads/feature'];
  return [
    for (final MapEntry(key: event, value: filters) in events.entries)
      ...switch ((event, filters)) {
        ('pull_request', _) => [
            for (final base in ['main', 'feature'])
              (event: event, ref: 'refs/pull/42/merge', baseRef: base),
          ],
        ('schedule', _) => [(event: event, ref: _mainRef, baseRef: '')],
        ('push', {'branches': final YamlList listed})
            when !listed.any((branch) => '$branch'.contains('*')) =>
          [
            for (final branch in listed)
              (event: event, ref: 'refs/heads/$branch', baseRef: ''),
          ],
        _ => [
            for (final ref in branches) (event: event, ref: ref, baseRef: ''),
          ],
      },
  ];
}

/// Whether [condition], the `if` of a job or of a step, with or without
/// `${{ }}`, holds in [run]; a job or a step without one runs. It reads `!`,
/// `==`, `!=`, `&&`, `||`, parentheses, strings, `true` and `false`, the
/// functions of the status of the job, which take every step before to have
/// succeeded, and the contexts `github.event_name`, `github.ref` and
/// `github.base_ref`. Anything else throws, so that the check fails on a
/// condition that it cannot read rather than guess.
bool _holds(Object? condition, _Run run) {
  if (condition == null || condition is bool) {
    return condition as bool? ?? true;
  }
  var text = '$condition'.trim();
  if (text.startsWith(r'${{') && text.endsWith('}}')) {
    text = text.substring(3, text.length - 2);
  }
  final tokens = [
    for (final match in RegExp(
      r"\|\||&&|==|!=|!|\(|\)|'(?:[^']|'')*'|[\w.-]+|\S",
    ).allMatches(text))
      match[0]!,
  ];
  var at = 0;
  String? peek() => at < tokens.length ? tokens[at] : null;
  String next() => at < tokens.length
      ? tokens[at++]
      : throw FormatException('The condition $condition ends too early.');
  void expect(String token) {
    if (next() != token) {
      throw FormatException('The condition $condition lacks $token.');
    }
  }

  bool truthy(Object? value) =>
      value is bool ? value : value is String && value.isNotEmpty;
  late final Object? Function() or;
  Object? primary() {
    final token = next();
    if (token == '(') {
      final value = or();
      expect(')');
      return value;
    }
    if (token.startsWith("'")) {
      return token.substring(1, token.length - 1).replaceAll("''", "'");
    }
    if (peek() == '(') {
      next();
      expect(')');
      return switch (token) {
        'success' || 'always' => true,
        'cancelled' || 'failure' => false,
        _ => throw ArgumentError('The check cannot read $token() in '
            '$condition.'),
      };
    }
    return switch (token) {
      'true' => true,
      'false' => false,
      'github.event_name' => run.event,
      'github.ref' => run.ref,
      'github.base_ref' => run.baseRef,
      _ => throw ArgumentError('The check cannot read $token in $condition.'),
    };
  }

  Object? comparison() {
    final left = primary();
    if (peek() case final operator? when operator == '==' || operator == '!=') {
      next();
      final right = primary();
      // GitHub compares strings without their case.
      final equal = '$left'.toLowerCase() == '$right'.toLowerCase();
      return operator == '==' ? equal : !equal;
    }
    return left;
  }

  Object? unary() {
    if (peek() != '!') return comparison();
    next();
    return !truthy(unary());
  }

  Object? and() {
    var value = unary();
    while (peek() == '&&') {
      next();
      final right = unary();
      value = truthy(value) && truthy(right);
    }
    return value;
  }

  or = () {
    var value = and();
    while (peek() == '||') {
      next();
      final right = and();
      value = truthy(value) || truthy(right);
    }
    return value;
  };
  final value = or();
  if (peek() case final rest?) {
    throw FormatException('The condition $condition has $rest after its end.');
  }
  return truthy(value);
}

/// The problem that the step [step] of the job [job] of the workflow [file]
/// scans the code with SonarCloud in [run].
String _scansBranch(String file, Object? job, Object? step, _Run run) =>
    '$file, job $job, step "$step" scans the code with SonarCloud in a run '
    'of ${run.event} on ${run.ref}, which is neither the run of a pull '
    'request nor a run on main, and SonarCloud stores its scan as the '
    'analysis of main: keep the step to the runs of pull requests and of '
    r"main, such as with if: ${{ github.event_name == 'pull_request' || "
    "github.ref == 'refs/heads/main' }}.";

const _mainUnscanned = 'No step of a workflow scans the code with SonarCloud '
    'in a push to main, so SonarCloud has no analysis of main to show and '
    'to compare the pull requests with.';

const _pullRequestsUnscanned = 'No step of a workflow scans the code with '
    'SonarCloud in the run of a pull request, so nobody sees the issues of a '
    'pull request before it is merged.';

void main() {
  test('finds the jobs that the job CI does not need', () {
    expect(
      problemsOf(r'''
jobs:
  a:
    name: A
  b:
    name: B
  c:
    name: C
  ci:
    name: CI
    needs: [a, c]
    if: ${{ !cancelled() }}
'''),
      ['CI does not need the job b, so it would not fail when b does.'],
    );
    expect(
      problemsOf(r'''
jobs:
  a:
    runs-on: ubuntu-latest
  all:
    name: CI
    needs: a
    if: ${{ !cancelled() }}
'''),
      isEmpty,
    );
    expect(
      problemsOf(r'''
jobs:
  a:
    name: A
  all:
    name: CI
    if: ${{ !cancelled() }}
'''),
      ['CI does not need the job a, so it would not fail when a does.'],
    );
  });

  test('finds a job CI that a failed job would skip', () {
    expect(
      problemsOf('''
jobs:
  a:
    name: A
  ci:
    name: CI
    needs: a
'''),
      [_skipped],
    );
  });

  test('finds a workflow without a job named CI', () {
    expect(problemsOf('jobs:\n  a:\n    name: A\n'), [
      'The workflow has 0 jobs named CI rather than one.',
    ]);
  });

  test('the job CI of build.yml needs every other job of the workflow', () {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    final root = '${top.stdout}'.trim();
    final workflow = File('$root/.github/workflows/build.yml');

    expect(problemsOf(workflow.readAsStringSync()), isEmpty);
  });

  group(
    'the job CI of build.yml',
    () {
      /// Runs the step of the job CI that sums up the [results] of the jobs it
      /// needs, each by the id of its job, as GitHub runs it, in a run that
      /// runs every job or not ([everyJob]).
      ProcessResult sumUp(Map<String, String> results, {bool everyJob = true}) {
        final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
        expect(top.exitCode, 0, reason: '${top.stderr}');
        final workflow = File(
          '${'${top.stdout}'.trim()}/.github/workflows/build.yml',
        );
        final jobs = (loadYaml(workflow.readAsStringSync()) as YamlMap)['jobs']
            as YamlMap;
        final ci = jobs.values
            .cast<YamlMap>()
            .singleWhere((job) => job['name'] == 'CI');
        final step = (ci['steps'] as YamlList).cast<YamlMap>().singleWhere(
              (step) =>
                  (step['env'] as YamlMap?)?.containsKey('NEEDS') ?? false,
            );
        return Process.runSync(
          'bash',
          ['-e', '-c', step['run'] as String],
          environment: {
            'NEEDS': jsonEncode({
              for (final MapEntry(:key, :value) in results.entries)
                key: {'result': value, 'outputs': <String, String>{}},
            }),
            'EVERY_JOB': '$everyJob',
          },
        );
      }

      test('passes when every job it needs succeeded', () {
        final result = sumUp({'checks': 'success', 'apps': 'success'});

        expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
        expect('${result.stdout}', 'checks: success\napps: success\n');
      });

      test('fails on a job that failed or was cancelled', () {
        for (final bad in ['failure', 'cancelled']) {
          final result = sumUp({'checks': 'success', 'apps': bad});

          expect(result.exitCode, 1, reason: bad);
          expect(
            '${result.stdout}',
            endsWith('::error::These jobs did not succeed: apps ($bad).\n'),
          );
        }
      });

      test(
          'fails on a job with a result that it does not know, as when no '
          'runner took a job of a called workflow', () {
        final result = sumUp({
          'checks': 'success',
          'apps': 'abandoned',
          'windows-install': 'success',
        });

        expect(result.exitCode, 1, reason: '${result.stdout}${result.stderr}');
        expect(
          '${result.stdout}',
          endsWith('::error::These jobs did not succeed: apps (abandoned).\n'),
        );
      });

      test('fails on a skipped job only in a run that runs every job', () {
        final results = {'checks': 'success', 'apps': 'skipped'};

        expect(sumUp(results, everyJob: false).exitCode, 0);
        final result = sumUp(results);
        expect(result.exitCode, 1);
        expect(
          '${result.stdout}',
          contains('::error::These jobs were skipped, though '),
        );
      });
    },
    testOn: '!windows',
  );

  test(
      'finds that no workflow cancels the run of Build of a closed pull '
      'request', () {
    const build = r'''
name: Build
on:
  pull_request:
concurrency:
  group: build-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: true
''';
    const cancel = r'''
name: Cancel
on:
  pull_request:
    types: [ closed ]
concurrency:
  group: build-${{ github.event.pull_request.number }}
  cancel-in-progress: true
''';
    expect(
      cancelProblemsOf({'build.yml': build, 'cancel.yml': cancel}),
      isEmpty,
    );
    // A group by the name of the workflow, which no other workflow has.
    expect(
      cancelProblemsOf({
        'build.yml': build.replaceFirst(
          r'build-${{ github.event.pull_request.number || github.ref }}',
          r'${{ github.workflow }}-${{ github.ref }}',
        ),
        'cancel.yml': cancel,
      }),
      [
        startsWith(
          'No workflow that runs when a pull request is closed joins the '
          'concurrency group of the runs of Build of the pull request, '
          'Build-refs/pull/42/merge, with cancel-in-progress',
        ),
      ],
    );
    // Without cancel-in-progress, or not on the closing of a pull request.
    expect(
      cancelProblemsOf({
        'build.yml': build,
        'cancel.yml': cancel.replaceFirst(
          'cancel-in-progress: true',
          'cancel-in-progress: false',
        ),
      }),
      hasLength(1),
    );
    expect(
      cancelProblemsOf({
        'build.yml': build,
        'cancel.yml': cancel.replaceFirst('[ closed ]', '[ opened ]'),
      }),
      hasLength(1),
    );
  });

  test(
      'a workflow of the repository cancels the run of Build of a pull '
      'request that is merged or closed', () {
    final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
    expect(top.exitCode, 0, reason: '${top.stderr}');
    final root = '${top.stdout}'.trim();
    final workflows = {
      for (final entity in Directory('$root/.github/workflows').listSync())
        if (entity is File && RegExp(r'\.ya?ml$').hasMatch(entity.path))
          entity.uri.pathSegments.last: entity.readAsStringSync(),
    };

    expect(cancelProblemsOf(workflows), isEmpty);
  });

  group('the scans of SonarCloud', () {
    /// A workflow like build.yml whose step scans with [condition], and
    /// whose job has [jobCondition].
    String build({String? condition, String? jobCondition}) => '''
name: Build
on:
  push:
    branches:
      - main
  pull_request:
  workflow_dispatch:
jobs:
  checks:
    name: Checks
${jobCondition == null ? '' : '    if: $jobCondition\n'}    steps:
      - name: Test
        run: dart test
      - name: SonarQube Scan
${condition == null ? '' : '        if: $condition\n'}        uses: SonarSource/sonarqube-scan-action@v8
''';

    test('finds a scan in a run by hand on another branch than main', () {
      expect(sonarProblemsOf({'build.yml': build()}), [
        startsWith(
          'build.yml, job checks, step "SonarQube Scan" scans the code with '
          'SonarCloud in a run of workflow_dispatch on refs/heads/feature, '
          'which is neither the run of a pull request nor a run on main',
        ),
      ]);
      expect(
        sonarProblemsOf({
          'build.yml': build(
            condition: r"${{ github.event_name == 'pull_request' || "
                "github.ref == 'refs/heads/main' }}",
          ),
        }),
        isEmpty,
      );
      // By the condition of the job, and without ${{ }}.
      expect(
        sonarProblemsOf({
          'build.yml': build(
            jobCondition: "github.event_name != 'workflow_dispatch'",
          ),
        }),
        isEmpty,
      );
      expect(
        sonarProblemsOf({
          'build.yml': build(
            condition: r'${{ !cancelled() && (github.event_name != '
                "'workflow_dispatch' || github.ref == 'refs/heads/MAIN') }}",
          ),
        }),
        isEmpty,
      );
    });

    test('finds a scan in a push to another branch than main', () {
      expect(
        sonarProblemsOf({
          'build.yml': build().replaceFirst(
            '    branches:\n      - main\n',
            "    branches:\n      - main\n      - 'release/**'\n",
          ),
        }),
        [
          contains('in a run of push on refs/heads/feature'),
          contains('in a run of workflow_dispatch on refs/heads/feature'),
        ],
      );
    });

    test('finds that nothing scans a push to main or a pull request', () {
      expect(
        sonarProblemsOf({
          'build.yml': build(
            condition: r"${{ github.event_name == 'pull_request' }}",
          ),
        }),
        [_mainUnscanned],
      );
      expect(
        sonarProblemsOf({
          'build.yml': build(condition: "github.ref == 'refs/heads/main'"),
        }),
        [_pullRequestsUnscanned],
      );
      expect(
        sonarProblemsOf({'build.yml': build(condition: 'false')}),
        [_mainUnscanned, _pullRequestsUnscanned],
      );
    });

    test('fails on a condition that it cannot read', () {
      expect(
        () => sonarProblemsOf({
          'build.yml': build(condition: "steps.test.outcome == 'success'"),
        }),
        throwsA(
          isA<ArgumentError>().having(
            (error) => '${error.message}',
            'message',
            contains('cannot read steps.test.outcome'),
          ),
        ),
      );
      expect(
        () => sonarProblemsOf({
          'build.yml': build(condition: "(github.ref == 'refs/heads/main'"),
        }),
        throwsFormatException,
      );
    });

    test(
        'the workflows of the repository scan only the runs of pull requests '
        'and of main', () {
      final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
      expect(top.exitCode, 0, reason: '${top.stderr}');
      final root = '${top.stdout}'.trim();
      final workflows = {
        for (final entity in Directory('$root/.github/workflows').listSync())
          if (entity is File && RegExp(r'\.ya?ml$').hasMatch(entity.path))
            entity.uri.pathSegments.last: entity.readAsStringSync(),
      };

      expect(sonarProblemsOf(workflows), isEmpty);
    });
  });
}
