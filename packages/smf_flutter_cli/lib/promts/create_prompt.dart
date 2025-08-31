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

import 'dart:io' show stdout;

import 'package:args/args.dart';
import 'package:interact/interact.dart';
import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/constants/smf_modules.dart';
import 'package:smf_flutter_cli/promts/models/cli_context.dart';
import 'package:smf_flutter_cli/promts/models/project_preferences.dart';
import 'package:smf_flutter_cli/promts/theme.dart';
import 'package:smf_flutter_cli/utils/module_creator.dart';

/// Interactive prompt that gathers project preferences from the user.
class CreatePrompt {
  /// Creates a new [CreatePrompt] with the specified module creator.
  const CreatePrompt({required this.creator});

  /// Module creator used for building module instances from user selections.
  final ModuleCreator creator;

  /// Starts the prompt flow and returns collected [ProjectPreferences].
  ProjectPreferences prompt(
    ArgResults? argResult, {
    required List<String> allowedModules,
    required StrictMode strictMode,
    required Logger logger,
  }) {
    stdout.writeln(
      "👋 Hello! Let's create a flutter project with Say my Frame.",
    );

    return _collect(
      argResult,
      allowedModules: allowedModules,
      strictMode: strictMode,
      logger: logger,
    );
  }

  /// Collects values from CLI flags or interacts with the user when missing.
  ProjectPreferences _collect(
    ArgResults? argResult, {
    required List<String> allowedModules,
    required StrictMode strictMode,
    required Logger logger,
  }) {
    final name = argResult?.rest.firstOrNull ??
        Input.withTheme(
          prompt: '✍️ Enter project name: ',
          theme: terminalTheme,
          defaultValue: 'app',
          validator: (x) {
            if (x.contains(RegExp(r'[^a-zA-Z\d]'))) {
              throw ValidationError('Contains an invalid character!');
            }

            return true;
          },
        ).interact();

    final packageName = argResult?['org'] as String? ??
        Input.withTheme(
          prompt: '🏢 Enter package name: ',
          theme: terminalTheme,
          defaultValue: 'com.example',
        ).interact();

    var selectedFactories = _selectedModules(
      argResult,
      allowedModules: allowedModules,
    );

    if (selectedFactories.isEmpty) {
      final modules = MultiSelect.withTheme(
        prompt: '📦 Select modules',
        options: allowedModules,
        theme: terminalTheme,
      ).interact();

      selectedFactories = _resolveModule(
        modules.map((i) => allowedModules[i]).toList(),
      );
    }

    final stateArg = argResult?['state-manager'] as String?;
    final selectedState = stateArg ??
        Select.withTheme(
          prompt: '🧠 Choose state manager',
          options: StateManager.values.map((s) => s.stateManager).toList(),
          theme: terminalTheme,
        ).interact();

    late final ModuleProfile profile;

    if (stateArg != null) {
      profile = ModuleProfile(
        stateManager: StateManager.values.firstWhere(
          (s) => s.stateManager == stateArg,
        ),
      );
    } else {
      profile = ModuleProfile(
        stateManager: StateManager.values[selectedState as int],
      );
    }

    final modules = creator.build(
      selectedFactories,
      profile,
      strictMode: strictMode,
      logger: logger,
    );

    final initialRoute = argResult?['route'] as String? ??
        _initialRoute(
          modules,
          coreModules: creator.coreModuleKeys,
        );

    return ProjectPreferences(
      name: name,
      packageName: packageName,
      selectedModules: modules,
      initialRoute: initialRoute,
    );
  }

  /// Requests the initial route from user based on selected modules.
  String? _initialRoute(
    List<IModuleCodeContributor> modules, {
    required List<String> coreModules,
  }) {
    final modulesWithInitialRoute = modules
        .where(
          (m) =>
              (m.routes.initialRoute?.isNotEmpty ?? false) &&
              !coreModules.contains(m.moduleDescriptor.name),
        )
        .toList();

    if (modulesWithInitialRoute.isNotEmpty) {
      if (modulesWithInitialRoute.length == 1) {
        return modulesWithInitialRoute.first.routes.initialRoute!;
      }

      final initialRoute = Select.withTheme(
        prompt: '🧭 Choose your initial screen',
        options: modulesWithInitialRoute
            .map((m) => m.moduleDescriptor.name)
            .toList(),
        theme: terminalTheme,
      ).interact();

      return modulesWithInitialRoute[initialRoute].routes.initialRoute;
    }

    return null;
  }

  /// Parses the `--modules` argument and validates allowed module names.
  List<IModuleContributorFactory> _selectedModules(
    ArgResults? argResult, {
    required List<String> allowedModules,
  }) {
    final modulesArg = argResult?['modules'] as String?;
    var selectedModules = <String>[];

    if (modulesArg != null && modulesArg.isNotEmpty) {
      // Split by commas and clean up whitespace
      selectedModules = modulesArg
          .split(',')
          .map((e) => e.trim())
          .where((e) => e.isNotEmpty)
          .toList();

      // Remove duplicates
      selectedModules = selectedModules.toSet().toList();

      final invalidModules = selectedModules
          .where((module) => !allowedModules.contains(module))
          .toList();

      if (invalidModules.isNotEmpty) {
        throw ArgumentError(
          'Invalid modules: ${invalidModules.join(', ')}. '
          'Allowed modules: ${allowedModules.join(', ')}',
        );
      }

      return _resolveModule(selectedModules);
    }

    return const [];
  }

  /// Maps module names to their implementations using the registry.
  List<IModuleContributorFactory> _resolveModule(List<String> modules) {
    return modules.map((e) {
      final module = smfModules[e];
      if (module == null) {
        throw ArgumentError(
          'Module "$e" is not registered. '
          'Available modules: ${smfModules.keys.join(', ')}',
        );
      }

      return module;
    }).toList();
  }
}
