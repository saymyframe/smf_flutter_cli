import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';

/// Input of a [DslAwareCodeGenerator]: the DSL declared by all selected
/// modules and details of the project being generated.
///
/// The CLI builds one context per run and passes it to every generator.
class DslContext {
  /// Creates a context; the DSL lists default to empty.
  const DslContext({
    required this.projectRootPath,
    required this.mustacheVariables,
    required this.logger,
    required this.initialRoute,
    this.diGroups = const [],
    this.routeGroups = const [],
    this.shellDeclarations = const [],
  });

  /// Root directory of the generated Flutter project.
  ///
  /// The CLI generates into a temporary directory and moves the project to
  /// its destination afterwards, so never write this path into generated
  /// code.
  final String projectRootPath;

  /// Template variables of the run, such as `app_name` and `org_name`.
  ///
  /// Render templates and [Import.resolve] results with them, so that
  /// placeholders like `{{app_name_sc}}` become the app's package name.
  final Map<String, dynamic> mustacheVariables;

  /// Logger of the CLI run, for progress and diagnostic output.
  final Logger logger;

  /// The [IModuleCodeContributor.di] groups of all selected modules.
  final List<DiDependencyGroup> diGroups;

  /// The [IModuleCodeContributor.routes] of all selected modules, one group
  /// per module.
  final List<RouteGroup> routeGroups;

  /// The shells that nested routes in [routeGroups] link to, each listed
  /// once.
  final List<ShellDeclaration> shellDeclarations;

  /// Path of the route the app starts on.
  ///
  /// The CLI takes it from its `--route` option or from the
  /// [RouteGroup.initialRoute]s of the selected modules, asking the user
  /// when several modules suggest one; without either it is `/noModules`.
  final String initialRoute;
}
