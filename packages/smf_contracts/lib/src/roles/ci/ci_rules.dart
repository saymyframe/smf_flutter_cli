part of '../ci.dart';

/// Whether [line] of a file of the provider is a comment: of a format with
/// `#` or with `//`.
bool _isComment(String line) {
  final text = line.trimLeft();
  return text.startsWith('#') || text.startsWith('//');
}

/// What may stand before a command or a file in a line: the start of the
/// line, white space, a quote or a bracket.
const _boundary = r'''(?:^|[\s"'\[(])''';

/// What may stand after a command at the end of a line: a closing quote, a
/// comma and white space.
const _closes = r'''["']?,?\s*$''';

/// [command] as it has to stand in a line, with nothing of another command
/// after it: so `flutter test` does not pass for
/// `flutter test --dart-define-from-file=.env`, or the other way round.
RegExp _commandAtEnd(String command) =>
    RegExp('$_boundary${RegExp.escape(command)}$_closes');

/// [text] in a line, followed by [end], with anything in place of the name of
/// the environment: a name, or what stands for one in the format of a
/// provider, whatever its syntax.
RegExp _perEnvironment(CiPerEnvironment text, String end) => RegExp(
      '$_boundary${RegExp.escape(text._before)}.+?'
      '${RegExp.escape(text._after)}$end',
    );

/// The problems of the files of the provider of the role against the pipeline
/// of the app; see [CiRole.structuralRules].
List<SmfIssue> _checkPipelineRendered(StructuralRuleInput<NoDsl> input) {
  final provider = input.modules
      .where((module) => module.provides.contains(ciRole))
      .firstOrNull
      ?.id;
  if (provider == null) return const [];
  final origin = ModuleOrigin(provider);

  final lines = [
    for (final MapEntry(key: path, value: text) in input.texts.entries)
      if (!path.endsWith('.dart') && _isOwnedBy(input.owners[path], provider))
        ...text.split('\n').where((line) => !_isComment(line)),
  ];
  if (lines.isEmpty) {
    return [
      SmfIssue(
        'The provider of the $ciRole generates no file that CI could read.',
        hint: 'Write what CiRole.pipelineIn() gives in the format of the '
            'host, in a file of RoleOutput.files of the render hook of the '
            'provider.',
        origin: origin,
      ),
    ];
  }

  bool hasLine(RegExp pattern) => lines.any(pattern.hasMatch);
  bool hasWord(String word) => hasLine(
        RegExp('(?<![\\w-])${RegExp.escape(word)}(?![\\w-])'),
      );
  SmfIssue problem(String what) => SmfIssue(
        'The files of the provider of the $ciRole have $what.',
        hint: 'Write everything that CiRole.pipelineIn() gives into the files '
            'of the provider, outside comments.',
        origin: origin,
      );

  final pipeline = ciRole.pipelineIn(input.roleInput);
  final build = pipeline.build;
  return [
    for (final command in [...pipeline.checks, ...build.prepare])
      if (!hasLine(_commandAtEnd(command.command)))
        problem('no line that ends with `${command.command}`'),
    if (!hasLine(_perEnvironment(build.command, _closes)))
      problem(
        'no line that ends with the command of the build, '
        '`${build.command.of('<environment>')}`',
      ),
    // A format may have the path inside a list on one line, so the path need
    // not end the line. A character of a path after it would make it another
    // file.
    if (!hasLine(_perEnvironment(build.artifact, r'(?![\w./-])')))
      problem(
        'no line with the file of the build, '
        '`${build.artifact.of('<environment>')}`',
      ),
    for (final environment in build.environments)
      if (!hasWord(environment)) problem('no environment `$environment`'),
    for (final key in build.keys)
      if (!hasWord(key)) problem('no key `$key`'),
  ];
}

/// Whether [owner], the owner of a file, is the module [provider].
bool _isOwnedBy(ContributionOrigin? owner, ModuleId provider) =>
    owner is ModuleOrigin && owner.module == provider;
