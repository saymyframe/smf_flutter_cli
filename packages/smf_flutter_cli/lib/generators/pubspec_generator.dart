import 'dart:io';

import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/generators/generator.dart';
import 'package:yaml_edit/yaml_edit.dart';

class PubspecGenerator extends Generator {
  @override
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  ) async {
    final dependencies = modules
        .map((m) => m.moduleDescriptor.pubDependency)
        .expand((e) => e)
        .toSet();
    final devDependencies = modules
        .map((m) => m.moduleDescriptor.pubDevDependency)
        .expand((e) => e)
        .toSet();
    final file = File('$generateTo/pubspec.yaml');

    final yaml = await file.readAsString();
    final editor = YamlEditor(yaml);

    void updatePubspec(Set<String> dependencies, String pubSpecSection) {
      for (final dependency in dependencies) {
        final split = dependency.split(':');
        editor.update([pubSpecSection, split.first.trim()], split.last.trim());
      }
    }

    updatePubspec(dependencies, 'dependencies');
    updatePubspec(devDependencies, 'dev_dependencies');

    await file.writeAsString(editor.toString());
  }
}
