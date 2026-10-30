part of '../env.dart';

/// The comment of [EnvRole.dotEnvFile] in the `.gitignore` of the app.
const _gitignoreComment =
    'The values of the app, which each developer fills in from .env.example';

/// The note of the env role in the guide for coding agents, whichever
/// module provides the role: how code reads a value, that no secret goes
/// into the file of the values, and what a new key needs. How a provider
/// gives `AppEnv` the getter of a new key is for its own note.
const _agentNote = '''
- Read a value of `${EnvRole.dotEnvFile}` only through a static getter of `$_appEnv` in `${EnvRole.readerFile}`. The getter is the key in lowerCamelCase: `$_appEnv.myServiceKey` for the key `MY_SERVICE_KEY`. It returns a `String?` that is `null` while the value is empty or missing, so handle `null`. Never read `${EnvRole.dotEnvFile}` or `${EnvRole.exampleFile}` from code.
- Every value ends up in the app, where anyone can read it. Never put a secret into `${EnvRole.dotEnvFile}`, such as the secret key of a server, a password or a private key.
- `${EnvRole.dotEnvFile}` stays out of git. A new key goes into both `${EnvRole.exampleFile}` and `${EnvRole.dotEnvFile}`, in UPPER_SNAKE_CASE with a comment line above it, and `$_appEnv` gets a getter for it.
''';

/// The section of the role in the README of the app, whichever module
/// provides the role: what the two files are for, that a value is no
/// secret and that an empty one counts as missing, that the file is not tied
/// to a flavor, the [keys] of the app, each with its getter, its owner and
/// its description, and the run configurations.
String _readmeSection(List<AppEnvKey> keys) {
  final buffer = StringBuffer('''
`${EnvRole.dotEnvFile}` at the root of the app holds the values you fill in after generating the app, such as the public key of a service. Code reads each value as a static getter of `$_appEnv` in `${EnvRole.readerFile}`. The getter is `null` while the value is empty or missing, so the app builds and starts before you fill anything in.

`.gitignore` lists `${EnvRole.dotEnvFile}`, so it stays out of git. `${EnvRole.exampleFile}` is in git and has the same keys without values: after a clone, run `cp ${EnvRole.exampleFile} ${EnvRole.dotEnvFile}` and fill in `${EnvRole.dotEnvFile}`. Every value ends up in the app, where anyone can read it, so never put a secret there, such as the secret key of a server, a password or a private key.

`${EnvRole.dotEnvFile}` is not tied to a flavor: a build of any flavor takes what `${EnvRole.dotEnvFile}` has when its command runs. Keep one file and change its values by hand, or have CI write the file for its job.

''');
  if (keys.isEmpty) {
    buffer.writeln('No module of the app reads a value yet.');
  } else {
    buffer.writeln('The keys of the app:\n');
    for (final key in keys) {
      buffer.writeln(
        '- `${key.name}`, read as `$_appEnv.${key.getter}`, from '
        '${_readmeOwnerOf(key.owner)}: ${key.description}',
      );
    }
  }
  buffer.write(
    '\nTo add a key of your own, put it into `${EnvRole.exampleFile}` and '
    '`${EnvRole.dotEnvFile}` and give `$_appEnv` a getter for it. The '
    'section of the module that provides the values tells how they get into '
    'the app.\n\n$_runConfigurationsReadme',
  );
  return '$buffer';
}

/// How the README of the app names [owner], the module that gave the app a
/// key: an app that the pipeline renders has no key of another owner.
String _readmeOwnerOf(ContributionOrigin owner) =>
    'the module `${(owner as ModuleOrigin).module}`';

/// The lines of [keys] in [EnvRole.dotEnvFile] and [EnvRole.exampleFile],
/// after the comment at the top of each: for each key, after an empty line,
/// its description as a comment and the key without a value.
String _keyLines(List<AppEnvKey> keys) => [
      for (final key in keys) '\n# ${key.description}\n${key.name}=',
    ].join('\n');

/// The template of the [EnvRole]: the file of the values and the file of
/// the keys, which the `.gitignore` of the app tells apart, the run
/// configurations of the IDEs, the section of the role in the README of the
/// app, its note for coding agents, and the checks of the data of the role
/// that the module rules cannot make.
final class _EnvTemplate extends RoleTemplate<EnvData> {
  const _EnvTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(envRoleBundle),
        AppEntryRole.gitignore.entry(EnvRole.dotEnvFile, _gitignoreComment),
        AppEntryRole.agentSections.entry(
          envRole.description,
          AgentNote.ofRole('$_agentNote$_runConfigurationsNote'),
        ),
      ];

  /// Checks what the module rule `env.keys` cannot see from one module:
  /// keys and tool arguments from the templates of roles, which only modules
  /// and the provider give, and the keys of two modules with one name or one
  /// getter.
  @override
  List<SmfIssue> validate(RoleHookInput<EnvData> input) {
    final issues = <SmfIssue>[];
    for (final data in input.data) {
      // Every data that a hook gets has an origin.
      if (data.origin case final RoleTemplateOrigin template) {
        issues.add(
          switch (data.value) {
            EnvKey(:final name) => SmfIssue(
                'The template of the ${template.role} gives the $envRole the '
                'key $name, but only modules give the role keys.',
                hint: 'Give the key from the module whose code reads the '
                    'value.',
                origin: template,
              ),
            EnvToolArguments() => SmfIssue(
                'The template of the ${template.role} gives the $envRole tool '
                'arguments, which only a provider of the role gives.',
                origin: template,
              ),
          },
        );
      }
    }

    // A key starts with the id of its module, but the id of one module can
    // start another, as `shop` starts `shop_cart`, and keys whose words are
    // cut differently can have one getter.
    final byName = <String, AppEnvKey>{};
    final byGetter = <String, AppEnvKey>{};
    for (final key in envRole.keysIn(input)) {
      if (key.owner is RoleTemplateOrigin) continue;
      final named = byName.putIfAbsent(key.name, () => key);
      final other = byGetter.putIfAbsent(key.getter, () => key);
      if (named.owner != key.owner) {
        issues.add(
          SmfIssue(
            'Both ${_named(named.owner)} and ${_named(key.owner)} give the '
            '$envRole the key ${key.name}.',
            hint: 'Rename one of the keys.',
            origin: key.owner,
          ),
        );
      } else if (other.owner != key.owner) {
        issues.add(
          SmfIssue(
            'The $other and the $key would both be read as '
            '$_appEnv.${key.getter}.',
            hint: 'Rename one of the keys.',
            origin: key.owner,
          ),
        );
      }
    }
    return issues;
  }

  /// The lines of the keys in the files of the template, the section of the
  /// role in the README of the app, and the run configurations of the IDEs.
  @override
  RoleOutput render(RoleHookInput<EnvData> input) {
    final keys = envRole.keysIn(input);
    return RoleOutput(
      vars: {'env_keys': Fragment(_keyLines(keys))},
      fragments: [
        AppEntryRole.readmeSections.entry(
          EnvRole.readmeHeading,
          _readmeSection(keys),
        ),
      ],
      files: _runConfigurationsOf(
        input.context.appName,
        envRole.toolArgumentsIn(input),
      ),
    );
  }
}
