import 'dart:io';

import 'package:mason/mason.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';

Future<void> runCli() async {
  // Selected modules, dev only data.
  final modules = <IModuleCodeContributor>[
    // FirebaseCoreModule(),
    FirebaseAnalyticsModule(),
  ];

  const resolver = ModuleDependencyResolver();
  for (final module in resolver.resolve(modules)) {
    for (final brick in module.brickContributions) {
      final generator = await MasonGenerator.fromBundle(brick.bundle);

      final target = DirectoryGeneratorTarget(Directory('gen'));

      print('🚀 Generating from ${brick.name}...');
      await generator.generate(
        target,
        vars: brick.vars,
        fileConflictResolution: _mapMergeStrategy(brick.mergeStrategy),
        logger: Logger(),
      );
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
