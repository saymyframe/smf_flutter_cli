// Checks the plan that the matrix tools print with --plan, which the job
// Plan of .github/workflows/apps.yml turns into the matrices of the other
// jobs: the combinations of the providers that the apps with every module of
// the matrices cover, the shards of each matrix, and, of the tool of the
// CLI, the apps that CI builds, archives and starts on devices, one for
// each job. So a new provider or module changes the plan, not the
// workflow.
import 'dart:convert';
import 'dart:io';

import 'package:test/test.dart';

/// The root of this repository.
String _root() {
  final top = Process.runSync('git', ['rev-parse', '--show-toplevel']);
  expect(top.exitCode, 0, reason: '${top.stderr}');
  return '${top.stdout}'.trim();
}

/// The plan that the matrix tool at [tool] of the repository prints with
/// `--plan` and [options].
Future<Map<String, Object?>> _planOf(
  String tool, [
  List<String> options = const [],
]) async {
  final result = await Process.run(
    Platform.resolvedExecutable,
    ['run', tool, '--plan', ...options],
    workingDirectory: _root(),
    stdoutEncoding: utf8,
    stderrEncoding: utf8,
  );
  expect(result.exitCode, 0, reason: '${result.stdout}${result.stderr}');
  final lines = const LineSplitter().convert('${result.stdout}');
  expect(lines, hasLength(1), reason: 'One line of JSON for GITHUB_OUTPUT.');
  return jsonDecode(lines.single) as Map<String, Object?>;
}

/// Matches the shards of a plan: `1/n` to `n/n`, for one or more.
final Matcher _shards = predicate<Object?>(
  (shards) {
    if (shards is! List || shards.isEmpty) return false;
    final count = shards.length;
    return [
          for (var shard = 1; shard <= count; shard++) '$shard/$count',
        ].join(',') ==
        shards.join(',');
  },
  'the shards 1/n to n/n',
);

/// Matches a list of the names of apps with every module, one or more.
final Matcher _apps = allOf(
  isA<List<Object?>>(),
  isNotEmpty,
  everyElement(allOf(isA<String>(), startsWith('every module'))),
);

void main() {
  const cli = 'packages/smf_flutter_cli/tool/matrix.dart';
  const fixtures = 'packages/smf_pipeline/fixture_registry/tool/matrix.dart';

  test(
    'the tool of the CLI plans a pairwise covering of the apps with every '
    'module in the shards of its matrix, and the apps that CI builds, '
    'starts and configures with Firebase, one for each job',
    () async {
      final plan = await _planOf(cli);

      expect(plan.keys, ['combinations', 'shards', 'apps', 'start', 'entries']);
      expect(plan['combinations'], 'pairwise');
      expect(plan['shards'], _shards);
      expect(plan['apps'], _apps);
      expect(plan['start'], _apps);
      expect(plan['entries'], _apps);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'with every combination, the tool of the CLI plans all of them, or a '
    '3-wise covering of more than 100',
    () async {
      final plan = await _planOf(cli, ['--every-combination']);

      expect(plan['combinations'], anyOf('all', '3-wise'));
      expect(plan['shards'], _shards);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );

  test(
    'the tool of the fixtures plans the shards of its matrix, and no apps to '
    'build',
    () async {
      final plan = await _planOf(fixtures);

      expect(plan.keys, ['combinations', 'shards']);
      expect(plan['combinations'], 'pairwise');
      expect(plan['shards'], _shards);
    },
    timeout: const Timeout(Duration(minutes: 3)),
  );
}
