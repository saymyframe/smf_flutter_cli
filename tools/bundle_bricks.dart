import 'dart:convert';
import 'dart:io';

Future<void> main() async {
  final runner = await MasonRunner.detect();
  if (runner == null) {
    _logError('Mason CLI not found. Install it with:\n   '
        'dart pub global activate mason_cli');
    // Optionally add to PATH: export PATH="$HOME/.pub-cache/bin:$PATH"
    exit(127);
  }

  final packageRoots = _determineTargetPackages();
  if (packageRoots.isEmpty) {
    _logInfo('No packages with bricks found. Nothing to bundle.');
    return;
  }

  var failures = 0;
  for (final packageRoot in packageRoots) {
    final bricksRoot = Directory('${packageRoot.path}/bricks');
    if (!bricksRoot.existsSync()) continue;

    final outputDir = _ensureBundlesOutput(packageRoot);
    _cleanExistingBundles(outputDir);

    final brickDirs = _findBrickDirectories(bricksRoot);
    if (brickDirs.isEmpty) continue;

    _logInfo('Bundling bricks for: ${packageRoot.path}');
    for (final brickDir in brickDirs) {
      _removeMacOsJunk(brickDir);
      await _embedHookAssets(brickDir);

      final ok = await _bundleBrick(
        runner: runner,
        brickDirectory: brickDir,
        outputDirectory: outputDir,
      );
      if (!ok) failures += 1;
    }
  }

  if (failures > 0) exitCode = 1;
}

// Discovery
List<Directory> _determineTargetPackages() {
  final melosPackagePath = Platform.environment['MELOS_PACKAGE_PATH'];
  if (melosPackagePath != null && melosPackagePath.isNotEmpty) {
    final pkg = Directory(melosPackagePath);
    return (pkg.existsSync() && Directory('${pkg.path}/bricks').existsSync())
        ? [pkg]
        : const [];
  }

  // Single-package invocation
  if (File('pubspec.yaml').existsSync() && Directory('bricks').existsSync()) {
    return [Directory.current];
  }

  // Workspace/monorepo invocation
  final rootPath = Platform.environment['MELOS_ROOT_PATH'];
  final root = (rootPath != null && rootPath.isNotEmpty)
      ? Directory(rootPath)
      : Directory.current;
  return _findPackagesWithBricks(root).toList(growable: false);
}

Set<Directory> _findPackagesWithBricks(Directory root) {
  final result = <Directory>{};
  if (!root.existsSync()) return result;

  final skipNames = <String>{
    '.git',
    '.dart_tool',
    'build',
    'ios',
    'android',
    '.idea',
    '.vscode',
    'node_modules',
    '.fvm',
  };

  final toVisit = <Directory>[root];
  while (toVisit.isNotEmpty) {
    final current = toVisit.removeLast();
    late final List<FileSystemEntity> children;
    try {
      children = current.listSync(followLinks: false);
    } on FileSystemException catch (_) {
      continue;
    }

    final isPackageRoot = File('${current.path}/pubspec.yaml').existsSync();
    final bricksDir = Directory('${current.path}/bricks');
    final hasBricks = bricksDir.existsSync() &&
        bricksDir
            .listSync()
            .whereType<Directory>()
            .any((d) => File('${d.path}/brick.yaml').existsSync());

    if (isPackageRoot && hasBricks) {
      result.add(current);
      // Do not traverse inside a package root further; continue with siblings
      continue;
    }

    for (final entity in children) {
      if (entity is! Directory) continue;
      final name = entity.uri.pathSegments.isNotEmpty
          ? entity.uri.pathSegments.last
          : '';
      if (skipNames.contains(name)) continue;
      toVisit.add(entity);
    }
  }
  return result;
}

// Bundling
Directory _ensureBundlesOutput(Directory packageRoot) {
  final dir = Directory('${packageRoot.path}/lib/bundles')
    ..createSync(recursive: true);
  return dir;
}

