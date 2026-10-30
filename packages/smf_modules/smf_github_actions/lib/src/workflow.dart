import 'package:smf_contracts/smf_contracts.dart';

/// An action at a full commit, with its tag in a comment after the line of the
/// step: a tag can move, and SMF cannot change the file once it is in the
/// repository of the app.
const _checkout =
    'actions/checkout@3d3c42e5aac5ba805825da76410c181273ba90b1 # v7.0.1';
const _flutter =
    'subosito/flutter-action@1a449444c387b1966244ae4d4f8c696479add0b2 # v2.23.0';
const _java =
    'actions/setup-java@b843ebf9b913146b38da2eaa7aeddf76074ae1ad # v6.1.0';
const _upload =
    'actions/upload-artifact@cf430e030ddbb5b0abf93d22962f4752f3646cd9 # v7.0.2';

/// The variable of the process that has the environment of a build, so that
/// the choice of the developer never is a part of the text of a script.
const _environmentVariable = 'APP_ENVIRONMENT';

/// The choice of the developer, where GitHub reads an expression.
const _chosenEnvironment = r'${{ inputs.environment }}';

/// The steps of a job that sets up Flutter, at the indent of a step.
const _flutterStep = '''
      - uses: $_flutter
        with:
          channel: stable
          cache: true''';

/// The workflow of an app with [pipeline], which [CiRole.pipelineIn] gives:
/// the text of `.github/workflows/ci.yml`.
///
/// A job for the checks runs on each push, on any branch whichever default a
/// repository has, and on no tag. A job for the build runs when a developer
/// asks for it. The `env:` of the step that runs [CiRole.writeEnvFile] gives
/// the script the value of each key from the variable of the environment on
/// GitHub, and no `run:` has an expression, so that no value runs as code.
String workflowOf(CiPipeline pipeline) {
  final build = pipeline.build;
  return '''
# The CI of this app. The section "GitHub Actions" of README.md tells what it
# runs and where its values come from.
name: CI

on:
  push:
    branches: ["**"]
  workflow_dispatch:
    inputs:
      environment:
        description: The environment to build the Android app for
        type: choice
        required: true
        default: ${build.environments.first}
        options:
${build.environments.map((name) => '          - $name').join('\n')}

permissions:
  contents: read

concurrency:
  group: \${{ github.workflow }}-\${{ github.ref }}-\${{ github.event_name }}
  cancel-in-progress: \${{ github.event_name == 'push' }}

jobs:
  checks:
    name: Format, analyze and test
    if: github.event_name == 'push'
    runs-on: ubuntu-latest
    timeout-minutes: 20
    steps:
      - uses: $_checkout
$_flutterStep
${pipeline.checks.map(_stepOf).join('\n')}

  build:
    name: Build for Android ($_chosenEnvironment)
    if: github.event_name == 'workflow_dispatch'
    runs-on: ubuntu-latest
    timeout-minutes: 45
    environment: $_chosenEnvironment
    steps:
      - uses: $_checkout
      - uses: $_java
        with:
          distribution: temurin
          java-version: "17"
          cache: gradle
$_flutterStep
${build.prepare.map((command) => _stepOf(command, keys: build.keys)).join('\n')}
${_buildStepOf(build)}
      - uses: $_upload
        with:
          name: app-$_chosenEnvironment-release
          path: ${build.artifact.of(_chosenEnvironment)}
          if-no-files-found: error
''';
}

/// The step that runs the build, with the choice of the developer in a variable
/// of the process.
String _buildStepOf(CiBuild build) => _step(
      build.name,
      build.command.of('"\$$_environmentVariable"'),
      env: const {_environmentVariable: _chosenEnvironment},
    );

/// The step of [command]. The step that writes `.env` gets the variable of
/// each of [keys].
String _stepOf(CiCommand command, {List<String> keys = const []}) => _step(
      command.name,
      command.command,
      env: {
        if (command.command.endsWith(CiRole.writeEnvFile))
          for (final key in keys) key: '\${{ vars.$key }}',
      },
    );

/// A step with [name] that runs [command], with the variables of [env].
String _step(
  String name,
  String command, {
  Map<String, String> env = const {},
}) =>
    [
      '      - name: $name',
      if (env.isNotEmpty) '        env:',
      for (final MapEntry(:key, :value) in env.entries)
        '          $key: $value',
      ..._runOf(command),
    ].join('\n');

/// The lines of the `run:` of [command]: on one line when YAML reads the
/// command as a plain text, and otherwise as a block, which YAML reads as it
/// is. A command that starts with `[` would be a list, and one with `: ` or
/// ` #` a map or a comment.
List<String> _runOf(String command) => _isPlain(command)
    ? ['        run: $command']
    : ['        run: |', '          $command'];

/// Whether YAML reads [command] as a plain text, as it is.
bool _isPlain(String command) =>
    RegExp('^[A-Za-z]').hasMatch(command) &&
    !command.contains(': ') &&
    !command.contains(' #') &&
    !command.endsWith(':');
