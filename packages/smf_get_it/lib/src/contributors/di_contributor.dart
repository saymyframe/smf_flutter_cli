import 'dart:io';

import 'package:mason_logger/mason_logger.dart';
import 'package:path/path.dart';
import 'package:smf_contracts/smf_contracts.dart';

abstract class DiContributor {
  const DiContributor({required this.projectRoot, this.logger});

  final String projectRoot;
  final Logger? logger;

  Future<List<File?>> contribute(
    List<DiDependencyGroup> groups, {
    Map? mustacheVariables,
  });

  String writeTo(DiDependencyGroup group) {
    switch (group.scope) {
      case DiScope.core:
        return join(projectRoot, 'lib', 'core', 'di', 'core_di.dart');
      case DiScope.module:
        return join(projectRoot, group.pathToDiTemplate);
    }
  }

  String generateDependency(DiDependency dependency, {Logger? logger}) {
    late String binding;

    switch (dependency.bindingType) {
      case DiBindingType.singleton:
        binding = 'registerLazySingleton';
        break;

      case DiBindingType.factory:
        binding = 'registerFactory';
        break;
    }

    final output =
        'getIt.$binding<${dependency.abstractType}>'
        '(() => ${dependency.implementation});';

    logger?.detail('Generating binding $output');
    return output;
  }
}
