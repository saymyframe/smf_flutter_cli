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
// It runs the step of the job Native caches too, with a stand-in of gh: on
// main it lists the entries of the native caches of each prefix of main,
// all pages and the newest first, and deletes every entry but the newest of
// its family, the part of its key before the week. A list or a deletion
// that fails only warns. The job needs the job that calls apps.yml, whose
// jobs save the entries, and runs when one of them failed.
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

/// The name of the job of build.yml that deletes the entries of the native
/// caches that a newer entry of their family replaced.
const nativeCachesJob = 'Native caches';

/// The problems of the job [nativeCachesJob] of [workflow], the text of
/// build.yml: there is no such job, or it does not need the job that calls
/// apps.yml, whose jobs save the entries, or does not run when one of them
/// failed, or its step that deletes the entries runs in other runs than
/// those on main.
List<String> nativeCachesProblemsOf(String workflow) {
  final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
  final job = jobs.values.cast<YamlMap>().where(
        (job) => job['name'] == nativeCachesJob,
      );
  if (job.length != 1) {
    return [_notOneNativeCachesJob(job.length)];
  }
  final apps = [
    for (final MapEntry(:key, :value) in jobs.entries)
      if ('${(value as YamlMap)['uses'] ?? ''}'.endsWith('/apps.yml')) key,
  ];
  final needs = switch (job.single['needs']) {
    final String job => {job},
    final YamlList list => {...list},
    _ => const <Object?>{},
  };
  final condition = '${job.single['if'] ?? ''}';
  final step = _deletionStepOf(job.single);
  return [
    for (final job in apps)
      if (!needs.contains(job)) _beforeTheWriters(job),
    if (!condition.contains('!cancelled()') && !condition.contains('always()'))
      _notAfterFailure,
    if (!'${step['if'] ?? ''}'.contains("github.ref == 'refs/heads/main'"))
      _deletesOutsideMain,
  ];
}

/// The problem that the workflow has [count] jobs [nativeCachesJob].
String _notOneNativeCachesJob(int count) =>
    'The workflow has $count jobs named $nativeCachesJob rather than one.';

/// The step of [job], the job [nativeCachesJob], that deletes the entries.
YamlMap _deletionStepOf(YamlMap job) =>
    (job['steps'] as YamlList).cast<YamlMap>().singleWhere(
          (step) => '${step['run'] ?? ''}'.contains('/actions/caches'),
        );

/// The problem that the job [nativeCachesJob] does not need [job], which
/// calls apps.yml.
String _beforeTheWriters(Object? job) =>
    'The job $nativeCachesJob does not need the job $job, so it may delete '
    'the entries before the jobs of $job save the new ones, and keep an '
    'entry that a new one replaces in the same run.';

const _notAfterFailure = 'The job $nativeCachesJob has no if: '
    r'${{ !cancelled() }}, so it does not run when a job with Flutter '
    'failed, though the jobs that write the entries may have saved them.';

const _deletesOutsideMain = 'The step of the job $nativeCachesJob that '
    "deletes the entries has no if: github.ref == 'refs/heads/main': it "
    'would list and delete the entries in the runs of pull requests too, '
    'which save none.';

/// The entries of the caches of the repository that the stand-in of gh of
/// [runNativeCaches] has: the id, the key, the ref and the time when it was
/// saved, of the entries of the families `aaa` and `bbb` of Gradle and
/// `ccc` of Swift packages, of an older key without a family of these, and
/// of an entry of a pull request, the newest of all.
const nativeCacheEntries = [
  (101, 'Linux-gradle-3.44.2-aaa-2026W43', 'refs/heads/main', 90),
  (102, 'Linux-gradle-3.44.2-bbb-2026W43', 'refs/heads/main', 80),
  (103, 'Linux-gradle-3.44.2-aaa-2026W42', 'refs/heads/main', 70),
  (104, 'Linux-gradle-b989-2026-41', 'refs/heads/main', 30),
  (105, 'Linux-gradle-3.44.2-bbb-2026W41', 'refs/heads/main', 20),
  (109, 'Linux-gradle-3.44.2-aaa-2026W44', 'refs/pull/7/merge', 95),
  (201, 'macOS-swiftpm-ccc-2026W43', 'refs/heads/main', 85),
  (202, 'macOS-swiftpm-ccc-2026W42', 'refs/heads/main', 50),
  (203, 'macOS-swiftpm-2026-40', 'refs/heads/main', 10),
];

