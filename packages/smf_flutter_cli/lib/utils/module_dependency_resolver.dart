import 'package:smf_flutter_cli/constants/smf_modules.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart'
    show IModuleCodeContributor;

class ModuleDependencyResolver {
  const ModuleDependencyResolver();

  List<IModuleCodeContributor> resolve(
    List<IModuleCodeContributor> selectedModules,
  ) {
    final resolved = <String>{};
    final sorted = <IModuleCodeContributor>[];

    void visit(String name) {
      if (resolved.contains(name)) return;

      final module = smfModules[name];
      if (module == null) throw Exception('Unknown module: $name');

      for (final dep in module.moduleDescriptor.dependsOn) {
        visit(dep);
      }

      resolved.add(name);
      sorted.add(module);
    }

    for (final module in selectedModules) {
      visit(module.moduleDescriptor.name);
    }

    return sorted;
  }
}
