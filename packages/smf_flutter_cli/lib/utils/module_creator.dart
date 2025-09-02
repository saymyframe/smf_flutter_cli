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

import 'package:mason/mason.dart' show Logger;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/prompts/prompt.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';

/// Builds module instances from factories, enforcing supports(profile)
/// and populating transitive dependencies from the registry.
class ModuleCreator {
  /// Creates a new [ModuleCreator] with the specified dependencies.
  const ModuleCreator(
    this.resolver,
    this.registry, {
    this.coreModuleKeys = const <String>[],
  });

  /// Resolver for determining module dependency order.
  final ModuleDependencyResolver resolver;

  /// Registry mapping module names to their factory implementations.
  final Map<String, IModuleContributorFactory> registry;

  /// List of core module keys that are automatically included.
  final List<String> coreModuleKeys;

  /// Builds module instances using [rootFactories] and [profile].
  ///
  /// - Adds core factories (flutter_core, contracts) implicitly via
  ///   [coreModuleKeys].
  /// - In strict mode throws when a module or its dependency is unsupported
  ///   or missing in the registry. In lenient mode logs a warning and skips.
  List<IModuleCodeContributor> build(
    List<IModuleContributorFactory> rootFactories,
    ModuleProfile profile, {
    required StrictMode strictMode,
    Logger? logger,
  }) {
    final allRequestedFactories = <IModuleContributorFactory>[
      ...coreModuleKeys
          .map((key) => registry[key])
          .whereType<IModuleContributorFactory>(),
      ...rootFactories,
    ];

    final moduleNameToInstance = <String, IModuleCodeContributor>{};
    final processedModuleNames = <String>{};

    IModuleCodeContributor? tryCreateModuleInstance(
      IModuleContributorFactory factory,
    ) {
      if (!factory.supports(profile)) {
        final message = 'Module factory ${factory.runtimeType} '
            'does not support profile: $profile';
        if (strictMode == StrictMode.strict) {
          logger?.err('❌ $message');
          throw StateError(message);
        } else {
          logger?.warn('⚠️ $message. Skipping.');
          return null;
        }
      }

      return factory.create(profile);
    }

    void addModuleAndDependencies(IModuleCodeContributor module) {
      final moduleName = module.moduleDescriptor.name;
      if (processedModuleNames.contains(moduleName)) return;
      processedModuleNames.add(moduleName);

      for (final dependencyName in module.moduleDescriptor.dependsOn) {
        final dependencyFactory = registry[dependencyName];
        if (dependencyFactory == null) {
          final message = 'Unknown dependency: $dependencyName for $moduleName';
          if (strictMode == StrictMode.strict) {
            logger?.err('❌ $message');
            throw StateError(message);
          } else {
            logger?.warn('⚠️ $message. Skipping $moduleName');
            return; // skip this module in lenient mode
          }
        }

        final alreadyPresent = moduleNameToInstance.containsKey(dependencyName);
        final dependencyInstance = moduleNameToInstance[dependencyName] ??
            tryCreateModuleInstance(dependencyFactory);
        if (dependencyInstance == null) {
          // Unsupported dependency in lenient mode → skip current module
          logger?.warn(
            '⚠️ Dependency $dependencyName not available for $moduleName. '
            'Skipping $moduleName',
          );

          return;
        }

        moduleNameToInstance[dependencyName] = dependencyInstance;
        if (!alreadyPresent) {
          logger?.detail(
            '🔗 Resolved transitive dependency: '
            '$dependencyName (required by $moduleName)',
          );
        }
        addModuleAndDependencies(dependencyInstance);
      }

      moduleNameToInstance[moduleName] = module;
    }

    for (final factory in allRequestedFactories) {
      final instance = tryCreateModuleInstance(factory);
      if (instance == null) continue;
      addModuleAndDependencies(instance);
    }

    // Resolve final order using provided resolver
    final built = moduleNameToInstance.values.toList();
    return resolver.resolve(built);
  }
}
