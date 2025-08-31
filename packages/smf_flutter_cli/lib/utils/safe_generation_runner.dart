// Copyright 2025 SayMyFrame. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'dart:io';

import 'package:interact/interact.dart';
import 'package:mason/mason.dart';
import 'package:path/path.dart' as p;
import 'package:smf_flutter_cli/cli_engine.dart';
import 'package:smf_flutter_cli/promts/models/cli_context.dart';
import 'package:smf_flutter_cli/promts/theme.dart';

/// Runs project generation into a temporary workspace and moves the result
/// to the final destination upon success. Always cleans up the temp directory.
class SafeGenerationRunner {
  /// Performs safe generation using the CLI engine and the provided [context].
  ///
  /// Steps:
  /// - Create temp workspace (cross-platform)
  /// - Clone [context] with [outputDirectory] replaced to temp path
  /// - Run generation into temp
  /// - Resolve destination conflicts (replace/copy/cancel)
  /// - Move temp project to final destination
  /// - Always delete temp workspace
  Future<void> run(
    CliContext context, {
    String onConflict = 'prompt',
  }) async {
    final logger = context.logger;
    final tempRoot = await Directory.systemTemp.createTemp('smf_cli');

    // Generation will happen into: <tempRoot>/<app_name>
    final tempContext = CliContext(
      name: context.name,
      selectedModules: context.selectedModules,
      outputDirectory: tempRoot.path,
      logger: logger,
      strictMode: context.strictMode,
      packageName: context.packageName,
      initialRoute: context.initialRoute,
      moduleResolver: context.moduleResolver,
    );

    try {
      await runCli(tempContext);

      final appName = context.name;
      final tempProjectDir = p.join(tempRoot.path, appName);
      final desiredDest = p.join(context.outputDirectory, appName);

      final destinationPath = await _resolveDestinationPath(
        desiredDest,
        logger: logger,
        onConflict: onConflict,
      );

      logger.detail('📁 Moving project to: $destinationPath');
      await _moveDirectoryRobust(tempProjectDir, destinationPath);
      logger.success('✅  Project created at: $destinationPath');
    } on Exception catch (_) {
    } finally {
      // Best-effort cleanup
      if (tempRoot.existsSync()) {
        await tempRoot.delete(recursive: true);
      }
    }
  }

  Future<String> _resolveDestinationPath(
    String desiredPath, {
    required Logger logger,
    String onConflict = 'prompt',
  }) async {
    final destDir = Directory(desiredPath);
    if (!destDir.existsSync()) return desiredPath;

    if (onConflict != 'prompt') {
      switch (onConflict) {
        case 'replace':
          logger.warn('⚠️ Removing existing directory: ${destDir.path}');
          await destDir.delete(recursive: true);
          return desiredPath;

        case 'copy':
          final unique = _computeCopyDestination(desiredPath);
          logger.info('Creating a copy destination: $unique');
          return unique;

        case 'cancel':
          logger.warn('⚠️ Operation cancelled by user.');
          throw throw Exception('User canceled operation');
      }
    }

    final choiceIndex = Select.withTheme(
      prompt: 'Target directory already exists. What would you like to do?',
      options: const <String>['Replace', 'Create copy', 'Cancel'],
      theme: terminalTheme,
    ).interact();

    switch (choiceIndex) {
      case 0:
        logger.warn('⚠️ Removing existing directory: ${destDir.path}');
        await destDir.delete(recursive: true);
        return desiredPath;

      case 1:
        final unique = _computeCopyDestination(desiredPath);
        logger.info('Creating a copy destination: $unique');
        return unique;

      case 2:
      default:
        logger.warn('⚠️ Operation cancelled by user.');
        throw Exception('User canceled operation');
    }
  }

  String _computeCopyDestination(String basePath) {
    final parent = p.dirname(basePath);
    final name = p.basename(basePath);

    final firstCandidate = p.join(parent, '$name copy');
    if (!Directory(firstCandidate).existsSync()) return firstCandidate;

    var index = 2;
    while (true) {
      final candidate = p.join(parent, '$name copy $index');
      if (!Directory(candidate).existsSync()) return candidate;
      index++;
    }
  }

  Future<void> _moveDirectoryRobust(String source, String destination) async {
    final srcDir = Directory(source);
    if (!srcDir.existsSync()) {
      throw FileSystemException('Source directory does not exist', source);
    }

    final destDir = Directory(destination);
    if (!destDir.parent.existsSync()) {
      await destDir.parent.create(recursive: true);
    }

    try {
      await srcDir.rename(destination);
    } on FileSystemException {
      await _copyDirectory(srcDir, destDir);
      await srcDir.delete(recursive: true);
    }
  }

  Future<void> _copyDirectory(Directory source, Directory destination) async {
    await destination.create(recursive: true);
    await for (final entity
        in source.list(recursive: true, followLinks: false)) {
      final relativePath = p.relative(entity.path, from: source.path);
      final newPath = p.join(destination.path, relativePath);

      if (entity is File) {
        await File(newPath).create(recursive: true);
        await entity.copy(newPath);
      } else if (entity is Directory) {
        await Directory(newPath).create(recursive: true);
      }
    }
  }
}
