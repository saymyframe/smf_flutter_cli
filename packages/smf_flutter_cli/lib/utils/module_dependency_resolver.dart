// Copyright 2025 SayMyFrame. All rights reserved.
// Licensed under the Apache License, Version 2.0 (the "License");
// you may not use this file except in compliance with the License.
// You may obtain a copy of the License at
//
//     http://www.apache.org/licenses/LICENSE-2.0
//
// Unless required by applicable law or agreed to in writing, software
// distributed under the License is distributed on an "AS IS" BASIS,
// WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
// See the License for the specific language governing permissions and
// limitations under the License.

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/constants/smf_modules.dart';

/// Resolves transitive module dependencies and returns a topologically
/// sorted list suitable for generation.
class ModuleDependencyResolver {
  /// Creates a new [ModuleDependencyResolver].
  const ModuleDependencyResolver();

  /// Returns a sorted list where dependencies appear before dependents.
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

  /// Returns a list of modules that directly depend on [module] within
  /// the provided [allModules] collection.
  List<IModuleCodeContributor> dependentsOf(
    IModuleCodeContributor module,
    List<IModuleCodeContributor> allModules,
  ) {
    final targetName = module.moduleDescriptor.name;
    return allModules
        .where((m) => m.moduleDescriptor.dependsOn.contains(targetName))
        .toList();
  }
}