void _cleanExistingBundles(Directory outputDir) {
  for (final file in outputDir.listSync().whereType<File>()) {
    if (file.path.endsWith('_bundle.dart')) {
      try {
        file.deleteSync();
      } on FileSystemException {
        // Non-fatal
      }
    }
  }
}

List<Directory> _findBrickDirectories(Directory bricksRoot) {
  try {
    return bricksRoot
        .listSync()
        .whereType<Directory>()
        .where((dir) => File('${dir.path}/brick.yaml').existsSync())
        .toList(growable: false);
  } on FileSystemException {
    return const [];
  }
}

Future<bool> _bundleBrick({
  required MasonRunner runner,
  required Directory brickDirectory,
  required Directory outputDirectory,
}) async {
  final res = await runner.run([
    'bundle',
    brickDirectory.path,
    '-t',
    'dart',
    '-o',
    outputDirectory.path,
  ]);
  stdout.write(res.stdout);
  stderr.write(res.stderr);
  if (res.exitCode != 0) {
    _logError('Mason bundling failed for ${brickDirectory.path}');
    return false;
  }
  // Format the generated bundle file
  final brickName = brickDirectory.uri.pathSegments.isNotEmpty
      ? brickDirectory.uri.pathSegments.where((s) => s.isNotEmpty).last
      : 'bundle';
  final bundleFile =
      File('${outputDirectory.path}/' '${brickName}_bundle.dart');
  await _formatDart(bundleFile);
  return true;
}

void _removeMacOsJunk(Directory root) {
  try {
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        final name = entity.uri.pathSegments.isNotEmpty
            ? entity.uri.pathSegments.last
            : '';
        if (name == '.DS_Store' ||
            name.startsWith('.DS_') ||
            name.startsWith('._')) {
          try {
            entity.deleteSync();
          } on FileSystemException {
            /* ignore */
          }
        }
      }
    }
  } on FileSystemException {
    /* ignore */
  }
}

// Logging helpers
void _logInfo(String message) => stdout.writeln('ℹ️ $message');

void _logError(String message) => stderr.writeln('❌ $message');

// Formatting helper
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
      _logError('dart format failed for ${target.path}');
    }
  } on ProcessException {
    // Ignore formatting errors silently to not fail the bundling step
  }
}

// Embed hook assets (e.g., .sh, .ps1) into a generated Dart file consumed by hooks.
Future<void> _embedHookAssets(Directory brickDir) async {
  final assetsDir = Directory('${brickDir.path}/hooks/assets');
  if (!assetsDir.existsSync()) return;

  // Collect files
  late final List<File> files;
  try {
    files = assetsDir
        .listSync(recursive: true, followLinks: false)
        .whereType<File>()
        .where((f) {
      final name = f.uri.pathSegments.isNotEmpty ? f.uri.pathSegments.last : '';
      // Skip macOS junk and hidden metadata files
      if (name == '.DS_Store' ||
          name.startsWith('.DS_') ||
          name.startsWith('._')) {
        return false;
      }
      return true;
    }).toList(growable: false);
  } on FileSystemException {
    return;
  }
  if (files.isEmpty) return;

  final outDir = Directory('${brickDir.path}/hooks/lib/generated')
    ..createSync(recursive: true);
  final outFile = File('${outDir.path}/hook_assets.dart');

  final buffer = StringBuffer()
    ..writeln('// GENERATED CODE - DO NOT MODIFY BY HAND')
    ..writeln('// This file is generated by tools/bundle_bricks.dart')
    ..writeln('// Values are Base64-encoded file contents')
    ..writeln("// Keys are paths relative to 'hooks/assets' (posix style)")
    ..writeln('const Map<String, String> hookAssetsB64 = <String, String>{');

  for (final f in files) {
    // Use relative path from assetsDir as key
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

// Mason CLI wrapper
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
    } on ProcessException {
      /* ignore */
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
    } on ProcessException {
      /* ignore */
    }

    return null;
  }

  Future<ProcessResult> run(List<String> args) async {
    final fullArgs = <String>[...prefixArgs, ...args];
    return Process.run(executable, fullArgs, runInShell: true);
  }
}
