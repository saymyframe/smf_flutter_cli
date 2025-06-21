import 'package:smf_flutter_core/smf_flutter_core.dart';

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
