part of '../env.dart';

/// The comment of [EnvRole.dotEnvFile] in the `.gitignore` of the app.
const _gitignoreComment =
    'The values of the app, which each developer fills in from .env.example';

/// The note of the env role in the guide for coding agents, whichever
/// module provides the role: how code reads a value, that no secret goes
/// into the file of the values, what a new key needs, and that a release
/// build of an app with keys stops without the values. How a provider gives
/// `AppEnv` the getter of a new key, and which arguments give a build the
/// values, is for its own note.
const _agentNote = '''
- Read a value of `${EnvRole.dotEnvFile}` only through a static getter of `$_appEnv` in `${EnvRole.readerFile}`. The getter is the key in lowerCamelCase: `$_appEnv.myServiceKey` for the key `MY_SERVICE_KEY`. It returns a `String?` that is `null` while the value is empty or missing, so handle `null`. Never read `${EnvRole.dotEnvFile}` or `${EnvRole.exampleFile}` from code.
- Every value ends up in the app, where anyone can read it. Never put a secret into `${EnvRole.dotEnvFile}`, such as the secret key of a server, a password or a private key.
- `${EnvRole.dotEnvFile}` stays out of git. A new key goes into both `${EnvRole.exampleFile}` and `${EnvRole.dotEnvFile}`, in UPPER_SNAKE_CASE with a comment line above it, and `$_appEnv` gets a getter for it.
- A release build of an app with keys stops with an error unless its command gives the app the values of `${EnvRole.dotEnvFile}`; the note of the provider names the arguments. Never remove or work around the check in `${EnvRole.checkFile}`, which `bootstrap()` calls in its first phase: give the build the arguments. `$_appEnv.$_supplied` tells whether a build has the values.
''';