/// The ids of [nativeCacheEntries] that the step deletes: those of main but
/// the newest of each family, the part of the key before its last hyphen.
const deletedNativeCacheEntries = {103, 105, 202};

/// A stand-in of gh, which notes each call in `$GH_LOG`, the arguments
/// apart by tabs, and answers `gh api --method GET .../actions/caches` with
/// the entries of `$GH_ENTRIES` whose key starts with the field `key` and,
/// with the field `ref`, of that ref, in the order of the time when they
/// were saved, the newest first with the field `direction=desc`, each as
/// `<id> <key>`, as the `--jq` of the step prints them; without
/// `--paginate` only those of the first page, of two entries. A list of
/// the key `$GH_FAIL_LIST` and a deletion of the id `$GH_FAIL_DELETE` fail.
const _gh = r'''
#!/usr/bin/env bash
{ printf '%s\t' "$@"; printf '\n'; } >> "$GH_LOG"
method=GET paginate=false path= key= ref= direction=
while [ $# -gt 0 ]; do
  case "$1" in
    api) ;;
    --method | -X) method="$2"; shift ;;
    --paginate) paginate=true ;;
    -f | -F | --raw-field | --field)
      case "$2" in
        key=*) key="${2#key=}" ;;
        ref=*) ref="${2#ref=}" ;;
        direction=*) direction="${2#direction=}" ;;
      esac
      shift
      ;;
    --jq | -q) shift ;;
    *) path="$1" ;;
  esac
  shift
done
if [ "$method" = DELETE ]; then
  if [ "${path##*/}" = "${GH_FAIL_DELETE:-}" ]; then
    echo 'HTTP 500: Internal Server Error' >&2
    exit 1
  fi
  exit 0
fi
if [ "$key" = "${GH_FAIL_LIST:-}" ]; then
  echo 'HTTP 502: Bad Gateway' >&2
  exit 1
fi
order=-n
if [ "$direction" = desc ]; then
  order=-rn
fi
entries="$(awk -F '\t' -v key="$key" -v ref="$ref" \
  'index($2, key) == 1 && (ref == "" || $3 == ref) { print $4 " " $1 " " $2 }' \
  "$GH_ENTRIES" | sort $order | cut -d ' ' -f 2-)"
if [ "$paginate" = false ]; then
  entries="$(printf '%s\n' "$entries" | head -n 2)"
fi
printf '%s\n' "$entries" | sed '/^$/d'
''';

