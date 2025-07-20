import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/composite_write_strategy.dart';
import 'package:smf_flutter_cli/generators/generator.dart';

/// Aggregates DSL data from all modules and invokes registered
/// [DslAwareCodeGenerator] implementations using a unified [DslContext].
///
/// This design avoids type branching and adheres to Open/Closed Principle by
/// delegating DSL-specific logic to the generators themselves.
///
/// Note: adding new DSL types may require extending [DslContext],
/// which is considered an acceptable and localized compromise.
class DslGenerator extends Generator {
  const DslGenerator(this.strategy);

  final CompositeWriteStrategy strategy;

  @override
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  ) async {
    final dslGenerators = modules.whereType<DslAwareCodeGenerator>().toList();
    final context = DslContext(
      projectRootPath: generateTo,
      mustacheVariables: coreVars,
      logger: logger,
      diGroups: modules.map((m) => m.di).expand((e) => e).toList(),
    );

    for (final dslGenerator in dslGenerators) {
      final files = await dslGenerator.generateFromDsl(context);
      for (final file in files) {
        await strategy.write(file);
      }
    }
  }
}
