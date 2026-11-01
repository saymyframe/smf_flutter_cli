@TestOn('vm')
library;

import 'package:smf_contracts/smf_contracts.dart';
import 'package:smf_github_actions/src/workflow.dart';
import 'package:smf_pipeline/testing.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

import 'support/apps.dart';

/// What stands for the choice of the developer where GitHub reads an
/// expression.
const _chosen = r'${{ inputs.environment }}';

/// The steps of the job [job] of [workflow].
List<YamlMap> _stepsOf(YamlMap workflow, String job) {
  final jobs = workflow['jobs'] as YamlMap;
  return ((jobs[job] as YamlMap)['steps'] as YamlList).cast<YamlMap>().toList();
}

/// The steps of [steps] that run a command, each as its name and its command,
/// without the line break of a block.
List<(String, String)> _runsOf(List<YamlMap> steps) => [
      for (final step in steps)
        if (step.containsKey('run'))
          (step['name'] as String, (step['run'] as String).trimRight()),
    ];

/// The step of [steps] that uses the action [action].
YamlMap _stepOfAction(List<YamlMap> steps, String action) => steps.singleWhere(
      (step) => '${step['uses']}'.startsWith('$action@'),
    );

/// [commands] of the role, each as its name and its command.
List<(String, String)> _commandsOf(List<CiCommand> commands) => [
      for (final command in commands) (command.name, command.command),
    ];

/// The pipeline of an app with the env role whose provider gives the tool
/// arguments [arguments].
CiPipeline _pipelineWith(List<String> arguments) => ciRole.pipelineIn(
      ciRole.hookInput(
        RoleHookRequest(
          data: [
            envRole.data(EnvToolArguments(arguments)).withOrigin(
                  const ModuleOrigin(ModuleId('another_env')),
                ),
          ],
          presentRoles: const {ciRole, envRole},
          context: ContractHarness.defaultContext,
        ),
      ),
    );

