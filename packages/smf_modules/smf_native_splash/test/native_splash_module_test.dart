@TestOn('vm')
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_flutter_core/smf_flutter_core.dart';
import 'package:smf_native_splash/smf_native_splash.dart';
import 'package:smf_native_splash/src/agents.dart';
import 'package:smf_native_splash/src/config.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

/// The modules of the tests: flutter_core, which creates the app, and this
/// module.
const List<SmfModule> _modules = [FlutterCoreModule(), NativeSplashModule()];

const _origin = ModuleOrigin(NativeSplashModule.id);

/// What the contract harness finds for the app of the module, rendered and
/// without errors.
Future<ContractResult> _rendered() async {
  final result = await ContractHarness(ModuleRegistry(_modules)).check(
    const ContractCase(
      'native_splash',
      requested: [NativeSplashModule.id],
    ),
  );
  if (result.errors.isNotEmpty || result.app == null) {
    throw StateError('The app has errors: ${result.errors.join('\n')}');
  }
  return result;
}

/// What the module contributes, of the type [T].
Iterable<T> _contributions<T extends Contribution>() =>
    const NativeSplashModule()
        .contribute(ContractHarness.defaultContext)
        .whereType<T>();

/// The text of the section of the module in the README of the app.
String _readmeSection() => _contributions<SocketContribution>()
    .singleWhere((socket) => socket.socket == AppEntryRole.readmeSections)
    .entryValue! as String;

void main() {
  test('every app that the harness can build with the module has no errors',
      () async {
    final results = await ContractHarness(ModuleRegistry(_modules)).checkAll();
    expect(results, isNotEmpty);
    for (final result in results) {
      expect(result.errors, isEmpty, reason: result.contractCase.name);
    }
  });

  group('the module', () {
    test('provides the splash role, and is infrastructure', () {
      final descriptor = const NativeSplashModule().descriptor;
      expect(descriptor.id, const ModuleId('native_splash'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {splashRole});
      expect(descriptor.dependsOn, isEmpty);
    });

    test('adds the tool as a dev dependency, which no code of the app imports',
        () async {
      final dependency = _contributions<PubspecDependency>().single;
      expect(dependency.package, 'flutter_native_splash');
      expect(dependency.dev, isTrue);
      final app = (await _rendered()).app!;
      final pubspec = loadYaml(app.files['pubspec.yaml']!.text) as YamlMap;
      expect(
        (pubspec['dev_dependencies'] as YamlMap)['flutter_native_splash'],
        '^2.4.8',
      );
      expect(
        (pubspec['dependencies'] as YamlMap).keys,
        isNot(contains('flutter_native_splash')),
      );
      expect(
        [
          for (final MapEntry(key: path, value: file) in app.files.entries)
            if (path.endsWith('.dart') &&
                file.text.contains('package:flutter_native_splash'))
              path,
        ],
        isEmpty,
      );
    });

    test(
        'makes the screen with one step that any run takes, and that a run '
        'leaves for later when the tool fails', () {
      final step = _contributions<PostGenStep>().single;
      expect(step.tool.executable, 'dart');
      expect(step.arguments, ['run', 'flutter_native_splash:create']);
      expect(step.skippable, isTrue);
      expect(step.external, isFalse);
      expect(step.interactive, isFalse);
      expect(step.notice, isNull);
      expect(step.followUpOf, isNull);
      expect(step.needs, isEmpty);
    });
  });

  group('the configuration of the tool', () {
    late YamlMap config;

    setUpAll(() async {
      final app = (await _rendered()).app!;
      config = (loadYaml(app.files[configFile]!.text)
          as YamlMap)['flutter_native_splash'] as YamlMap;
    });

    test('has the colours of the module and the images of the role', () {
      for (final section in [config, config['android_12'] as YamlMap]) {
        expect(section['color'], splashLightBackground);
        expect(section['color_dark'], splashDarkBackground);
        expect(section['image'], SplashRole.lightImageFile);
        expect(section['image_dark'], SplashRole.darkImageFile);
      }
    });

    test('is for Android and iOS, and has no version of the system', () {
      expect(config['android'], isTrue);
      expect(config['ios'], isTrue);
      expect(config['web'], isFalse);
      // The trap of the tool: with it, the launch background that Android
      // below 12 reads keeps no image.
      expect(config.keys, isNot(contains('android_min_sdk')));
    });
  });

  group('what the module tells the developer of the app', () {
    test('the section of the README has its colours, the command and the trap',
        () async {
      final readme = _readmeSection();
      expect(
        readme,
        allOf(
          contains(SplashRole.lightImageFile),
          contains(SplashRole.darkImageFile),
          contains('`$configFile`'),
          contains('$splashCommand\n'),
          contains('`android_min_sdk`'),
        ),
      );
      final app = (await _rendered()).app!;
      final text = app.files[AppEntryRole.readmeFile]!.text;
      expect(
        text,
        contains('## ${NativeSplashModule.readmeHeading}\n'),
      );
      expect(text, contains('## ${SplashRole.readmeHeading}\n'));
    });

    test(
        'the note follows that of the role, opens with the package and gives '
        'the command that the note of the role leaves to it', () async {
      final result = await _rendered();
      final notes = [
        for (final (contributor, heading, value)
            in result.app!.entriesOf(AppEntryRole.agentSections))
          if (heading == splashRole.description) (contributor, value),
      ];
      expect(notes, contains((_origin, AgentNote(agentNote))));
      expect(
        notes,
        contains(
          predicate<(ContributionOrigin, Object?)>(
            (note) => note.$1 == const RoleTemplateOrigin(splashRole),
          ),
        ),
      );
      final guide = result.app!.files[AppEntryRole.agentsFile]!.text;
      expect(
        guide.indexOf(agentNote.trim()),
        greaterThan(guide.indexOf('`${SplashRole.lightImageFile}`')),
      );
      expect(agentNote, startsWith('With `flutter_native_splash`:\n'));
      expect(agentNote, contains('`$splashCommand`'));
      expect(agentNote, contains('`android_min_sdk`'));
      expect(agentNote, contains('`$configFile`'));
    });
  });
}
