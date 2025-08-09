import 'dart:io';

Future<void> main(List<String> args) async {
  final targetDir = Directory('packages/smf_modules');
  final repoUrl = 'https://github.com/saymyframe/smf_modules';

  final force = args.contains('--force');
  final shallow = !args.contains('--no-shallow');

  if (targetDir.existsSync()) {
    // Safety: do not overwrite existing directory unless --force
    if (!force) {
      stdout.writeln('ℹ️ packages/smf_modules already exists. Skipping clone.');
      stdout.writeln('   Use `dart tools/fetch_modules.dart --force` to reclone.');
      return;
    }

    stdout.writeln('⚠️ --force specified. Removing existing directory...');
    try {
      targetDir.deleteSync(recursive: true);
    } catch (e) {
      stderr.writeln('❌ Failed to remove existing directory: $e');
      exit(1);
    }
  }

  final gitAvailable = await _isGitAvailable();
  if (!gitAvailable) {
    stderr.writeln('❌ Git is not available. Please install Git to clone smf_modules.');
    exit(1);
  }

  targetDir.createSync(recursive: true);
  final cloneArgs = <String>['clone'];
  if (shallow) cloneArgs.addAll(['--depth', '1']);
  cloneArgs.addAll([repoUrl, targetDir.path]);

  stdout.writeln('⬇️ Cloning smf_modules from $repoUrl ...');
  final result = await Process.run('git', cloneArgs, runInShell: true);
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr.writeln('❌ Failed to clone smf_modules.');
    exit(result.exitCode);
  }

  stdout.writeln('✅ smf_modules cloned to ${targetDir.path}');
}

Future<bool> _isGitAvailable() async {
  try {
    final res = await Process.run('git', ['--version'], runInShell: true);
    return res.exitCode == 0;
  } catch (_) {
    return false;
  }
}

