import 'dart:io' show stdout;

import 'package:args/args.dart';
import 'package:interact/interact.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/constants/smf_modules.dart';
import 'package:smf_flutter_cli/promts/models/project_preferences.dart';
import 'package:smf_flutter_cli/promts/theme.dart';

class CreatePrompt {
  ProjectPreferences prompt(ArgResults? argResult) {
    stdout.writeln(
      "👋 Hello! Let's create a flutter project with Say my Frame.",
    );

    return _collect(argResult);
  }

  ProjectPreferences _collect(ArgResults? argResult) {
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

    final packageName = Input.withTheme(
      prompt: '🏢 Enter package name: ',
      theme: terminalTheme,
      defaultValue: 'com.example.$name',
    ).interact();

    // final stateManager = Select.withTheme(
    //   prompt: 'Select state management approach',
    //   options: smfStateManagers,
    //   theme: terminalTheme,
    // ).interact();

    final allModulesKeysList = smfModules.keys.toList();
    final modules = MultiSelect.withTheme(
      prompt: '📦 Select modules',
      options: allModulesKeysList,
      theme: terminalTheme,
    ).interact();

    final selectedModules =
        modules.map((i) => smfModules[allModulesKeysList[i]]!).toList();
    final initialRoute = _initialRoute(selectedModules);

    return ProjectPreferences(
      name: name,
      packageName: packageName,
      stateManager: '',
      selectedModules: selectedModules,
      initialRoute: initialRoute,
    );
  }

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
}
