import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/generators/generator.dart';

class DslGenerator extends Generator {
  @override
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  ) async {
    final dslGenerators = modules.whereType<DslAwareCodeGenerator>().toList();
    for (final dslGenerator in dslGenerators) {
      if (dslGenerator is DiDslAwareCodeGenerator) {
        final diGroups = modules.map((m) => m.di).expand((e) => e).toList();

        await dslGenerator.generateFromDiDsl(
          diGroups: diGroups,
          projectRootPath: generateTo,
          mustacheVariables: coreVars,
          logger: logger,
        );
      }
    }
  }
}
