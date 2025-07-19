import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';

class DslContext {
  const DslContext({
    required this.projectRootPath,
    required this.mustacheVariables,
    required this.logger,
    this.diGroups = const [],
    // this.routeDefinitions = const [],
  });

  final String projectRootPath;
  final Map<String, dynamic> mustacheVariables;
  final Logger logger;

  final List<DiDependencyGroup> diGroups;
  // final List<RouteDefinition> routeDefinitions;
}
