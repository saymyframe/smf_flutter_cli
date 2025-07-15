import 'dart:io';

import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/generators/generator.dart';

class BrickGenerator extends Generator {
  @override
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  ) async {
    for (final module in modules) {
      for (final brick in module.brickContributions) {
        final generator = await MasonGenerator.fromBundle(brick.bundle);

        final target = DirectoryGeneratorTarget(Directory(generateTo));

        final vars = coreVars..addAll(brick.vars ?? {});
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
      }
    }
  }
}
