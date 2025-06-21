import 'package:interact/interact.dart';
import 'package:smf_flutter_cli/constants/smf_modules.dart';
import 'package:smf_flutter_cli/promts/models/project_preferences.dart';
import 'package:smf_flutter_cli/promts/theme.dart';

class PreferencesCollector {
  ProjectPreferences collect() {
    final name = Input.withTheme(
      prompt: '👋 Enter project name: ',
      theme: terminalTheme,
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

    final stateManager = Select.withTheme(
      prompt: 'Select state management approach',
      options: smfStateManagers,
      theme: terminalTheme,
    ).interact();

    final allModulesKeysList = smfModules.keys.toList();

    final modules = MultiSelect.withTheme(
      prompt: '📦 Select modules',
      options: allModulesKeysList,
      theme: terminalTheme,
    ).interact();

    return ProjectPreferences(
      name: name,
      packageName: packageName,
      stateManager: smfStateManagers[stateManager],
      selectedModules:
          modules.map((i) => smfModules[allModulesKeysList[i]]!).toList(),
    );
  }
}
