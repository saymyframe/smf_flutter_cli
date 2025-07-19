import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/get_it_code_generator.dart';
import 'package:smf_get_it/src/contributors/module_di_contributor.dart';

import 'contributors/contributors.dart';

mixin DiDslGenerator implements DslAwareCodeGenerator {
  @override
  Future<void> generateFromDsl(DslContext context) async {
    final coreDependencies = context.diGroups
        .where((g) => g.scope == DiScope.core)
        .toList();

    await CoreDiContributor(
      projectRoot: context.projectRootPath,
      coreGenerator: const GetItCodeGenerator(),
      logger: context.logger,
    ).contribute(
      coreDependencies,
      mustacheVariables: context.mustacheVariables,
    );

    final moduleDependencies = context.diGroups
        .where((g) => g.scope == DiScope.module)
        .toList();

    await ModuleDiContributor(
      projectRoot: context.projectRootPath,
      logger: context.logger,
    ).contribute(
      moduleDependencies,
      mustacheVariables: context.mustacheVariables,
    );
  }
}
