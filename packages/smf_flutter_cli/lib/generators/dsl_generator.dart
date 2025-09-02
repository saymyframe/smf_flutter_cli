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

import 'package:mason/mason.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/file_writers/composite_write_strategy.dart';
import 'package:smf_flutter_cli/generators/generator.dart';
import 'package:smf_flutter_cli/prompts/prompt.dart';

/// Aggregates DSL data from all modules and invokes registered
/// [DslAwareCodeGenerator] implementations using a unified [DslContext].
///
/// This design avoids type branching and adheres to Open/Closed Principle by
/// delegating DSL-specific logic to the generators themselves.
///
/// Note: adding new DSL types may require extending [DslContext],
/// which is considered an acceptable and localized compromise.
class DslGenerator extends Generator {
  /// Creates a generator that aggregates DSLs and writes output via [strategy].
  const DslGenerator(this.strategy, {required this.cliContext});

  /// Write strategy used for persisting generated files.
  final CompositeWriteStrategy strategy;

  /// Execution context with CLI-level preferences.
  final CliContext cliContext;

  @override
  Future<void> generate(
    List<IModuleCodeContributor> modules,
    Logger logger,
    Map<String, dynamic> coreVars,
    String generateTo,
  ) async {
    final dslGenerators = modules.whereType<DslAwareCodeGenerator>().toList();
    final diGroups = modules.map((m) => m.di).expand((e) => e).toList();
    final routeGroups = modules.map((m) => m.routes).toList();
    final shellDeclarations = _toShellDeclarations(routeGroups);
    final initialRoute = cliContext.initialRoute ?? '/noModules';

    final context = DslContext(
      projectRootPath: generateTo,
      mustacheVariables: coreVars,
      logger: logger,
      diGroups: diGroups,
      routeGroups: routeGroups,
      shellDeclarations: shellDeclarations,
      initialRoute: initialRoute,
    );

    for (final dslGenerator in dslGenerators) {
      final files = await dslGenerator.generateFromDsl(context);
      for (final file in files) {
        await strategy.write(file);
      }
    }
  }

  /// Collects unique shell declarations referenced by nested routes.
  List<ShellDeclaration> _toShellDeclarations(List<RouteGroup> routeGroups) {
    final shellIds = routeGroups
        .expand((group) => group.routes)
        .whereType<NestedRoute>()
        .map((r) => r.shellLink.id)
        .whereType<String>()
        .toSet();

    return shellIds.map((id) {
      final declaration = ShellRegistry.resolve(id);
      if (declaration == null) {
        throw ArgumentError(
          'Unknown shell link $id. Declare it in ShellRegistry.',
        );
      }

      return declaration;
    }).toList();
  }
}
