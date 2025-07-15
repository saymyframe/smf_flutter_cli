import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';

abstract interface class DslAwareCodeGenerator {}

abstract interface class DiDslAwareCodeGenerator
    implements DslAwareCodeGenerator {
  Future<void> generateFromDiDsl({
    required List<DiDependencyGroup> diGroups,
    required String projectRootPath,
    Map<String, dynamic>? mustacheVariables,
    Logger? logger,
  });
}

// abstract class RoutingDslAwareCodeGenerator {
//   Future<void> generateFromRoutingDsl({
//     required List<RouteDefinitionGroup> routeGroups,
//     required String packageName,
//     required String projectRootPath,
//   });
// }
