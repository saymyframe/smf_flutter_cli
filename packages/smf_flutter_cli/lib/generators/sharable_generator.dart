import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_flutter_cli/generators/generator.dart';

class SharableGenerator extends Generator {
  @override
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  ) async {
    final contributions =
        modules.map((m) => m.sharedFileContributions).expand((e) => e).toList();

    return PatchEngine(
      contributions,
      projectRoot: generateTo,
      mustacheVariables: coreVars,
      logger: logger,
    ).applyAll();
  }
}