/// The section of the role in the README of the app, whichever module
/// provides the role: what the two files are for, that a value is no
/// secret and that an empty one counts as missing, that a release build
/// stops without the values, with the [toolArguments] of the app, that the
/// file is not tied to a flavor, the [keys] of the app, each with its getter,
/// its owner and its description, and the run configurations.
String _readmeSection(List<AppEnvKey> keys, List<String> toolArguments) {
  final buffer = StringBuffer('''
`${EnvRole.dotEnvFile}` at the root of the app holds the values you fill in after generating the app, such as the public key of a service. Code reads each value as a static getter of `$_appEnv` in `${EnvRole.readerFile}`. The getter is `null` while the value is empty or missing, so the app builds and starts before you fill anything in.

${_releaseReadme(keys, toolArguments)}

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

/// The paragraph of the section of the role in the README of the app on a
/// release build without the values, which names the [toolArguments] of the
/// app: that it stops with an error in an app with [keys], and in an app
/// without them once `AppEnv.supplied` checks for a key, which it need not do
/// before.
String _releaseReadme(List<AppEnvKey> keys, List<String> toolArguments) {
  final given = toolArguments.isEmpty
      ? 'the command gives the app the values of `${EnvRole.dotEnvFile}`'
      : 'the command has `${toolArguments.map(shellWord).join(' ')}`';
  final stops = '`flutter build` of a release, and an archive in Xcode, stop '
      'with an error unless $given and `${EnvRole.dotEnvFile}` has a line of '
      'a key of the app, also with an empty value';
  const check = '`${EnvRole.checkFile}` holds the check, which `bootstrap()` '
      'calls in its first phase, and `$_appEnv.$_supplied` tells whether a '
      'build has the values.';
  return keys.isEmpty
      ? 'While the app has no key, a release build goes out without the '
          'values: `$_appEnv.$_supplied` is `true`, since nothing can tell '
          'whether a build has them. Once `$_appEnv.$_supplied` checks for a '
          'key of the app, $stops. $check'
      : 'A release build needs `${EnvRole.dotEnvFile}`: $stops. So a build '
          'for a store never goes out by mistake from a command that did not '
          'give it `${EnvRole.dotEnvFile}`. A debug or profile build without '
          'it starts with every getter `null` and says so in the console. '
          '$check';
}

/// How the README of the app names [owner], who gave the app a key: only
/// modules and the templates of roles give the role keys.
String _readmeOwnerOf(ContributionOrigin owner) => switch (owner) {
      ModuleOrigin(:final module) => 'the module `$module`',
      _ => 'the ${(owner as RoleTemplateOrigin).role}',
    };

/// Who answers for [key], which clashes with [earlier], a key before it in
/// the order of [EnvRole.keysIn]: its owner, unless that is the template of a
/// role, whose error stops the run. Lenient mode can leave out a module, which
/// comes before every template in that order.
ContributionOrigin _atFault(AppEnvKey earlier, AppEnvKey key) =>
    key.owner is RoleTemplateOrigin ? earlier.owner : key.owner;

/// The lines of [keys] in [EnvRole.dotEnvFile] and [EnvRole.exampleFile],
/// after the comment at the top of each: for each key, after an empty line,
/// its description as a comment and the key without a value.
String _keyLines(List<AppEnvKey> keys) => [
      for (final key in keys) '\n# ${key.description}\n${key.name}=',
    ].join('\n');

/// The import of [EnvRole.checkFile], by its path below `lib/`.
const _checkFileUri = 'core/env/env_check.dart';

/// [text] as adjacent string literals of Dart, one on each line, joined by a
/// line break and [indent]: each piece of the text but the last ends with
/// the spaces after its last word, and each literal has at most [width]
/// characters, but one whose word alone is longer.
String _literalLines(
  String text, {
  required int width,
  required String indent,
}) {
  final pieces = <String>[];
  var piece = '';
  // Each word with the spaces after it, so that a run of spaces stays whole
  // in one piece.
  for (final word in text.split(_afterSpaces)) {
    final longer = '$piece$word';
    // The literal of the piece and the space that it ends with, if a word
    // follows.
    final ended = longer.endsWith(' ') ? longer : '$longer ';
    if (piece.isEmpty || SmfNames.dartString(ended).length <= width) {
      piece = longer;
    } else {
      pieces.add(piece);
      piece = word;
    }
  }
  return [...pieces, piece].map(SmfNames.dartString).join('\n$indent');
}

/// The places in a text after a run of spaces and before the next word.
final _afterSpaces = RegExp('(?<= )(?=[^ ])');

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
        const SocketContribution.code(
          AppEntryRole.bootstrapEarly,
          Fragment(
            'checkEnvValues(debugPrint);',
            imports: [
              ImportRef('package:flutter/foundation.dart'),
              ImportRef.app(_checkFileUri),
            ],
          ),
        ),
      ];

  /// Checks what the module rule `env.keys` cannot see from one module: the
  /// keys of the templates of roles, which that rule does not read, tool
  /// arguments from such a template, which only a provider gives, and the
  /// keys of two owners with one name or one getter.
  @override
  List<SmfIssue> validate(RoleHookInput<EnvData> input) {
    final issues = <SmfIssue>[];
    final ofTemplates = <RoleTemplateOrigin, List<EnvKey>>{};
    for (final data in input.data) {
      // Every data that a hook gets has an origin.
      if (data.origin case final RoleTemplateOrigin template) {
        switch (data.value) {
          case final EnvKey key:
            (ofTemplates[template] ??= []).add(key);
          case EnvToolArguments():
            issues.add(
              SmfIssue(
                'The template of the ${template.role} gives the $envRole tool '
                'arguments, which only a provider of the role gives.',
                origin: template,
              ),
            );
        }
      }
    }
    for (final MapEntry(key: template, value: keys) in ofTemplates.entries) {
      for (final problem in _keyProblems(keys, template.role.id)) {
        issues.add(SmfIssue(problem, origin: template));
      }
    }

    // A key starts with the id of its owner, but the id of one owner can
    // start another, as `shop` starts `shop_cart`, and keys whose words are
    // cut differently can have one getter.
    final byName = <String, AppEnvKey>{};
    final byGetter = <String, AppEnvKey>{};
    for (final key in envRole.keysIn(input)) {
      final named = byName.putIfAbsent(key.name, () => key);
      final other = byGetter.putIfAbsent(key.getter, () => key);
      if (named.owner != key.owner) {
        issues.add(
          SmfIssue(
            'Both ${_named(named.owner)} and ${_named(key.owner)} give the '
            '$envRole the key ${key.name}.',
            hint: 'Rename one of the keys.',
            origin: _atFault(named, key),
          ),
        );
      } else if (other.owner != key.owner) {
        issues.add(
          SmfIssue(
            'The $other and the $key would both be read as '
            '$_appEnv.${key.getter}.',
            hint: 'Rename one of the keys.',
            origin: _atFault(other, key),
          ),
        );
      }
    }
    return issues;
  }

  /// The lines of the keys in the files of the template, the texts of
  /// [EnvRole.checkFile] with the tool arguments of the provider, the section
  /// of the role in the README of the app, and the run configurations of the
  /// IDEs.
  @override
  RoleOutput render(RoleHookInput<EnvData> input) {
    final keys = envRole.keysIn(input);
    final toolArguments = envRole.toolArgumentsIn(input);
    return RoleOutput(
      vars: {
        'env_keys': Fragment(_keyLines(keys)),
        // The first line of each follows the code of the template, which
        // has the indent of the others as `dart format` writes them.
        'env_release_error': Fragment(
          _literalLines(
            EnvRole.releaseErrorOf(toolArguments),
            width: 66,
            indent: ' ' * 14,
          ),
        ),
        'env_no_values_message': Fragment(
          _literalLines(
            EnvRole.noValuesMessageOf(toolArguments),
            width: 75,
            indent: ' ' * 4,
          ),
        ),
      },
      fragments: [
        AppEntryRole.readmeSections.entry(
          EnvRole.readmeHeading,
          _readmeSection(keys, toolArguments),
        ),
      ],
      files: _runConfigurationsOf(input.context.appName, toolArguments),
    );
  }
}
