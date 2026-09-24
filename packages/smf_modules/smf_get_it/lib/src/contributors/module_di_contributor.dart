import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/contributors.dart';

/// Renders module groups into the DI templates they point to with
/// [DiDependencyGroup.pathToDiTemplate].
final class ModuleDiContributor extends DiContributor {
  /// Creates a contributor for the module DI files under [projectRoot].
  ModuleDiContributor({
    required super.projectRoot,
    required super.codeGenerator,
    super.logger,
  });

  /// Returns one file per template, with the imports and registrations of
  /// the [groups] that point to it; no file when [groups] is empty.
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
