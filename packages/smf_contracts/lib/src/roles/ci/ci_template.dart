part of '../ci.dart';

/// The note of the CI role in the guide for coding agents, whichever module
/// provides the role and wherever it runs.
const _agentNote = '''
- CI runs the commands of the section "${CiRole.readmeHeading}" of `README.md`, in a fresh copy of the repository. Keep them passing, and run them before you finish a change.
- A generated file that the app needs stays in git, or comes from `flutter pub get`, since no other of these commands writes it.
''';

/// The note of the CI role in an app with the env role.
const _envAgentNote = '''
- `${CiRole.writeEnvFile}` writes `${EnvRole.dotEnvFile}` for a build of CI, from the keys of `${EnvRole.exampleFile}` and the variables of the process. A new key also needs its variable where CI runs. The script stops when `${EnvRole.dotEnvFile}` has a value, and never replaces one.
- The first check copies `${EnvRole.exampleFile}` only when `${EnvRole.dotEnvFile}` is missing, so running it keeps the values on your machine.
- A value of `${EnvRole.dotEnvFile}` ends up in the app, so never give a build of CI a secret through it.
''';

/// A block of shell [commands] for the README of the app.
String _commandBlock(Iterable<String> commands) =>
    '```bash\n${commands.join('\n')}\n```';

/// The section of the role in the README of the app, whichever module
/// provides the role: the commands of [pipeline], and where the values come
/// from in an app with the env role, as [hasEnv] tells.
String _readmeSection(CiPipeline pipeline, {required bool hasEnv}) {
  final build = pipeline.build;
  final names = [for (final name in build.environments) '`$name`'];
  final environments =
      '${names.sublist(0, names.length - 1).join(', ')} and ${names.last}';
  const placeholder = '<environment>';
  final buffer = StringBuffer('''
On each push, CI of this app runs these commands in a fresh copy of the repository:

${_commandBlock([for (final check in pipeline.checks) check.command])}

On request, it builds a release APK for one of the environments $environments:

${_commandBlock([
        for (final command in build.prepare) command.command,
        build.command.of(placeholder),
      ])}

The APK is `${build.artifact.of(placeholder)}`. The build signs it as the Android project of the app does, so it is for testers: uploading to a store, a signing key of your own and iOS are not part of it.
''');
  if (hasEnv) {
    buffer.write('''

CI writes its own `${EnvRole.dotEnvFile}`, since that file is not in git. The checks copy `${EnvRole.exampleFile}` when `${EnvRole.dotEnvFile}` is missing, so in a fresh copy every value is empty, and on your machine your values stay. A build takes the values of the chosen environment with `${CiRole.writeEnvFile}`, and lists the keys it found no value for. A value with a double quote or a line break stops the build, and so does a `${EnvRole.dotEnvFile}` that has a value already, which the script never replaces: delete the file to write it again. Every value ends up in the app, so never use one for a secret.
''');
  }
  buffer.write('''

The section of the module that provides CI tells how to start a build.
''');
  return '$buffer';
}

/// The template of the [CiRole]: the script that writes the values of a build,
/// the section of the role in the README of the app, and its notes for coding
/// agents.
final class _CiTemplate extends RoleTemplate<NoDsl> {
  const _CiTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(ciRoleEnvBundle, when: const {envRole}),
        AppEntryRole.agentSections.entry(
          ciRole.description,
          AgentNote.ofRole(_agentNote),
        ),
        AppEntryRole.agentSections.entry(
          ciRole.description,
          AgentNote.ofRole(_envAgentNote),
          when: const {envRole},
        ),
      ];

  @override
  RoleOutput render(RoleHookInput<NoDsl> input) => RoleOutput(
        fragments: [
          AppEntryRole.readmeSections.entry(
            CiRole.readmeHeading,
            _readmeSection(
              ciRole.pipelineIn(input),
              hasEnv: input.has(envRole),
            ),
          ),
        ],
      );
}
