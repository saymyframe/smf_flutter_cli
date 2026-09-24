import 'dart:io';

import 'package:mason/mason.dart';
import 'package:path/path.dart';
import 'package:smf_get_it/bundles/smf_get_it_brick_bundle.dart';

const appName = 'test_app';

/// Renders the get_it brick into [dir] the way the CLI does before running
/// the DSL generators, and returns the generated project root.
Future<String> renderGetItBrick(Directory dir) async {
  final generator = await MasonGenerator.fromBundle(smfGetItBrickBundle);
  await generator.generate(
    DirectoryGeneratorTarget(dir),
    vars: {'app_name': appName},
  );
  return join(dir.path, appName);
}

/// Writes a module DI template with the same slots as the core one to
/// [relativePath] under [projectRoot].
Future<void> writeModuleDiTemplate(
  String projectRoot,
  String relativePath, {
  required String setUpFunction,
}) async {
  final file = File(join(projectRoot, relativePath));
  await file.create(recursive: true);
  await file.writeAsString('''
import 'package:$appName/core/typedef.dart';
{{#imports}}
{{{.}}}
{{/imports}}

void $setUpFunction() {
  {{#di}}
  {{{.}}}
  {{/di}}
}
''');
}