/// What the step of the job [nativeCachesJob] of [workflow], the text of
/// build.yml, did when it ran as on main with a stand-in of gh that has
/// [nativeCacheEntries]: the result of bash, and the arguments of each call
/// of gh. The list of the entries of the prefix [failList] and the deletion
/// of the entry [failDelete] fail.
({ProcessResult result, List<List<String>> calls}) runNativeCaches(
  String workflow, {
  String? failList,
  int? failDelete,
}) {
  final jobs = (loadYaml(workflow) as YamlMap)['jobs'] as YamlMap;
  final job = jobs.values
      .cast<YamlMap>()
      .singleWhere((job) => job['name'] == nativeCachesJob);
  final directory = Directory.systemTemp.createTempSync('native_caches_');
  try {
    final gh = File('${directory.path}/bin/gh')
      ..createSync(recursive: true)
      ..writeAsStringSync(_gh);
    Process.runSync('chmod', ['+x', gh.path]);
    final entries = File('${directory.path}/entries.tsv')
      ..writeAsStringSync(
        [
          for (final (id, key, ref, saved) in nativeCacheEntries)
            '$id\t$key\t$ref\t$saved\n',
        ].join(),
      );
    final log = File('${directory.path}/gh.log')..createSync();
    final result = Process.runSync(
      'bash',
      ['-e', '-o', 'pipefail', '-c', _deletionStepOf(job)['run'] as String],
      environment: {
        'PATH': '${gh.parent.path}:${Platform.environment['PATH']}',
        'GH_TOKEN': 'token',
        'GITHUB_REPOSITORY': 'saymyframe/smf_flutter_cli',
        'GITHUB_REF': 'refs/heads/main',
        'GH_ENTRIES': entries.path,
        'GH_LOG': log.path,
        'GH_FAIL_LIST': failList ?? '',
        'GH_FAIL_DELETE': '${failDelete ?? ''}',
      },
    );
    return (
      result: result,
      calls: [
        for (final line in log.readAsLinesSync())
          line.split('\t')..removeLast(),
      ],
    );
  } finally {
    directory.deleteSync(recursive: true);
  }
}

/// The ids of the entries that [calls] of gh delete.
List<int> deletedIn(List<List<String>> calls) => [
      for (final call in calls)
        if (call.contains('DELETE')) int.parse(call.last.split('/').last),
    ];

