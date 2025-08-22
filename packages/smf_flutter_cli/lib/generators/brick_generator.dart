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

import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/generators/generator.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';

/// Generates files from module-provided mason bricks.
class BrickGenerator extends Generator {
  /// Creates a [BrickGenerator] that uses the provided [moduleResolver].
  const BrickGenerator(this.moduleResolver);

  /// Resolves module dependencies and dependents during brick generation.
  final ModuleDependencyResolver moduleResolver;

  @override
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  ) async {
    final disabledModules = <IModuleCodeContributor>{};

    for (final module in modules) {
      for (final brick in module.brickContributions) {
        if (disabledModules.contains(module)) continue;

        final generator = await MasonGenerator.fromBundle(brick.bundle);

        final target = DirectoryGeneratorTarget(Directory(generateTo));

        final vars = coreVars..addAll(brick.vars ?? {});
        try {
          await generator.hooks.preGen(
            vars: vars,
            onVarsChanged: vars.addAll,
            logger: logger,
          );

          final generateProgress = logger.progress(
            '🔄 Generating from ${brick.name}',
          );

          final files = await generator.generate(
            target,
            vars: vars,
            fileConflictResolution: mapMergeStrategy(brick.mergeStrategy),
            logger: logger,
          );

          generateProgress.complete('✅ Generated ${files.length} file(s)');

          await generator.hooks.postGen(vars: vars, logger: logger);
        } on Exception catch (e) {
          logger.detail(
            'Error during pre-generation for module '
            "'${module.moduleDescriptor.name}': $e",
          );

          disabledModules
            ..add(module)
            ..addAll(
              moduleResolver.dependentsOf(module, modules),
            );
        }
      }
    }

    if (disabledModules.isNotEmpty) {
      final excludedNames =
          disabledModules.map((m) => m.moduleDescriptor.name).join(', ');

      logger.info(
        '⚠️ Errors occurred during generation.\n'
        'Excluding the following modules (and their dependents):\n'
        '$excludedNames',
      );

      modules.removeWhere(disabledModules.contains);
    }
  }
}
