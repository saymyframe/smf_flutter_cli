import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/bundles/smf_cli_brick_bundle.dart';
import 'package:smf_flutter_cli/file_writers/composite_write_strategy.dart';
import 'package:smf_flutter_cli/file_writers/default_write_strategy.dart';
import 'package:smf_flutter_cli/generators/brick_generator.dart';
import 'package:smf_flutter_cli/generators/dsl_generator.dart';
import 'package:smf_flutter_cli/generators/pubspec_generator.dart';
import 'package:smf_flutter_cli/generators/sharable_generator.dart';
import 'package:smf_flutter_cli/promts/models/cli_context.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';

Future<void> runCli(CliContext context) async {
  const resolver = ModuleDependencyResolver();
  final resolvedModules = resolver.resolve(context.selectedModules);

  final cliGenerator = await MasonGenerator.fromBundle(smfCliBrickBundle);
  final coreVars = <String, dynamic>{
    kWorkingDirectory: context.outputDirectory,
    'modules':
        '[${resolvedModules.map((e) => "'${e.moduleDescriptor.name}'").join(',')}]',
    'app_name': context.name,
    'org_name': context.packageName,
  };
  await cliGenerator.hooks.preGen(
    vars: coreVars,
    onVarsChanged: coreVars.addAll,
    logger: context.logger,
  );

  final writeStrategy = CompositeWriteStrategy([DefaultWriteStrategy()]);

  // Generate individual brick contributions
  context.logger.info('📦 Generating brick contributions...');
  await BrickGenerator().generate(
    resolvedModules,
    context.logger,
    coreVars,
    context.outputDirectory,
  );

  // Generate shared file contributions
  context.logger.info('🔧 Applying shared file contributions...');
  await SharableGenerator().generate(
    resolvedModules,
    context.logger,
    coreVars,
    coreVars[kWorkingDirectory] as String,
  );

  context.logger.info('🛣️ Generating from dsls...');
  await DslGenerator(writeStrategy, cliContext: context).generate(
    resolvedModules,
    context.logger,
    coreVars,
    coreVars[kWorkingDirectory] as String,
  );

  // Generate dependencies to pubspec
  context.logger.info('📋 Updating pubspec.yaml...');
  await PubspecGenerator().generate(
    resolvedModules,
    context.logger,
    coreVars,
    coreVars[kWorkingDirectory] as String,
  );

  context.logger.info('🏁 Running post gen cli hook...');
  await cliGenerator.hooks.postGen(
    vars: coreVars,
    logger: context.logger,
  );
}
