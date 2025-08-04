import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';

abstract class DiContributor {
  const DiContributor({required this.projectRoot, this.logger});

  final String projectRoot;
  final Logger? logger;

  Future<List<GeneratedFile>> contribute(
    List<DiDependencyGroup> groups, {
    Map? mustacheVariables,
  });

  String writeTo(DiScope scope, {String? pathToDiTemplate}) {
    assert(
      scope != DiScope.module || pathToDiTemplate?.isNotEmpty == true,
      'pathToDiTemplate must be provided when scope is DiScope.module',
    );

    switch (scope) {
      case DiScope.core:
        return join(projectRoot, 'lib', 'core', 'di', 'core_di.dart');
      case DiScope.module:
        return join(projectRoot, pathToDiTemplate);
    }
  }
}
