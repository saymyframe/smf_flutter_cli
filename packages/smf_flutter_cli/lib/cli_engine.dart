import 'dart:io';

import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_flutter_cli/bundles/smf_cli_brick_bundle.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';

Future<void> runCli() async {
  // Selected modules, dev only data.
  final modules = <IModuleCodeContributor>[
    SmfCoreModule(),
    FirebaseAnalyticsModule(),
  ];
  final logger = Logger(level: Level.verbose);

  const resolver = ModuleDependencyResolver();
  final resolvedModules = resolver.resolve(modules);

  final generator = await MasonGenerator.fromBundle(smfCliBrickBundle);
  var coreVars = <String, dynamic>{};
  await generator.hooks.preGen(
    vars: coreVars,
    onVarsChanged: (v) => coreVars = v,
  );

  // Generate individual brick contributions
  await _generateBrickContributions(resolvedModules, logger, coreVars);

  // Generate shared file contributions
  await _generateSharable(resolvedModules, logger, coreVars);
}

Future<void> _generateBrickContributions(
  List<IModuleCodeContributor> modules,
  Logger logger,
  Map<String, dynamic> coreVars,
) async {
  for (final module in modules) {
    for (final brick in module.brickContributions) {
      final generator = await MasonGenerator.fromBundle(brick.bundle);

      final target = DirectoryGeneratorTarget(
        Directory('/Users/ybeshkarov/gen/'),
      );

      final generateProgress = logger.progress(
        '🔄 Generating from ${brick.name}',
      );

      var vars = coreVars..addAll(brick.vars ?? {});
      await generator.hooks.preGen(vars: vars, onVarsChanged: (v) => vars = v);

      final files = await generator.generate(
        target,
        vars: vars,
        fileConflictResolution: _mapMergeStrategy(brick.mergeStrategy),
        logger: logger,
      );

      generateProgress.complete('✅ Generated ${files.length} file(s)');
    }
  }
}

Future<void> _generateSharable(
  List<IModuleCodeContributor> selectedModules,
  Logger logger,
  Map<String, dynamic> coreVars,
) async {
  // Group shared contributions by bundle and slot
  final sharedContributions =
      <String, Map<String, List<SharedFileContribution>>>{};

  for (final module in selectedModules) {
    for (final contribution in module.sharedFileContributions) {
      final bundleKey = contribution.bundle.name;
      sharedContributions.putIfAbsent(bundleKey, () => {});
      sharedContributions[bundleKey]!.putIfAbsent(contribution.slot, () => []);
      sharedContributions[bundleKey]![contribution.slot]!.add(contribution);
    }
  }

  // Process each bundle's shared contributions
  for (final bundleKey in sharedContributions.keys) {
    final slotContributions = sharedContributions[bundleKey]!;

    // Find the bundle from any contribution
    final sampleContribution = slotContributions.values.first.first;
    final bundle = sampleContribution.bundle;

    final generator = await MasonGenerator.fromBundle(bundle);
    final target =
        DirectoryGeneratorTarget(Directory('/Users/ybeshkarov/gen/'));

    // Prepare variables for the bundle
    var vars = coreVars..addAll(sampleContribution.vars ?? {});

    // Process each slot
    for (final slot in slotContributions.keys) {
      final contributions = slotContributions[slot]!

        // Sort by order if specified
        ..sort((a, b) => (a.order ?? 0).compareTo(b.order ?? 0));

      // Combine content for this slot
      final combinedContent = contributions.map((c) => c.content).join();
      vars[slot] = combinedContent;
    }

    final generateProgress = logger.progress(
      '🔄 Generating shared content for $bundleKey',
    );

    await generator.hooks.preGen(vars: vars, onVarsChanged: (v) => vars = v);

    final files = await generator.generate(
      target,
      vars: vars,
      fileConflictResolution: FileConflictResolution.overwrite,
      logger: logger,
    );

    generateProgress.complete(
      '✅ Generated shared content in ${files.length} file(s)',
    );
  }
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
