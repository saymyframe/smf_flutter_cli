import 'dart:io';

Future<void> main() async {
  final runner = await MasonRunner.detect();
  if (runner == null) {
    _logError('Mason CLI not found. Install it with:\n   dart pub global activate mason_cli');
    // Optionally add to PATH: export PATH="$HOME/.pub-cache/bin:$PATH"
    exit(127);
  }

  final packageRoots = _determineTargetPackages();
  if (packageRoots.isEmpty) {
    _logInfo('No packages with bricks found. Nothing to bundle.');
    return;
  }

  int failures = 0;
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
      final ok = await _bundleBrick(runner: runner, brickDirectory: brickDir, outputDirectory: outputDir);
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
    return (pkg.existsSync() && Directory('${pkg.path}/bricks').existsSync()) ? [pkg] : const [];
  }

  // Single-package invocation
  if (File('pubspec.yaml').existsSync() && Directory('bricks').existsSync()) {
    return [Directory.current];
  }

  // Workspace/monorepo invocation
  final rootPath = Platform.environment['MELOS_ROOT_PATH'];
  final root = (rootPath != null && rootPath.isNotEmpty) ? Directory(rootPath) : Directory.current;
  return _findPackagesWithBricks(root).toList(growable: false);
}

Set<Directory> _findPackagesWithBricks(Directory root) {
  final result = <Directory>{};
  if (!root.existsSync()) return result;

  final skipNames = <String>{
    '.git', '.dart_tool', 'build', 'ios', 'android', '.idea', '.vscode', 'node_modules', '.fvm',
  };

  final toVisit = <Directory>[root];
  while (toVisit.isNotEmpty) {
    final current = toVisit.removeLast();
    late final List<FileSystemEntity> children;
    try {
      children = current.listSync(followLinks: false);
    } catch (_) {
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
      final name = entity.uri.pathSegments.isNotEmpty ? entity.uri.pathSegments.last : '';
      if (skipNames.contains(name)) continue;
      toVisit.add(entity);
    }
  }
  return result;
}

// Bundling
Directory _ensureBundlesOutput(Directory packageRoot) {
  final dir = Directory('${packageRoot.path}/lib/bundles');
  dir.createSync(recursive: true);
  return dir;
}

void _cleanExistingBundles(Directory outputDir) {
  for (final file in outputDir.listSync().whereType<File>()) {
    if (file.path.endsWith('_bundle.dart')) {
      try {
        file.deleteSync();
      } catch (_) {
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
  } catch (_) {
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
  return true;
}

void _removeMacOsJunk(Directory root) {
  try {
    for (final entity in root.listSync(recursive: true, followLinks: false)) {
      if (entity is File) {
        final name = entity.uri.pathSegments.isNotEmpty ? entity.uri.pathSegments.last : '';
        if (name == '.DS_Store' || name.startsWith('.DS_') || name.startsWith('._')) {
          try {
            entity.deleteSync();
          } catch (_) {/* ignore */}
        }
      }
    }
  } catch (_) {/* ignore */}
}

// Logging helpers
void _logInfo(String message) => stdout.writeln('ℹ️ $message');
void _logError(String message) => stderr.writeln('❌ $message');

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
    } catch (_) {/* ignore */}

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
    } catch (_) {/* ignore */}

    return null;
  }

  Future<ProcessResult> run(List<String> args) async {
    final fullArgs = <String>[...prefixArgs, ...args];
    return Process.run(executable, fullArgs, runInShell: true);
  }
}
