import 'package:smf_contracts/smf_contracts.dart';

class ProjectPreferences {
  const ProjectPreferences({
    required this.name,
    required this.packageName,
    required this.stateManager,
    required this.selectedModules,
  });

  final String name;
  final String packageName;
  final String stateManager;
  final List<IModuleCodeContributor> selectedModules;
}
