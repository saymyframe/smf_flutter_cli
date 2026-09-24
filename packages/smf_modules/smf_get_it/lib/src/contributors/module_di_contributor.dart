import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/contributors.dart';

final class ModuleDiContributor extends DiContributor {
  ModuleDiContributor({
    required super.projectRoot,
    required super.codeGenerator,
    super.logger,
  });

  @override
  Future<List<GeneratedFile>> contribute(
    List<DiDependencyGroup> groups, {
    Map? mustacheVariables,
  }) async {
    final byFile = <String, List<DiDependencyGroup>>{};
    for (final group in groups) {
      byFile
          .putIfAbsent(
            writeTo(DiScope.module, pathToDiTemplate: group.pathToDiTemplate),
            () => [],
          )
          .add(group);
    }

    final generatedFiles = <GeneratedFile>[];
    for (final groupEntry in byFile.entries) {
      generatedFiles.add(
        await processFile(
          imports: combineImports(groupEntry.value),
          registrations: combineRegistrations(groupEntry.value),
          file: File(groupEntry.key),
          mustacheVariables: mustacheVariables,
        ),
      );
    }

    return generatedFiles;
  }
}
