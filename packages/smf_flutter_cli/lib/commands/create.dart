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

import 'dart:core';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/commands/base.dart';
import 'package:smf_flutter_cli/constants/smf_modules.dart';
import 'package:smf_flutter_cli/constants/smf_options.dart';
import 'package:smf_flutter_cli/prompts/prompt.dart';
import 'package:smf_flutter_cli/utils/module_creator.dart';
import 'package:smf_flutter_cli/utils/module_dependency_resolver.dart';
import 'package:smf_flutter_cli/utils/safe_generation_runner.dart';

/// CLI command that scaffolds a new Flutter app using Say My Frame modules.
final class CreateCommand extends BaseCommand {
  /// Creates a new create command with CLI flags for output, modules, and org.
  CreateCommand() {
    argParser
      ..addOption(
        'output',
        abbr: 'o',
        help: 'Output path. A path where project will be created',
        defaultsTo: './',
      )
      ..addOption(
        'modules',
        abbr: 'm',
        help: 'Modules to include (comma-separated values, '
            'e.g., firebase_core,home,firebase_analytics)',
      )
      ..addOption(
        'route',
        abbr: 'r',
        help: 'Initial route for the app (e.g., /home, /dashboard)',
      )
      ..addOption(
        'org',
        help: 'Organization name for app ID (format: org_name.app_name)',
      )
      ..addOption(
        'state-manager',
        abbr: 's',
        help: 'State manager to use (allowed: ${smfStateManagers.join(', ')})',
        allowed: smfStateManagers,
      );
  }

  /// Whitelist of allowed module identifiers that can be selected by users.
  final allowedModules = <String>[
    kFirebaseCore,
    kFirebaseAnalytics,
    kFirebaseCrashlytics,
    kGetItModule,
    kCommunicationModule,
    kGoRouterModule,
    kHomeFeatureModule,
  ];

  @override
  String get description => 'Create flutter app';

  @override
  String get name => 'create';

  @override
  Future<void> run() async {
    const moduleResolver = ModuleDependencyResolver();

    final isStrict = (globalResults?['strict'] as bool?) ?? false;
    final moduleCreator = ModuleCreator(
      moduleResolver,
      smfModules,
      coreModuleKeys: const [
        kFlutterCoreModule,
        kContractsModule,
      ],
    );
    final preferences = CreatePrompt(creator: moduleCreator).prompt(
      argResults,
      allowedModules: allowedModules,
      strictMode: isStrict ? StrictMode.strict : StrictMode.lenient,
      logger: logger,
    );

    return SafeGenerationRunner().run(
      CliContext(
        name: preferences.name,
        packageName: preferences.packageName,
        selectedModules: preferences.selectedModules,
        outputDirectory: argResults?['output'] as String? ?? './',
        initialRoute: preferences.initialRoute,
        strictMode: isStrict ? StrictMode.strict : StrictMode.lenient,
        logger: logger,
        moduleResolver: moduleResolver,
      ),
      onConflict: globalResults?['on-conflict'] as String? ?? 'prompt',
    );
  }
}
