import 'dart:io' show stdout;

import 'package:args/args.dart';
import 'package:interact/interact.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/constants/smf_modules.dart';
import 'package:smf_flutter_cli/promts/models/project_preferences.dart';
import 'package:smf_flutter_cli/promts/theme.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';

/// Interactive prompt that gathers project preferences from the user.
class CreatePrompt {
  /// Starts the prompt flow and returns collected [ProjectPreferences].
  ProjectPreferences prompt(
    ArgResults? argResult, {
    required List<String> allowedModules,
  }) {
    stdout.writeln(
      "👋 Hello! Let's create a flutter project with Say my Frame.",
    );

    return _collect(argResult, allowedModules: allowedModules);
  }

  /// Collects values from CLI flags or interacts with the user when missing.
  ProjectPreferences _collect(
    ArgResults? argResult, {
    required List<String> allowedModules,
  }) {
    final name = argResult?.rest.first ??
        Input.withTheme(
          prompt: '👋 Enter project name: ',
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
          defaultValue: 'com.example.$name',
        ).interact();

    var selectedModules = _selectedModules(
      argResult,
      allowedModules: allowedModules,
    );

    if (selectedModules.isEmpty) {
      final modules = MultiSelect.withTheme(
        prompt: '📦 Select modules',
        options: allowedModules,
        theme: terminalTheme,
      ).interact();

      selectedModules = _resolveModule(
        modules.map((i) => allowedModules[i]).toList(),
      );
    }

    final initialRoute =
        argResult?['route'] as String? ?? _initialRoute(selectedModules);

    return ProjectPreferences(
      name: name,
      packageName: packageName,
      selectedModules: [
        SmfCoreModule(),
        SmfContractsModule(),
        ...selectedModules
      ],
      initialRoute: initialRoute,
    );
  }

  /// Requests the initial route from user based on selected modules.
  String _initialRoute(List<IModuleCodeContributor> modules) {
    final modulesWithInitialRoute = modules
        .where((m) => m.routes.initialRoute?.isNotEmpty ?? false)
        .toList();

    final initialRoute = Select.withTheme(
      prompt: '🧭 Choose your initial screen',
      options:
          modulesWithInitialRoute.map((m) => m.moduleDescriptor.name).toList(),
      theme: terminalTheme,
    ).interact();

    return modulesWithInitialRoute[initialRoute].routes.initialRoute!;
  }

  /// Parses the `--modules` argument and validates allowed module names.
  List<IModuleCodeContributor> _selectedModules(
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
  List<IModuleCodeContributor> _resolveModule(List<String> modules) {
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
