// Checks that the job CI of .github/workflows/build.yml needs every other
// job of the workflow, and runs when one of them failed. The ruleset of
// main requires CI rather than each job, and CI fails only when a job it
// needs fails: a job added to the workflow but not to the needs of CI could
// fail, and the pull request could still be merged. Without its condition,
// CI would be skipped when a job it needs failed, and a ruleset takes a
// skipped check as passed.
//
// It also checks that a run of Build of a pull request that is merged or
// closed stops, as nobody needs its checks any more: a workflow that runs
// when a pull request is closed joins the concurrency group of the runs of
// Build of the pull request with cancel-in-progress, and GitHub cancels a
// run in the group that is still in progress. Concurrency groups are shared
// by the workflows of a repository.
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
}
