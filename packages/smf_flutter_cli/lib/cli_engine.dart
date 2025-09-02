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
import 'package:smf_flutter_cli/bundles/smf_cli_brick_bundle.dart';
import 'package:smf_flutter_cli/file_writers/composite_write_strategy.dart';
import 'package:smf_flutter_cli/file_writers/default_write_strategy.dart';
import 'package:smf_flutter_cli/generators/brick_generator.dart';
import 'package:smf_flutter_cli/generators/dsl_generator.dart';
import 'package:smf_flutter_cli/generators/pubspec_generator.dart';
import 'package:smf_flutter_cli/generators/sharable_generator.dart';
import 'package:smf_flutter_cli/prompts/models/cli_context.dart';

/// Entrypoint that orchestrates project generation using selected modules.
Future<void> runCli(CliContext context) async {
  final cliGenerator = await MasonGenerator.fromBundle(smfCliBrickBundle);
  final coreVars = <String, dynamic>{
    kWorkingDirectory: context.outputDirectory,
    'modules': '[${context.selectedModules.map(
          (e) => "'${e.moduleDescriptor.name}'",
        ).join(',')}]',
    'app_name': context.name,
    'org_name': context.packageName,
    'strict_mode': context.strictMode == StrictMode.strict,
  };
  await cliGenerator.hooks.preGen(
    vars: coreVars,
    onVarsChanged: coreVars.addAll,
    logger: context.logger,
  );

  final writeStrategy = CompositeWriteStrategy([DefaultWriteStrategy()]);

  // Generate individual brick contributions
  context.logger.info('📦 Generating brick contributions...');
  await BrickGenerator(context.moduleResolver).generate(
    context.selectedModules,
    context.logger,
    coreVars,
    context.outputDirectory,
  );

  // Generate shared file contributions
  context.logger.info('🔧 Applying shared file contributions...');
  await const SharableGenerator().generate(
    context.selectedModules,
    context.logger,
    coreVars,
    coreVars[kWorkingDirectory] as String,
  );

  context.logger.info('🛣️ Generating from dsls...');
  await DslGenerator(writeStrategy, cliContext: context).generate(
    context.selectedModules,
    context.logger,
    coreVars,
    coreVars[kWorkingDirectory] as String,
  );

  // Generate dependencies to pubspec
  context.logger.info('📋 Updating pubspec.yaml...');
  await const PubspecGenerator().generate(
    context.selectedModules,
    context.logger,
    coreVars,
    coreVars[kWorkingDirectory] as String,
  );

  context.logger.info('🏁 Running post gen cli hook...');
  await cliGenerator.hooks.postGen(
    vars: coreVars,
    logger: context.logger,
  );
}
