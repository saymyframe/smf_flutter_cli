import 'package:mason_logger/mason_logger.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/get_it_code_generator.dart';
import 'package:smf_get_it/src/contributors/module_di_contributor.dart';

import 'contributors/contributors.dart';

mixin DiDslGenerator implements DiDslAwareCodeGenerator {
  @override
  Future<void> generateFromDiDsl({
    required List<DiDependencyGroup> diGroups,
    required String projectRootPath,
    Map<String, dynamic>? mustacheVariables,
    Logger? logger,
  }) async {
    final coreDependencies = diGroups
        .where((g) => g.scope == DiScope.core)
        .toList();

    await CoreDiContributor(
      projectRoot: projectRootPath,
      coreGenerator: const GetItCodeGenerator(),
      logger: logger,
    ).contribute(coreDependencies, mustacheVariables: mustacheVariables);

    final moduleDependencies = diGroups
        .where((g) => g.scope == DiScope.module)
        .toList();

    await ModuleDiContributor(
      projectRoot: projectRootPath,
      logger: logger,
    ).contribute(moduleDependencies, mustacheVariables: mustacheVariables);
  }
}