/// The problems of what the step of the job [nativeCachesJob] of
/// [workflow], the text of build.yml, does on main (see [runNativeCaches]):
/// it lists the entries of a prefix of the keys of the jobs of apps.yml
/// that save them without all pages, the filter of the ref of main, or the
/// order of the newest first, deletes other entries than those that a newer
/// entry of their family replaced, or fails.
List<String> nativeCachesRunProblemsOf(String workflow) {
  final (:result, :calls) = runNativeCaches(workflow);
  final problems = <String>[];
  for (final prefix in ['Linux-gradle-', 'macOS-swiftpm-']) {
    final list = calls.where((call) => call.contains('key=$prefix'));
    final missing = [
      for (final argument in [
        'GET',
        '--paginate',
        'repos/saymyframe/smf_flutter_cli/actions/caches',
        'ref=refs/heads/main',
        'sort=created_at',
        'direction=desc',
      ])
        if (!list.any((call) => call.contains(argument))) argument,
    ];
    if (list.isEmpty || missing.isNotEmpty) {
      problems.add(
        'The step of $nativeCachesJob lists the entries $prefix* without '
        '${missing.join(', ')}: it would not see every entry of main, or '
        'take an entry of another ref or an older one for the newest of its '
        'family.',
      );
    }
  }
  final deleted = deletedIn(calls).toSet();
  if (deleted.length != deletedNativeCacheEntries.length ||
      !deleted.containsAll(deletedNativeCacheEntries)) {
    problems.add(
      'The step of $nativeCachesJob deletes the entries ${deleted.toList()} '
      'rather than ${deletedNativeCacheEntries.toList()}, those of main but '
      'the newest of each family.',
    );
  }
  if (result.exitCode != 0) {
    problems.add(
      'The step of $nativeCachesJob fails: ${result.stdout}${result.stderr}',
    );
  }
  return problems;
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

  group('the job Native caches of build.yml', () {
    /// The text of build.yml.
    String build() {
      final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
      expect(top.exitCode, 0, reason: '${top.stderr}');
      return File('${'${top.stdout}'.trim()}/.github/workflows/build.yml')
          .readAsStringSync();
    }

    /// [text] with [from] replaced by [to], which it must have.
    String replaced(String text, String from, String to) {
      expect(text, contains(from));
      return text.replaceFirst(from, to);
    }

    test(
        'needs the job of the jobs with Flutter, runs when one of them '
        'failed, and deletes the entries only on main', () {
      final workflow = build();
      expect(nativeCachesProblemsOf(workflow), isEmpty);

      expect(
        nativeCachesProblemsOf(
          replaced(
            workflow,
            '    name: Native caches\n    needs: apps\n',
            '    name: Native caches\n',
          ),
        ),
        [_beforeTheWriters('apps')],
      );
      expect(
        nativeCachesProblemsOf(
          replaced(
            workflow,
            '    needs: apps\n    if: \${{ !cancelled() }}\n',
            '    needs: apps\n',
          ),
        ),
        [_notAfterFailure],
      );
      expect(
        nativeCachesProblemsOf(
          replaced(
            workflow,
            "        if: github.ref == 'refs/heads/main'\n"
                '        env:\n          GH_TOKEN:',
            '        env:\n          GH_TOKEN:',
          ),
        ),
        [_deletesOutsideMain],
      );
      expect(
        nativeCachesProblemsOf(
          replaced(workflow, 'name: Native caches', 'name: Caches'),
        ),
        [_notOneNativeCachesJob(0)],
      );
    });

    group(
      'runs its step on main with a stand-in of gh, which',
      () {
        test(
            'lists the entries of each prefix of main, all pages and the '
            'newest first, and deletes every entry but the newest of its '
            'family', () {
          final (:result, :calls) = runNativeCaches(build());

          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}${result.stderr}',
          );
          expect(nativeCachesRunProblemsOf(build()), isEmpty);
          for (final prefix in ['Linux-gradle-', 'macOS-swiftpm-']) {
            expect(
              calls,
              contains(
                containsAll([
                  'api',
                  'GET',
                  '--paginate',
                  'repos/saymyframe/smf_flutter_cli/actions/caches',
                  'key=$prefix',
                  'ref=refs/heads/main',
                  'sort=created_at',
                  'direction=desc',
                ]),
              ),
            );
          }
          expect(deletedIn(calls), deletedNativeCacheEntries.toList());
          expect(
            '${result.stdout}',
            allOf(
              contains('Keeps Linux-gradle-3.44.2-aaa-2026W43, the newest '),
              contains('Keeps Linux-gradle-b989-2026-41, the newest '),
              contains('Deleted Linux-gradle-3.44.2-aaa-2026W42, which a '),
              isNot(contains('::warning::')),
            ),
          );
        });

        test('only warns when a list fails, and goes on with the next one', () {
          final (:result, :calls) =
              runNativeCaches(build(), failList: 'Linux-gradle-');

          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}${result.stderr}',
          );
          expect(
            '${result.stdout}',
            contains(
              '::warning::The caches Linux-gradle-* could not be listed;',
            ),
          );
          expect(deletedIn(calls), [202]);
        });

        test('only warns when a deletion fails, and goes on with the next one',
            () {
          final (:result, :calls) = runNativeCaches(build(), failDelete: 103);

          expect(
            result.exitCode,
            0,
            reason: '${result.stdout}${result.stderr}',
          );
          expect(
            '${result.stdout}',
            contains(
              '::warning::The cache Linux-gradle-3.44.2-aaa-2026W42, which a '
              'newer entry of its family replaced, could not be deleted;',
            ),
          );
          expect(deletedIn(calls), [103, 105, 202]);
        });

        test(
            'finds a step that lists the oldest entries first, or the entries '
            'of every ref, or only the first page of them', () {
          final workflow = build();
          for (final (from, to, missing) in [
            ('-f direction=desc', '-f direction=asc', 'direction=desc'),
            (r' -f ref="$GITHUB_REF"', '', 'ref=refs/heads/main'),
            (' --paginate', '', '--paginate'),
          ]) {
            final problems = nativeCachesRunProblemsOf(
              replaced(workflow, from, to),
            );
            expect(
              problems,
              containsAll([
                startsWith(
                  'The step of Native caches lists the entries Linux-gradle-* '
                  'without $missing:',
                ),
                startsWith('The step of Native caches deletes the entries '),
              ]),
              reason: to,
            );
          }
        });
      },
      testOn: '!windows',
    );
  });
}
