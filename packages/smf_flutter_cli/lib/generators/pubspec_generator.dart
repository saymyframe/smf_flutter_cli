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

import 'dart:io';

import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/generators/generator.dart';
import 'package:yaml_edit/yaml_edit.dart';

/// Updates the target project's pubspec.yaml with module dependencies.
class PubspecGenerator extends Generator {
  const PubspecGenerator();

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