void main() {
  final apps = {
    'without the env role': withoutEnv,
    'with the env role and no keys': withEnv,
    'with the env role and keys': withKeys,
  };

  for (final MapEntry(key: name, value: modules) in apps.entries) {
    group('the workflow of an app $name', () {
      late String text;
      late YamlMap workflow;
      late CiPipeline pipeline;

      setUpAll(() async {
        final result = await renderedApp(modules);
        text = workflowTextOf(result);
        workflow = parsedWorkflow(text);
        pipeline = pipelineOf(result);
      });

      test('runs the checks of the role, in their order, on a push', () {
        final job = (workflow['jobs'] as YamlMap)['checks'] as YamlMap;

        expect(job['if'], "github.event_name == 'push'");
        expect(
          _runsOf(_stepsOf(workflow, 'checks')),
          _commandsOf(pipeline.checks),
        );
      });

      test(
          'runs the preparation and the build of the role, in their order, '
          'on request, with the choice of the developer in a variable', () {
        final job = (workflow['jobs'] as YamlMap)['build'] as YamlMap;
        final build = pipeline.build;

        expect(job['if'], "github.event_name == 'workflow_dispatch'");
        expect(job['environment'], _chosen);
        expect(_runsOf(_stepsOf(workflow, 'build')), [
          ..._commandsOf(build.prepare),
          (build.name, build.command.of(r'"$APP_ENVIRONMENT"')),
        ]);
        final step = _stepsOf(workflow, 'build').singleWhere(
          (step) => step['name'] == build.name,
        );
        expect(step['env'], {'APP_ENVIRONMENT': _chosen});
      });

      test(
          'names a skipped job without an expression, which GitHub would '
          'show as it is on every push, and a run by its environment', () {
        final job = (workflow['jobs'] as YamlMap)['build'] as YamlMap;

        expect(job['name'], 'Build for Android');
        expect(
          workflow['run-name'],
          r"${{ inputs.environment && format('Build for Android ({0})', "
          "inputs.environment) || '' }}",
        );
      });

      test('offers the environments of the role, the first by default', () {
        final on = workflow['on'] as YamlMap;
        final dispatch = on['workflow_dispatch'] as YamlMap;
        final input = (dispatch['inputs'] as YamlMap)['environment'] as YamlMap;
        final environments = pipeline.build.environments;

        expect(on['push'], {
          'branches': ['**'],
        });
        expect(input['type'], 'choice');
        expect(input['options'], environments);
        expect(input['default'], environments.first);
      });

      test('gives only the step that writes .env the keys of the role', () {
        final keys = pipeline.build.keys;
        final build = pipeline.build.command.of(r'"$APP_ENVIRONMENT"');
        final withEnv = {
          for (final step in _stepsOf(workflow, 'build'))
            if (step['env'] case final YamlMap env)
              if (step['run'] != build) step['run'] as String: env,
        };

        if (keys.isEmpty) {
          expect(withEnv, isEmpty);
        } else {
          expect(withEnv.keys, ['dart ${CiRole.writeEnvFile}']);
          expect(withEnv.values.single, {
            for (final key in keys) key: '\${{ vars.$key }}',
          });
        }
        for (final step in _stepsOf(workflow, 'checks')) {
          expect(step.containsKey('env'), isFalse, reason: '$step');
        }
      });

      test('has no expression in a command, so that no value runs as code', () {
        for (final job in ['checks', 'build']) {
          for (final (name, command) in _runsOf(_stepsOf(workflow, job))) {
            expect(command, isNot(contains(r'${{')), reason: name);
          }
        }
      });

      test('pins each action to a full commit, with its tag in a comment', () {
        final pinned = RegExp(
          r'^\s*- uses: [\w-]+/[\w-]+@[0-9a-f]{40} # v\d+\.\d+\.\d+$',
        );
        final lines = [
          for (final line in text.split('\n'))
            if (line.contains('uses:')) line,
        ];

        expect(lines, isNotEmpty);
        for (final line in lines) {
          expect(line, matches(pinned));
        }
      });

      test('can do nothing but read the repository', () {
        expect(workflow['permissions'], {'contents': 'read'});
      });

      test('checks out and sets up what each job needs, before its commands',
          () {
        for (final job in ['checks', 'build']) {
          final steps = _stepsOf(workflow, job);
          expect(_stepOfAction(steps, 'actions/checkout'), steps.first);
          final flutter = _stepOfAction(steps, 'subosito/flutter-action');
          expect(flutter['with'], {'channel': 'stable', 'cache': true});
          final firstRun = steps.indexWhere((s) => s.containsKey('run'));
          expect(steps.indexOf(flutter), lessThan(firstRun));
        }
        final java =
            _stepOfAction(_stepsOf(workflow, 'build'), 'actions/setup-java');
        expect(java['with'], {
          'distribution': 'temurin',
          'java-version': '17',
          'cache': 'gradle',
        });
      });

      test('keeps the file of the build, and fails when there is none', () {
        final steps = _stepsOf(workflow, 'build');
        final upload = _stepOfAction(steps, 'actions/upload-artifact');

        expect(steps.last, upload);
        expect(upload['with'], {
          'name': 'app-$_chosen-release',
          'path': pipeline.build.artifact.of(_chosen),
          'if-no-files-found': 'error',
        });
      });

      test(
          'cancels the run of an older push, and keeps a build from taking '
          'the place of a build of another environment that waits', () {
        final concurrency = workflow['concurrency'] as YamlMap;

        expect(concurrency['group'], contains(r'${{ github.ref }}'));
        expect(concurrency['group'], contains(r'${{ github.event_name }}'));
        expect(concurrency['group'], contains(_chosen));
        expect(
          concurrency['cancel-in-progress'],
          r"${{ github.event_name == 'push' }}",
        );
      });
    });
  }

  group('a command that YAML would read as something else', () {
    /// The commands of [pipeline] as the workflow has them, after YAML read
    /// the workflow, with what the job of the build puts in place of the
    /// environment.
    List<String> commandsRead(CiPipeline pipeline) {
      final workflow = parsedWorkflow(workflowOf(pipeline));
      return [
        for (final job in ['checks', 'build'])
          for (final (_, command) in _runsOf(_stepsOf(workflow, job))) command,
      ];
    }

    /// The commands of [pipeline], each as it has to run.
    List<String> commandsOf(CiPipeline pipeline) => [
          for (final command in pipeline.checks) command.command,
          for (final command in pipeline.build.prepare) command.command,
          pipeline.build.command.of(r'"$APP_ENVIRONMENT"'),
        ];

    for (final (what, arguments) in const [
      ('a word with a colon and a space', ['--note=a: b']),
      ('a word with a space and a hash', ['--note=a #b']),
      ('a word that ends with a colon', ['--note=a:']),
      ('two words and a quote', ['--dart-define-from-file', ".env's"]),
    ]) {
      test('stays as it is with $what among the tool arguments', () {
        final pipeline = _pipelineWith(arguments);

        expect(commandsRead(pipeline), commandsOf(pipeline));
      });
    }

    test('keeps the command that starts with a bracket from being a list', () {
      final pipeline = _pipelineWith(const []);
      final command = pipeline.checks.first.command;

      expect(command, startsWith('['));
      expect(commandsRead(pipeline), contains(command));
    });
  });
}
