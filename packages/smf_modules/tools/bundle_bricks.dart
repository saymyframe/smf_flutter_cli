import 'dart:io';
import 'dart:convert';

Future<void> main() async {
  final masonRunner = await MasonRunner.detect();
  if (masonRunner == null) {
    stderr
      ..writeln('⚠️ Mason CLI not found. Install it with:')
      ..writeln('   dart pub global activate mason_cli');
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
  var totalFailures = 0;
  for (final brickDirectory in brickDirectories) {
    await _embedHookAssets(brickDirectory);
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

Directory ensureOutputDirectory() {
  final output = Directory('lib/bundles')..createSync(recursive: true);
  return output;
}

void cleanExistingBundles(Directory outputDirectory) {
  for (final file in outputDirectory.listSync().whereType<File>()) {
    if (file.path.endsWith('_bundle.dart')) {
      try {
        file.deleteSync();
      } on FileSystemException catch (e) {
        stderr.writeln(e);
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
  // Format the generated bundle
  final brickName = brickDirectory.uri.pathSegments.isNotEmpty
      ? brickDirectory.uri.pathSegments
          .where((s) => s.isNotEmpty)
          .last
      : 'bundle';
  final bundleFile = File('${outputDirectory.path}/' '${brickName}_bundle.dart');
  await _formatDart(bundleFile);
  return true;
}

class MasonRunner {
  MasonRunner({required this.executable, required this.prefixArgs});

  final String executable;
  final List<String> prefixArgs;

  static Future<MasonRunner?> detect() async {
    try {
      final probe = await Process.run('mason', ['--version'], runInShell: true);
      if (probe.exitCode == 0) {
        return MasonRunner(executable: 'mason', prefixArgs: const []);
      }
    } on ProcessException catch (e) {
      stderr.writeln(e);
    }

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
    } on ProcessException catch (e) {
      stderr.writeln(e);
    }

    return null;
  }

  Future<ProcessResult> run(List<String> args) async {
    final fullArgs = <String>[...prefixArgs, ...args];
    return Process.run(executable, fullArgs, runInShell: true);
  }
}

Future<void> _formatDart(File target) async {
  try {
    if (!target.existsSync()) return;
    final res = await Process.run(
      'dart',
      ['format', target.path],
      runInShell: true,
    );
    stdout.write(res.stdout);
    stderr.write(res.stderr);
    if (res.exitCode != 0) {
      stderr.writeln('⚠️ dart format failed for ${target.path}');
    }
  } on ProcessException catch (e) {
    stderr.writeln(e);
  }
}

Future<void> _embedHookAssets(Directory brickDir) async {
  final assetsDir = Directory('${brickDir.path}/hooks/assets');
  if (!assetsDir.existsSync()) return;

  late final List<File> files;
  try {
    files = assetsDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) {
          final name = f.uri.pathSegments.isNotEmpty
              ? f.uri.pathSegments.last
              : '';
          if (name == '.DS_Store' || name.startsWith('.DS_') || name.startsWith('._')) {
            return false;
          }
          return true;
        })
        .toList(growable: false);
  } on FileSystemException catch (e) {
    stderr.writeln(e);
    return;
  }
  if (files.isEmpty) return;

  final outDir = Directory('${brickDir.path}/hooks/lib/generated')
    ..createSync(recursive: true);
  final outFile = File('${outDir.path}/hook_assets.dart');

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('// This file is generated by packages/smf_modules/tools/bundle_bricks.dart')
    ..writeln('// Values are Base64-encoded file contents')
    ..writeln("// Keys are paths relative to 'hooks/assets' (posix style)")
    ..writeln('const Map<String, String> hookAssetsB64 = <String, String>{');

  for (final f in files) {
    final relPath = f.path.length > assetsDir.path.length
        ? f.path.substring(assetsDir.path.length + 1).replaceAll('\\', '/')
        : f.path.replaceAll('\\', '/');
    final bytes = await f.readAsBytes();
    final b64 = base64.encode(bytes);
    buffer.writeln('  ${jsonEncode(relPath)}: ${jsonEncode(b64)},');
  }
  buffer.writeln('};');

  await outFile.writeAsString(buffer.toString());
  await _formatDart(outFile);
}
