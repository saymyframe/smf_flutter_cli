// Patches the lib/main.dart of a Flutter project: adds an import and a call
// before runApp(). Run it with
// `dart run example/smf_contribution_engine_example.dart`.
//
// It prints:
//
//   import 'package:flutter/material.dart';
//   import 'package:shop_app/logging.dart';
//
//   void main() {
//     setUpLogging();
//     runApp(const MaterialApp(home: Placeholder()));
//   }
import 'dart:io';

import 'package:smf_contribution_engine/smf_contribution_engine.dart';

const _main = '''
import 'package:flutter/material.dart';

void main() {
  runApp(const MaterialApp(home: Placeholder()));
}
''';

Future<void> main() async {
  final project = Directory.systemTemp.createTempSync('smf_engine_example');
  try {
    final file = File('${project.path}/lib/main.dart')
      ..createSync(recursive: true)
      ..writeAsStringSync(_main);

    // Each contribution parses the file and finds its target by the names
    // in the source. The engine renders the placeholders in the text that a
    // contribution inserts: {{app_name_sc}} is app_name in snake_case.
    await PatchEngine(
      const [
        InsertImport(
          file: 'lib/main.dart',
          import: "import 'package:{{app_name_sc}}/logging.dart';",
        ),
        InsertIntoFunction(
          file: 'lib/main.dart',
          function: 'main',
          beforeStatement: 'runApp(',
          insert: 'setUpLogging();',
        ),
      ],
      projectRoot: project.path,
      mustacheVariables: const {'app_name': 'shop app'},
    ).applyAll();

    stdout.write(file.readAsStringSync());
  } finally {
    project.deleteSync(recursive: true);
  }
}
