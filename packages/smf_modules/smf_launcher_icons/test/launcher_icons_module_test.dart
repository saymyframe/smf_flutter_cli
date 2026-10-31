@TestOn('vm')
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_launcher_icons/smf_launcher_icons.dart';
import 'package:smf_launcher_icons/src/agents.dart';
import 'package:smf_launcher_icons/src/brand.dart';
import 'package:smf_launcher_icons/src/readme.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: flutter_core, which creates the app, and this
/// module.
const List<SmfModule> _modules = [FlutterCoreModule(), LauncherIconsModule()];

/// The files that the module adds to an app.
const Set<String> _files = {
  configFile,
  updateScript,
  AppIconRole.imageFile,
  AppIconRole.foregroundFile,
};

/// What the contract harness finds for the app of [modules], which has no
/// errors and is rendered.
Future<ContractResult> _resultOf(List<ModuleId> modules) async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    ContractCase(modules.join(', '), requested: modules),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError(
      'The app of $modules has errors: ${result.errors.join('\n')}',
    );
  }
  return result;
}

void main() {
  late RenderedApp app;
  late RenderedApp without;

  setUpAll(() async {
    app = (await _resultOf(const [LauncherIconsModule.id])).app!;
    without = (await _resultOf(const [FlutterCoreModule.id])).app!;
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    });

    test('builds the app of the module, with its role', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core',
        'launcher_icons',
      ]);
    });

    test('finds no errors or warnings in any app', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.warnings, isEmpty, reason: '${result.contractCase}');
        expect(result.app, isNotNull, reason: '${result.contractCase}');
      }
    });

    test('leaves no provider of a role of the module unchecked', () async {
      expect(ModuleRegistry.problemsOf(_modules), isEmpty);
      expect(
        await ContractHarness(ModuleRegistry(_modules)).uncheckedProviders(),
        isEmpty,
      );
    });
  });

  group('the module', () {
    test('provides the app icon role, and depends on no module', () {
      const module = LauncherIconsModule();
      expect(module.descriptor.id, LauncherIconsModule.id);
      expect(
        module.descriptor.providers.map((provider) => provider.role),
        [appIconRole],
      );
      expect(module.descriptor.dependsOn, isEmpty);
    });

    test(
        'adds its files and nothing else to the files of the app, and leaves '
        'the native projects to the step', () {
      expect(
        app.files.keys.toSet(),
        {...without.files.keys, ..._files},
      );
      for (final path in _files) {
        expect(
          app.files[path]!.owner,
          const ModuleOrigin(LauncherIconsModule.id),
          reason: path,
        );
      }
    });

    test('does not bundle the sources in the app', () {
      final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;
      final flutter = pubspec['flutter'] as YamlMap;
      expect(flutter['assets'], isNull);
    });

    test('adds the tool as a dev dependency only', () {
      final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;
      expect(
        (pubspec['dev_dependencies'] as YamlMap)['flutter_launcher_icons'],
        '^0.14.4',
      );
      expect(
        (pubspec['dependencies'] as YamlMap).keys,
        isNot(contains('flutter_launcher_icons')),
      );
    });

    test(
        'runs the script of the app after generation, in every run, and may '
        'fail without losing the app', () {
      final step = const LauncherIconsModule()
          .contribute(ContractHarness.defaultContext)
          .whereType<PostGenStep>()
          .single;

      expect(step.tool.executable, 'dart');
      expect(step.arguments, [updateScript]);
      expect(step.skippable, isTrue);
      expect(step.external, isFalse);
      expect(step.interactive, isFalse);
      expect(step.notice, isNull);
      expect(step.hosts, isEmpty);
      expect(step.needs, isEmpty);
      expect(step.followUpOf, isNull);
    });
  });

  group('the files of the brick', () {
    test('the configuration of the tool names the sources and the colour', () {
      final file = loadYaml(app.files[configFile]!.text) as YamlMap;
      final config = file['flutter_launcher_icons'] as YamlMap;
      expect(config['image_path'], AppIconRole.imageFile);
      expect(config['adaptive_icon_foreground'], AppIconRole.foregroundFile);
      expect(config['adaptive_icon_monochrome'], AppIconRole.foregroundFile);
      expect(config['adaptive_icon_background'], iconBackground);
      expect(config['background_color_ios'], iconBackground);
      expect(config['remove_alpha_ios'], isTrue);
      expect(config['android'], isTrue);
      expect(config['ios'], isTrue);
    });

    test('the script is Dart that imports the tool and names the Xcode project',
        () {
      final unit = parseString(content: app.files[updateScript]!.text).unit;
      expect(
        unit.directives
            .whereType<ImportDirective>()
            .map((directive) => directive.uri.stringValue!)
            .where((uri) => uri.startsWith('package:')),
        [startsWith('package:flutter_launcher_icons/')],
      );
      final constants = {
        for (final declaration
            in unit.declarations.whereType<TopLevelVariableDeclaration>())
          for (final variable in declaration.variables.variables)
            variable.name.lexeme: variable.initializer,
      };
      expect(
        (constants['_project']! as StringLiteral).stringValue,
        AppEntryRole.xcodeProjectFile,
      );
    });
  });

  group('what the app says of the icon', () {
    test('the README has the section of the module, with the command', () {
      final readme = app.files[AppEntryRole.readmeFile]!.text;
      expect(readme, contains('\n## $readmeHeading\n'));
      expect(readme, contains(readmeSection));
      expect(readmeSection, contains('\n$updateCommand\n'));
      expect(readmeSection, contains('90%'));
      expect(
        without.files[AppEntryRole.readmeFile]!.text,
        isNot(contains(readmeHeading)),
      );
    });

    test('the guide has the note of the module under the heading of the role',
        () {
      final notes = app.entriesOf(AppEntryRole.agentSections);
      expect(
        [
          for (final (origin, heading, note) in notes)
            if (heading == appIconRole.description) (origin, note.isOfRole),
        ],
        // The template of a role contributes after its providers; the guide
        // shows what the role says first.
        [
          (const ModuleOrigin(LauncherIconsModule.id), false),
          (const RoleTemplateOrigin(appIconRole), true),
        ],
      );
      expect(agentNote, startsWith('With `flutter_launcher_icons`:\n'));
      expect(agentNote, contains('`$updateCommand`'));
    });
  });
}
