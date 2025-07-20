import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_get_it/src/contributors/contributors.dart';

class ModuleDiContributor extends DiContributor {
  ModuleDiContributor({required super.projectRoot, super.logger});

  @override
  Future<List<GeneratedFile>> contribute(
    List<DiDependencyGroup> groups, {
    Map? mustacheVariables,
  }) async {
    final byFile = <String, List<DiDependencyGroup>>{};
    for (final group in groups) {
      byFile.putIfAbsent(writeTo(group), () => []).add(group);
    }

    return [];
  }
}
