import 'package:mason/mason.dart';
import 'package:smf_analytics/smf_analytics.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/bundles/smf_cli_brick_bundle.dart';
import 'package:smf_flutter_cli/file_writers/composite_write_strategy.dart';
import 'package:smf_flutter_cli/file_writers/default_write_strategy.dart';
import 'package:smf_flutter_cli/generators/brick_generator.dart';
import 'package:smf_flutter_cli/generators/dsl_generator.dart';
import 'package:smf_flutter_cli/generators/pubspec_generator.dart';
import 'package:smf_flutter_cli/generators/sharable_generator.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';

const testPath = '/Users/ybeshkarov/gen/';

Future<void> runCli() async {
  // Selected modules, dev only data.
  final modules = <IModuleCodeContributor>[
    SmfCoreModule(),
    FirebaseAnalyticsModule(),
  ];

  final logger = Logger();
  const resolver = ModuleDependencyResolver();
  final resolvedModules = resolver.resolve(modules);

  final generator = await MasonGenerator.fromBundle(smfCliBrickBundle);
  final coreVars = <String, dynamic>{
    kWorkingDirectory: testPath,
    'modules':
        '[${resolvedModules.map((e) => "'${e.moduleDescriptor.name}'").join(',')}]',
  };
  await generator.hooks.preGen(
    vars: coreVars,
    onVarsChanged: coreVars.addAll,
    logger: logger,
  );

  final writeStrategy = CompositeWriteStrategy([DefaultWriteStrategy()]);

  // Generate individual brick contributions
  await BrickGenerator().generate(resolvedModules, logger, coreVars, testPath);

  // Generate shared file contributions
  await SharableGenerator().generate(
    resolvedModules,
    logger,
    coreVars,
    coreVars[kWorkingDirectory] as String,
  );

  await DslGenerator(writeStrategy).generate(
    resolvedModules,
    logger,
    coreVars,
    coreVars[kWorkingDirectory] as String,
  );

  // Generate dependencies to pubspec
  await PubspecGenerator().generate(
    resolvedModules,
    logger,
    coreVars,
    coreVars[kWorkingDirectory] as String,
  );
}
