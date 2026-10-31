@TestOn('vm')
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_github_actions/smf_github_actions.dart';
import 'package:smf_github_actions/src/agents.dart';
import 'package:smf_pipeline/smf_pipeline.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/apps.dart';

/// The section of the module in the README of the app of [result].
String _readmeSectionOf(ContractResult result) {
  final readme = result.app!.files[AppEntryRole.readmeFile]!.text;
  final start = readme.indexOf('## ${GithubActionsModule.readmeHeading}\n');
  expect(start, isNot(-1));
  final end = readme.indexOf('\n## ', start);
  return readme.substring(start, end == -1 ? readme.length : end);
}

/// The notes of the module in the guide for coding agents of the app of
/// [result], in their order.
List<AgentNote> _notesOf(ContractResult result) => [
      for (final (origin, _, note)
          in result.app!.entriesOf(AppEntryRole.agentSections))
        if (origin == const ModuleOrigin(GithubActionsModule.id)) note,
    ];

void main() {
  const module = GithubActionsModule();

  group('GithubActionsModule', () {
    test('is infrastructure that provides the CI role and needs nothing', () {
      final descriptor = module.descriptor;

      expect(descriptor.id, const ModuleId('github_actions'));
      expect(descriptor.kind, ModuleKinds.infrastructure);
      expect(descriptor.provides, {ciRole});
      expect(descriptor.dependsOn, isEmpty);
      expect(descriptor.requires, isEmpty);
      expect(descriptor.uses, isEmpty);
      expect(descriptor.variants, isNull);
    });

    test('forms a valid registry with the modules of the tests', () {
      expect(ModuleRegistry.problemsOf(testModules), isEmpty);
    });
  });

  group('the contract harness', () {
    late List<ContractResult> results;

    setUpAll(() async {
      results = await ContractHarness(ModuleRegistry(testModules)).checkAll();
    });

    test('builds the app of the module with the env role and without it', () {
      expect(results.map((result) => result.contractCase.name), [
        'flutter_core',
        'dart_define',
        'github_actions with env',
        'github_actions',
        'shop',
      ]);
    });

    test('finds no errors in any app, and no warning', () {
      for (final result in results) {
        expect(
          result.errors.map((issue) => '$issue'),
          isEmpty,
          reason: '${result.contractCase}',
        );
        expect(result.app, isNotNull, reason: '${result.contractCase}');
        expect(result.warnings, isEmpty, reason: '${result.contractCase}');
      }
    });

    test('leaves no provider of the env role unchecked', () async {
      expect(
        await ContractHarness(ModuleRegistry(testModules)).uncheckedProviders(),
        isEmpty,
      );
    });
  });

  group('the app of the module', () {
    test('has the workflow as a file of the module, and no other file',
        () async {
      for (final modules in [withoutEnv, withEnv, withKeys]) {
        final result = await renderedApp(modules);

        expect(
          [
            for (final file in result.app!.files.values)
              if (file.owner == const ModuleOrigin(GithubActionsModule.id))
                file.path,
          ],
          ['.github/workflows/ci.yml'],
          reason: '$modules',
        );
      }
    });

    test('passes the rule of the role with the keys of its modules', () async {
      final result = await renderedApp(withKeys);

      expect(pipelineOf(result).build.keys, ShopModule.keys);
      expect(
        result.app!.files[EnvRole.exampleFile]!.text,
        allOf(contains('SHOP_APPLE_KEY='), contains('SHOP_TERMS_URL=')),
      );
    });
  });

  group('the section of the module in the README of the app', () {
    test('tells how to start a build, and needs no env role for that',
        () async {
      final section = _readmeSectionOf(await renderedApp(withoutEnv));

      expect(section, contains('`${GithubActionsModule.workflowFile}`'));
      expect(section, contains('"${CiRole.readmeHeading}"'));
      expect(section, contains('**Run workflow**'));
      expect(section, contains('gh workflow run ci.yml -f environment=dev'));
      expect(section, contains('default branch'));
    });

    test(
        'names the format check and the analyzer as what a new Flutter can '
        'turn red, and the line that pins Flutter under the channel of the '
        'workflow', () async {
      final result = await renderedApp(withoutEnv);
      final section = _readmeSectionOf(result);
      final workflow = parsedWorkflow(workflowTextOf(result));

      expect(section, contains('`flutter analyze`'));
      expect(section, contains('format check'));
      expect(section, contains('`flutter-version: <version>`'));
      expect(section, contains('`channel: stable`'));
      for (final job in (workflow['jobs'] as YamlMap).values) {
        final steps = (job as YamlMap)['steps'] as YamlList;
        final flutter = steps.cast<YamlMap>().singleWhere(
              (step) =>
                  '${step['uses']}'.startsWith('subosito/flutter-action@'),
            );
        expect((flutter['with'] as YamlMap)['channel'], 'stable');
      }
    });

    test('says nothing of values in an app without the env role', () async {
      final section = _readmeSectionOf(await renderedApp(withoutEnv));

      expect(section, isNot(contains(EnvRole.dotEnvFile)));
      expect(section, isNot(contains('gh variable set')));
      expect(section, isNot(contains('Environment variables')));
    });

    test('lists the keys of the app, and where their values go', () async {
      final section = _readmeSectionOf(await renderedApp(withKeys));

      for (final key in ShopModule.keys) {
        expect(section, contains('- `$key`'));
      }
      expect(section, contains('**Environment variables**'));
      expect(section, contains('**Repository variables**'));
      expect(section, contains('`dev`, `staging` and `prod`'));
      expect(section, contains('gh variable set <KEY> --env dev'));
    });

    test(
        'tells where values go in an app with the env role and no keys, and '
        'lists none', () async {
      final section = _readmeSectionOf(await renderedApp(withEnv));

      expect(
        section,
        contains('by the names of the keys. With the GitHub CLI'),
      );
      expect(section, isNot(contains('- `')));
      expect(section, contains('gh variable set <KEY>'));
      expect(
        section,
        contains(r'`MY_SERVICE_KEY: ${{ vars.MY_SERVICE_KEY }}`'),
      );
    });
  });

  group('the note of the module in the guide for coding agents', () {
    test('opens with the host', () {
      expect(agentNote, startsWith('With `GitHub Actions`:\n'));
    });

    test('names the jobs that the workflow has', () async {
      final result = await renderedApp(withoutEnv);
      final jobs = parsedWorkflow(workflowTextOf(result))['jobs'] as YamlMap;

      for (final job in jobs.keys) {
        expect(agentNote, contains('`$job`'));
      }
      expect(agentNote, contains('`${GithubActionsModule.workflowFile}`'));
    });

    test('tells of keys only in an app with the env role', () async {
      expect(_notesOf(await renderedApp(withoutEnv)), [AgentNote(agentNote)]);
      expect(
        _notesOf(await renderedApp(withEnv)),
        [AgentNote(agentNote), AgentNote(envAgentNote)],
      );
      expect(envAgentNote, contains('`${CiRole.writeEnvFile}`'));
      expect(envAgentNote, contains('`${EnvRole.dotEnvFile}`'));
    });
  });
}
