// Checks that the job CI of .github/workflows/build.yml needs every other
// job of the workflow, and runs when one of them failed. The ruleset of
// main requires CI rather than each job, and CI fails only when a job it
// needs fails: a job added to the workflow but not to the needs of CI could
// fail, and the pull request could still be merged. Without its condition,
// CI would be skipped when a job it needs failed, and a ruleset takes a
// skipped check as passed.
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
}
