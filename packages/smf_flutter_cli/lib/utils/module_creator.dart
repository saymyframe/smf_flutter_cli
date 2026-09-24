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
    final selection = _ModuleSelection(
      registry,
      profile,
      strictMode: strictMode,
      logger: logger,
    );
    [
      ...coreModuleKeys
          .map((key) => registry[key])
          .whereType<IModuleContributorFactory>(),
      ...rootFactories,
    ].forEach(selection.addRoot);

    return resolver.resolve(selection.modules.values.toList());
  }
}

/// The modules of one [ModuleCreator.build] run.
///
/// A module is selected only when all of its dependencies are, transitively.
/// In lenient mode a module that can't be selected is skipped together with
/// every module that depends on it, and it is never brought back later.
class _ModuleSelection {
  _ModuleSelection(
    this.registry,
    this.profile, {
    required this.strictMode,
    required this.logger,
  });

  final Map<String, IModuleContributorFactory> registry;
  final ModuleProfile profile;
  final StrictMode strictMode;
  final Logger? logger;

  /// Selected modules by name. A dependency takes its slot before its own
  /// dependencies, which keeps the order the resolver starts from stable.
  final modules = <String, IModuleCodeContributor>{};

  final _selected = <String>{};
  final _skipped = <String>{};
  final _visiting = <String>{};

  void addRoot(IModuleContributorFactory factory) {
    final module = _create(factory);
    if (module != null) _add(module);
  }

  /// Selects [module] if all of its dependencies can be selected.
  bool _add(IModuleCodeContributor module) {
    final name = module.moduleDescriptor.name;
    if (_selected.contains(name)) return true;
    if (_skipped.contains(name)) return false;
    // A module that is already being added depends on itself; the resolver
    // reports the cycle.
    if (!_visiting.add(name)) return true;

    final dependenciesSelected = module.moduleDescriptor.dependsOn
        .every((dependency) => _addDependency(dependency, name));
    _visiting.remove(name);

    if (!dependenciesSelected) {
      _skipped.add(name);
      modules.remove(name);
      return false;
    }
    modules[name] = module;
    _selected.add(name);
    return true;
  }

  bool _addDependency(String dependency, String dependent) {
    if (_selected.contains(dependency)) return true;

    final factory = registry[dependency];
    if (factory == null) {
      _fail(
        'Unknown dependency: $dependency for $dependent',
        skipping: 'Skipping $dependent',
      );
      return false;
    }

    final isNew = !modules.containsKey(dependency);
    final module = _skipped.contains(dependency)
        ? null
        : modules[dependency] ?? _create(factory);
    if (module != null) modules[dependency] = module;
    if (module == null || !_add(module)) {
      logger?.warn(
        '⚠️ Dependency $dependency not available for $dependent. '
        'Skipping $dependent',
      );
      return false;
    }

    if (isNew) {
      logger?.detail(
        '🔗 Resolved transitive dependency: '
        '$dependency (required by $dependent)',
      );
    }
    return true;
  }

  IModuleCodeContributor? _create(IModuleContributorFactory factory) {
    if (factory.supports(profile)) return factory.create(profile);

    _fail(
      'Module factory ${factory.runtimeType} does not support profile: '
      '$profile',
      skipping: 'Skipping.',
    );
    return null;
  }

  /// Throws in strict mode; otherwise warns that something is [skipping].
  void _fail(String message, {required String skipping}) {
    if (strictMode == StrictMode.strict) {
      logger?.err('❌ $message');
      throw StateError(message);
    }
    logger?.warn('⚠️ $message. $skipping');
  }
}
