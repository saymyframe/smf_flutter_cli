import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:yaml/yaml.dart';
import 'package:yaml_edit/yaml_edit.dart';

Future<void> main() async {
  final modulesDirectory = Directory('packages/smf_modules');
  await _ensureSmfModulesPresent(modulesDirectory);

  final pubspecFile = File('packages/smf_flutter_cli/pubspec.yaml');
  if (!pubspecFile.existsSync()) {
    stderr.writeln('pubspec.yaml not found at ${pubspecFile.path}');
    exit(1);
  }

  final updated = await _rewriteDependenciesToLocalPaths(
    pubspecFile: pubspecFile,
    modulesDirectory: modulesDirectory,
  );

  if (updated) {
    stdout.writeln('\n✅ pubspec.yaml updated with local module paths.');
    stdout.writeln('Run: melos bootstrap');
  } else {
    stdout.writeln('\nℹ️ No changes were necessary. Local paths already set.');
  }
}

Future<void> _ensureSmfModulesPresent(Directory modulesDirectory) async {
  if (modulesDirectory.existsSync()) {
    // Directory already exists – assume developer manages updates.
    return;
  }

  // Ensure parent directory exists
  modulesDirectory.createSync(recursive: true);

  final gitAvailable = await _isGitAvailable();
  if (!gitAvailable) {
    stderr.writeln('⚠️ Git is not available. Please install Git to clone smf_modules.');
    stderr.writeln('Expected to clone into: ${modulesDirectory.path}');
    return;
  }

  final repoUrl = 'https://github.com/saymyframe/smf_modules';
  stdout.writeln('⬇️ Cloning smf_modules from $repoUrl ...');
  final result = await Process.run(
    'git',
    ['clone', '--depth', '1', repoUrl, modulesDirectory.path],
    runInShell: true,
  );
  stdout.write(result.stdout);
  stderr.write(result.stderr);
  if (result.exitCode != 0) {
    stderr.writeln('❌ Failed to clone smf_modules. You may need to clone it manually.');
  } else {
    stdout.writeln('✅ smf_modules cloned to ${modulesDirectory.path}');
  }
}

Future<bool> _isGitAvailable() async {
  try {
    final res = await Process.run('git', ['--version'], runInShell: true);
    return res.exitCode == 0;
  } catch (_) {
    return false;
  }
}

Future<bool> _rewriteDependenciesToLocalPaths({
  required File pubspecFile,
  required Directory modulesDirectory,
}) async {
  final originalContent = await pubspecFile.readAsString();
  final yaml = loadYaml(originalContent);
  if (yaml is! YamlMap) return false;

  final dependencies = yaml['dependencies'];
  if (dependencies is! YamlMap) return false;

  final editor = YamlEditor(originalContent);

  final pubspecDir = pubspecFile.parent.path;
  var madeChanges = false;

  for (final entry in dependencies.entries) {
    final packageName = entry.key as String;
    final spec = entry.value;

    final modulePath = p.normalize(p.join(modulesDirectory.path, packageName));
    if (!Directory(modulePath).existsSync()) {
      // Module directory not found – skip.
      continue;
    }

    final relativePath = p.normalize(p.relative(modulePath, from: pubspecDir));

    // Update when spec is a git map, or a path map with a different path.
    if (spec is YamlMap && spec.containsKey('git')) {
      editor.update(['dependencies', packageName], {'path': relativePath});
      stdout.writeln('🔄 Set $packageName -> path: $relativePath (from git)');
      madeChanges = true;
      continue;
    }

    if (spec is YamlMap && spec.containsKey('path')) {
      final currentPath = spec['path'] as String?;
      if (currentPath == null || p.normalize(currentPath) != relativePath) {
        editor.update(['dependencies', packageName], {'path': relativePath});
        stdout.writeln('🔄 Set $packageName -> path: $relativePath');
        madeChanges = true;
      }
      continue;
    }
  }

  if (madeChanges) {
    await pubspecFile.writeAsString(editor.toString());
  }

  return madeChanges;
}
