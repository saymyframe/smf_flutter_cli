import 'dart:core';

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_cli/cli_engine.dart';
import 'package:smf_flutter_cli/commands/base.dart';
import 'package:smf_flutter_cli/promts/create_prompt.dart';
import 'package:smf_flutter_cli/promts/models/cli_context.dart';

final class CreateCommand extends BaseCommand {
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
      );
  }

  final allowedModules = <String>[
    kFirebaseCore,
    kFirebaseAnalytics,
    kGetItModule,
    kCommunicationModule,
    kGoRouterModule,
    kHomeFeatureModule
  ];

  @override
  String get description => 'Create flutter app';

  @override
  String get name => 'create';

  @override
  Future<void> run() async {
    final preferences = CreatePrompt().prompt(
      argResults,
      allowedModules: allowedModules,
    );

    return runCli(
      CliContext(
        name: preferences.name,
        packageName: preferences.packageName,
        selectedModules: preferences.selectedModules,
        outputDirectory: argResults?['output'] as String? ?? './',
        initialRoute: preferences.initialRoute,
        logger: logger,
      ),
    );
  }
}
