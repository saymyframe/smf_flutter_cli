import 'dart:io';

Future<void> main() async {
  final masonRunner = await MasonRunner.detect();
  if (masonRunner == null) {
    stderr.writeln('⚠️ Mason CLI not found. Install it with:');
    stderr.writeln('   dart pub global activate mason_cli');
    // Optionally add to PATH: export PATH="$HOME/.pub-cache/bin:$PATH"
    exit(127);
  }

  final bricksRoot = Directory('bricks');
  if (!bricksRoot.existsSync()) {
    stdout.writeln('No bricks/ directory found. Nothing to bundle.');
    return;
  }

  final outputDirectory = ensureOutputDirectory();
  cleanExistingBundles(outputDirectory);

  final brickDirectories = findBrickDirectories(bricksRoot);
  int totalFailures = 0;
  for (final brickDirectory in brickDirectories) {
    final success = await bundleBrickDirectory(
      masonRunner: masonRunner,
      brickDirectory: brickDirectory,
      outputDirectory: outputDirectory,
    );
    if (!success) totalFailures += 1;
  }

  if (totalFailures > 0) {
    exitCode = 1;
  }
}

// Orchestration helpers
Directory ensureOutputDirectory() {
  final output = Directory('lib/bundles');
  output.createSync(recursive: true);
  return output;
}

void cleanExistingBundles(Directory outputDirectory) {
  for (final file in outputDirectory.listSync().whereType<File>()) {
    if (file.path.endsWith('_bundle.dart')) {
      try {
        file.deleteSync();
      } catch (_) {
        // Ignore deletion failures – not critical
      }
    }
  }
}

List<Directory> findBrickDirectories(Directory bricksRoot) {
  return bricksRoot
      .listSync()
      .whereType<Directory>()
      .where((dir) => File('${dir.path}/brick.yaml').existsSync())
      .toList(growable: false);
}

Future<bool> bundleBrickDirectory({
  required MasonRunner masonRunner,
  required Directory brickDirectory,
  required Directory outputDirectory,
}) async {
  final result = await masonRunner.run([
    'bundle',
    brickDirectory.path,
    '-t',
    'dart',
    '-o',
    outputDirectory.path,
  ]);

  stdout.write(result.stdout);
  stderr.write(result.stderr);

  if (result.exitCode != 0) {
    stderr.writeln('❌ Mason bundling failed for ${brickDirectory.path}');
    return false;
  }
  return true;
}

// Mason CLI wrapper
class MasonRunner {
  MasonRunner({required this.executable, required this.prefixArgs});

  final String executable;
  final List<String> prefixArgs;

  static Future<MasonRunner?> detect() async {
    // Try native `mason`
    try {
      final probe = await Process.run('mason', ['--version'], runInShell: true);
      if (probe.exitCode == 0) {
        return MasonRunner(executable: 'mason', prefixArgs: const []);
      }
    } catch (_) {
      // Ignore – fall through to next strategy
    }

    // Try global pub invocation
    try {
      final probe = await Process.run(
        'dart',
        ['pub', 'global', 'run', 'mason_cli:mason', '--version'],
        runInShell: true,
      );
      if (probe.exitCode == 0) {
        return MasonRunner(
          executable: 'dart',
          prefixArgs: const ['pub', 'global', 'run', 'mason_cli:mason'],
        );
      }
    } catch (_) {
      // Ignore – no viable invocation found
    }

    return null;
  }

  Future<ProcessResult> run(List<String> args) async {
    final fullArgs = <String>[...prefixArgs, ...args];
    return Process.run(executable, fullArgs, runInShell: true);
  }
}
