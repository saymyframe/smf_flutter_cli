import 'dart:async';

import 'package:smf_analytics/smf_analytics.dart';
import 'package:smf_flutter_cli/cli_engine.dart';
import 'package:smf_flutter_cli/commands/base.dart';
import 'package:smf_flutter_cli/promts/create_prompt.dart';
import 'package:smf_flutter_cli/promts/models/cli_context.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_go_router/smf_go_router.dart';
import 'package:smf_home_flutter/smf_home_flutter.dart';

final class CreateCommand extends BaseCommand {
  CreateCommand() {
    argParser.addOption(
      'output',
      abbr: 'o',
      help: 'Output path. A path where project will be created',
      defaultsTo: './',
    );
  }

  @override
  String get description => 'Create flutter app';

  @override
  String get name => 'create';

  @override
  Future<void> run() async {
    return runCli(
      CliContext(
        name: 'my_cli_test_app',
        selectedModules: [
          SmfCoreModule(),
          FirebaseAnalyticsModule(),
          SmfGoRouterModule(),
          SmfHomeFlutterModule(),
        ],
        outputDirectory: argResults?['output'] as String? ?? './',
        logger: logger,
      ),
    );

    final preferences = CreatePrompt().prompt(argResults);
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
