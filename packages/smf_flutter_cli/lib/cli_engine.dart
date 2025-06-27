import 'dart:io';

import 'package:mason/mason.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';

Future<void> runCli() async {
  // Selected modules, dev only data.
  final modules = <IModuleCodeContributor>[
    // FirebaseCoreModule(),
    SmfCoreModule(),
    // FirebaseAnalyticsModule(),
  ];
  final logger = Logger(level: Level.verbose);

  const resolver = ModuleDependencyResolver();
  for (final module in resolver.resolve(modules)) {
    for (final brick in module.brickContributions) {
      final generator = await MasonGenerator.fromBundle(brick.bundle);

      final target = DirectoryGeneratorTarget(
        Directory('/Users/ybeshkarov/gen/'),
      );

      final generateProgress = logger.progress('Bootstrapping');
      var vars = brick.vars;
      await generator.hooks.preGen(vars: vars, onVarsChanged: (v) => vars = v);

      print('🚀 Generating from ${brick.name}...');
      final files = await generator.generate(
        target,
        vars: vars,
        fileConflictResolution: _mapMergeStrategy(brick.mergeStrategy),
        logger: logger,
      );
      generateProgress.complete('Generated ${files.length} file(s)');
    }
  }

  print('✅ Done!');
}

FileConflictResolution _mapMergeStrategy(FileMergeStrategy strategy) {
  switch (strategy) {
    case FileMergeStrategy.appendToFile:
      return FileConflictResolution.append;
    case FileMergeStrategy.injectByTag:
      return FileConflictResolution.prompt;
    case FileMergeStrategy.overwrite:
  }

  return FileConflictResolution.overwrite;
}
