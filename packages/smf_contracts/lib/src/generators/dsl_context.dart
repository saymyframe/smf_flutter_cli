import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';

class DslContext {
  const DslContext({
    required this.projectRootPath,
    required this.mustacheVariables,
    required this.logger,
    required this.initialRoute,
    this.diGroups = const [],
    this.routeGroups = const [],
    this.shellDeclarations = const [],
  });

  final String projectRootPath;
  final Map<String, dynamic> mustacheVariables;
  final Logger logger;

  final List<DiDependencyGroup> diGroups;
  final List<RouteGroup> routeGroups;
  final List<ShellDeclaration> shellDeclarations;
  final String initialRoute;
}
