import 'dart:convert';

import 'package:mason/mason.dart' show MasonBundle, MasonBundledFile;
import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';

import '../support.dart';

/// The start of a PNG, which is no text in UTF-8.
final String _image = base64.encode([0x89, 0x50, 0x4e, 0x47]);

/// A brick of the images at [paths], as a provider would generate them.
MasonBundle _images(List<String> paths) => MasonBundle(
      name: 'images',
      description: 'images',
      version: '0.1.0',
      files: [
        for (final path in paths) MasonBundledFile(path, _image, 'binary'),
      ],
      hooks: const [],
    );

const _sources = [
  AppIconRole.imageFile,
  AppIconRole.foregroundFile,
  SplashRole.lightImageFile,
  SplashRole.darkImageFile,
];

/// A step of a tool that no package of pub.dev brings.
const _step = PostGenStep(ToolRef('draw_images'), ['--all'], skippable: true);

/// One module that provides both roles with [contributions], as nothing
/// keeps a module from doing.
TestModule _provider(List<Contribution> contributions) => TestModule(
      'look',
      providers: const [
        RoleProvider.plain(appIconRole),
        RoleProvider.plain(splashRole),
      ],
      contributions: contributions,
    );

/// The app of [provider].
Future<ContractResult> _appOf(TestModule provider) =>
    ContractHarness(ModuleRegistry([scaffold(), provider])).check(
      const ContractCase('look', requested: [ModuleId('look')]),
    );

void main() {
  test(
      'an app with a provider that only has the images and a step of its own '
      'keeps every rule, with the sections and the notes of the two roles',
      () async {
    final result = await _appOf(
      _provider([BrickContribution(_images(_sources)), _step]),
    );

    expect(result.issues, isEmpty);
    final app = result.app!;
    for (final source in _sources) {
      expect(app.owners[source], const ModuleOrigin(ModuleId('look')));
      expect(app.texts, isNot(contains(source)));
    }
    final readme = app.texts['README.md']!;
    final guide = app.texts[AppEntryRole.agentsFile]!;
    expect(readme, contains('## ${AppIconRole.readmeHeading}\n'));
    expect(readme, contains('## ${SplashRole.readmeHeading}\n'));
    expect(guide, contains('## ${appIconRole.description}\n'));
    expect(guide, contains('## ${splashRole.description}\n'));
    for (final source in _sources) {
      expect(readme, contains('`$source`'));
      expect(guide, contains('`$source`'));
    }
    expect(
      result.validation!.postGenOrder.contributions
          .map((step) => step.contribution),
      contains(same(_step)),
    );
  });

  test(
      'the notes of the two roles name no module behind them, also not the '
      'images, which only the provider generates', () async {
    final result = await _appOf(
      _provider([BrickContribution(_images(_sources)), _step]),
    );

    expect(
      roleNoteProblems(
        [result],
        AppEntryRole.agentSections,
        textOf: (note) => note.text,
      ),
      isEmpty,
    );
  });

  test('the harness reports an image that the provider does not generate',
      () async {
    final result = await _appOf(
      _provider([
        BrickContribution(_images(_sources.skip(1).toList())),
        _step,
      ]),
    );

    expect(
      [for (final issue in result.issues) issue.message],
      contains(
        'The module look provides the $appIconRole, whose every provider '
        'generates ${AppIconRole.imageFile}, but the app has no such file.',
      ),
    );
  });

  test('validation reports a provider without a step, for each of its roles',
      () async {
    final result = await _appOf(
      _provider([BrickContribution(_images(_sources))]),
    );

    expect(
      [for (final issue in result.issues) issue.message],
      containsAll([
        contains('provides the $appIconRole, which needs a step'),
        contains('provides the $splashRole, which needs a step'),
      ]),
    );
    expect(
      {for (final issue in result.issues) issue.origin},
      {const ModuleOrigin(ModuleId('look'))},
    );
  });
}
