import 'package:smf_contracts/smf_contracts.dart';

class ProjectPreferences {
  const ProjectPreferences({
    required this.name,
    required this.packageName,
    required this.stateManager,
    required this.initialRoute,
    required this.selectedModules,
  });

  final String name;
  final String packageName;
  final String stateManager;
  final String initialRoute;
  final List<IModuleCodeContributor> selectedModules;
}
