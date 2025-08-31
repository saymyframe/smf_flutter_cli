import 'package:smf_contracts/smf_contracts.dart';

/// Snapshot of user choices collected during scaffolding.
class ProjectPreferences {
  /// Creates a new [ProjectPreferences].
  const ProjectPreferences({
    required this.name,
    required this.packageName,
    required this.initialRoute,
    required this.selectedModules,
  });

  /// Human-readable project name.
  final String name;

  /// Reverse-domain package/organization name.
  final String packageName;

  /// Initial route path to show after app launch.
  final String? initialRoute;

  /// Selected modules to be included in the generated project.
  final List<IModuleCodeContributor> selectedModules;
}
