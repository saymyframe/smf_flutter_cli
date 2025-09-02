import 'dart:io';

/// Fetches required external repositories into the local `packages/` directory.
///
/// - Supports `--force` to re-clone even if the directory exists.
/// - Supports `--no-shallow` to disable shallow clone (depth=1 by default).
Future<void> main(List<String> args) async {
  final force = args.contains('--force');
  final shallow = !args.contains('--no-shallow');

  final repositories = <_RepoSpec>[
    _RepoSpec(
      name: 'smf_modules',
      url: 'https://github.com/saymyframe/smf_modules',
      targetDir: Directory('packages/smf_modules'),
    ),
    _RepoSpec(
      name: 'smf_contracts',
      url: 'https://github.com/saymyframe/smf_contracts.git',
      targetDir: Directory('packages/smf_contracts'),
    ),
  ];

  final gitAvailable = await _isGitAvailable();
  if (!gitAvailable) {
    stderr.writeln(
      '❌ Git is not available. Please install Git to clone repositories.',
    );
    exit(1);
  }

  for (final repo in repositories) {
    await _cloneRepository(repo, force: force, shallow: shallow);
  }
}

class _RepoSpec {
  const _RepoSpec({
    required this.name,
    required this.url,
    required this.targetDir,
  });

  final String name;
  final String url;
  final Directory targetDir;
}

Future<void> _cloneRepository(
  _RepoSpec repo, {
  required bool force,
  required bool shallow,
}) async {
  final targetDir = repo.targetDir;

  if (targetDir.existsSync()) {
    // Safety: do not overwrite existing directory unless --force
    if (!force) {
      stdout
        ..writeln(
          'ℹ️ ${targetDir.path} already exists. '
          'Skipping clone of ${repo.name}.',
        )
        ..writeln(
          '   Use `dart tools/fetch_modules.dart --force` to reclone.',
        );
      return;
    }

    stdout.writeln(
      '⚠️ --force specified. Removing existing directory: ${targetDir.path}',
    );
    try {
      targetDir.deleteSync(recursive: true);
    } on FileSystemException catch (e) {
      stderr.writeln(
        '❌ Failed to remove existing directory ${targetDir.path}: $e',
      );
      exit(1);
    }
  }

  targetDir.createSync(recursive: true);
  final cloneArgs = <String>['clone'];
  if (shallow) cloneArgs.addAll(['--depth', '1']);
  cloneArgs.addAll([repo.url, targetDir.path]);

  stdout.writeln('⬇️ Cloning ${repo.name} from ${repo.url} ...');
  final result = await Process.run('git', cloneArgs, runInShell: true);
  stdout
    ..write(result.stdout)
    ..write('');
  stderr
    ..write(result.stderr)
    ..write('');
  if (result.exitCode != 0) {
    stderr.writeln('❌ Failed to clone ${repo.name}.');
    exit(result.exitCode);
  }

  stdout.writeln('✅ ${repo.name} cloned to ${targetDir.path}');
}

Future<bool> _isGitAvailable() async {
  try {
    final res = await Process.run('git', ['--version'], runInShell: true);
    return res.exitCode == 0;
  } on ProcessException {
    return false;
  }
}
