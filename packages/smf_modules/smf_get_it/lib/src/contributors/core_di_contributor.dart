import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/contributors.dart';

final class CoreDiContributor extends DiContributor {
  const CoreDiContributor({
    required super.projectRoot,
    required super.codeGenerator,
    super.logger,
  });

  @override
  Future<List<GeneratedFile>> contribute(
    List<DiDependencyGroup> groups, {
    Map? mustacheVariables,
  }) async {
    return [
      await processFile(
        imports: combineImports(groups),
        registrations: combineRegistrations(groups),
        file: File(writeTo(DiScope.core)),
        mustacheVariables: mustacheVariables,
      ),
    ];
  }
}
