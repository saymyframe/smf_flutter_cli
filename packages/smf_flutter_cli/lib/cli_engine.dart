import 'dart:io';

import 'package:mason/mason.dart';
import 'package:mustachex/mustachex.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_firebase_analytics/smf_firebase_analytics.dart';
import 'package:smf_flutter_cli/bundles/smf_cli_brick_bundle.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:smf_flutter_cli/utils/utils.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:yaml_edit/yaml_edit.dart';

const testPath = '/Users/ybeshkarov/gen/';

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
  var coreVars = <String, dynamic>{kWorkingDirectory: testPath};
  await generator.hooks.preGen(
    vars: coreVars,
    onVarsChanged: (v) => coreVars = v,
  );

  // Generate individual brick contributions
  await _generateBrickContributions(resolvedModules, logger, coreVars);

  // Generate shared file contributions
  await _generateSharable(resolvedModules, logger, coreVars);

  // Generate dependencies to pubspec
  await _generatePubspecDependencies(
      resolvedModules, logger, coreVars['app_name'] as String);
}

Future<void> _generateBrickContributions(
  List<IModuleCodeContributor> modules,
  Logger logger,
  Map<String, dynamic> coreVars,
) async {
  for (final module in modules) {
    for (final brick in module.brickContributions) {
      final generator = await MasonGenerator.fromBundle(brick.bundle);

      final target = DirectoryGeneratorTarget(Directory(testPath));

      var vars = coreVars..addAll(brick.vars ?? {});
      await generator.hooks.preGen(
        vars: vars,
        onVarsChanged: (v) => vars = v,
        logger: logger,
      );

      final generateProgress = logger.progress(
        '🔄 Generating from ${brick.name}',
      );

      final files = await generator.generate(
        target,
        vars: vars,
        fileConflictResolution: _mapMergeStrategy(brick.mergeStrategy),
        logger: logger,
      );

      generateProgress.complete('✅ Generated ${files.length} file(s)');

      await generator.hooks.postGen(
        vars: vars,
        onVarsChanged: (v) => vars = v,
        logger: logger,
      );
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
      sharedContributions[bundleKey]!
          .putIfAbsent(contribution.slot.tag, () => []);
      sharedContributions[bundleKey]![contribution.slot.tag]!.add(contribution);
    }
  }

  // Process each bundle's shared contributions
  for (final bundleKey in sharedContributions.keys) {
    final slotContributions = sharedContributions[bundleKey]!;

    // Find the bundle from any contribution
    final sampleContribution = slotContributions.values.first.first;
    final bundle = sampleContribution.bundle;

    final generator = await MasonGenerator.fromBundle(bundle);
    final target = DirectoryGeneratorTarget(Directory(testPath));

    // Prepare variables for the bundle
    var vars = coreVars..addAll(sampleContribution.vars ?? {});

    // Processor for shared contribution content
    final processor = MustachexProcessor(initialVariables: vars);

    // Process each slot
    for (final slot in slotContributions.keys) {
      final contributions = slotContributions[slot]!

        // Sort by order if specified
        ..sort((a, b) =>
            (a.order ?? maxIntValue).compareTo(b.order ?? maxIntValue));

      final renderedContents = await Future.wait(
        contributions.map((c) => processor.process(c.content)),
      );
      final combinedContent = renderedContents.join();
      vars[slot] = combinedContent;
    }

    await generator.hooks.preGen(
      vars: vars,
      onVarsChanged: (v) => vars = v,
      logger: logger,
    );

    final generateProgress = logger.progress(
      '🔄 Generating shared content for $bundleKey',
    );

    final files = await generator.generate(
      target,
      vars: vars,
      fileConflictResolution: FileConflictResolution.overwrite,
      logger: logger,
    );

    generateProgress.complete(
      '✅ Generated shared content in ${files.length} file(s)',
    );

    await generator.hooks.postGen(
      vars: vars,
      onVarsChanged: (v) => vars = v,
      logger: logger,
    );
  }
}

Future<void> _generatePubspecDependencies(
  List<IModuleCodeContributor> modules,
  Logger logger,
  String appName,
) async {
  final dependencies = modules
      .map((m) => m.moduleDescriptor.pubDependency)
      .expand((e) => e)
      .toSet();
  final devDependencies = modules
      .map((m) => m.moduleDescriptor.pubDevDependency)
      .expand((e) => e)
      .toSet();
  final file = File(
    '$testPath${appName.snakeCase}/pubspec.yaml',
  );

  final yaml = await file.readAsString();
  final editor = YamlEditor(yaml);

  void updatePubspec(Set<String> dependencies, String pubSpecSection) {
    for (final dependency in dependencies) {
      final split = dependency.split(':');
      editor.update([pubSpecSection, split.first.trim()], split.last.trim());
    }
  }

  updatePubspec(dependencies, 'dependencies');
  updatePubspec(devDependencies, 'dev_dependencies');

  await file.writeAsString(editor.toString());
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
