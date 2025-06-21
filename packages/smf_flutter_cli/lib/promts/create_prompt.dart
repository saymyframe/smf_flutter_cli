import 'dart:io' show stdout;

import 'package:smf_flutter_cli/promts/collectors/preferences_collector.dart';

class CreatePrompt {
  void prompt() {
    stdout.writeln(
      "👋 Hello! Let's create a flutter project with Say my Frame.",
    );

    final projectPreferences = PreferencesCollector().collect();
    print(projectPreferences);
  }
}
