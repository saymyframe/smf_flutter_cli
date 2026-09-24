import 'dart:io';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/contributors.dart';

/// Renders every group it is given into `lib/core/di/core_di.dart`.
final class CoreDiContributor extends DiContributor {
  /// Creates a contributor for the core DI file under [projectRoot].
  const CoreDiContributor({
    required super.projectRoot,
    required super.codeGenerator,
    super.logger,
  });

  /// Returns `core_di.dart` with the imports and registrations of all
  /// [groups], even when they are empty.
  @override
  Future<List<GeneratedFile>> contribute(
    List<DiDependencyGroup> groups, {
    Map<dynamic, dynamic>? mustacheVariables,
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
