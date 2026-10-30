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

/// How a message of the rule starts.
final _filesHave = 'The files of the provider of the $ciRole have';

/// [command] as it has to stand in a line, with nothing of another command
/// after it: so `flutter test` does not pass for
/// `flutter test --dart-define-from-file=.env`, or the other way round.
RegExp _commandAtEnd(String command) =>
    RegExp('$_boundary${RegExp.escape(command)}$_closes');

/// [text] in a line, followed by [end], with anything in place of the name of
/// the environment, in the first group: a name, or what stands for one in the
/// format of a provider, whatever its syntax.
RegExp _perEnvironment(CiPerEnvironment text, String end) => RegExp(
      '$_boundary${RegExp.escape(text._before)}(.+?)'
      '${RegExp.escape(text._after)}$end',
    );

/// What stands in place of the environment wherever [pattern] of
/// [_perEnvironment] matches in [lines], without the quotes around it.
List<String> _standInsIn(Iterable<String> lines, RegExp pattern) => [
      for (final line in lines)
        for (final match in pattern.allMatches(line))
          match[1]!.replaceAll(RegExp(r'''^["']|["']$'''), ''),
    ];

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
        '$_filesHave $what.',
        hint: 'Write everything that CiRole.pipelineIn() gives into the files '
            'of the provider, outside comments.',
        origin: origin,
      );

  final pipeline = ciRole.pipelineIn(input.roleInput);
  final build = pipeline.build;

  // A stand-in that is no environment is a reference of the host, which a job
  // fills in with the choice of the developer. Otherwise the file has to name
  // every environment, as a format with a block for each does: with fewer, a
  // choice of another environment would not build what it asks for.
  List<SmfIssue> placeProblems(
    RegExp pattern, {
    required String what,
    required String missing,
  }) {
    final standIns = _standInsIn(lines, pattern);
    if (standIns.isEmpty) return [problem(missing)];
    final environments = build.environments;
    if (!standIns.every(environments.contains)) return const [];
    final left = [
      for (final environment in environments)
        if (!standIns.contains(environment)) environment,
    ];
    if (left.isEmpty) return const [];
    final written = [
      for (final environment in environments)
        if (standIns.contains(environment)) environment,
    ];
    return [
      SmfIssue(
        '$_filesHave $what only for ${written.join(', ')}, and none for '
        '${left.join(', ')}, so a choice of one of those would not give what '
        'it asks for.',
        hint: 'Write what stands for the choice of the developer on the host '
            'in place of the environment, or one for each environment.',
        origin: origin,
      ),
    ];
  }

  return [
    for (final command in [...pipeline.checks, ...build.prepare])
      if (!hasLine(_commandAtEnd(command.command)))
        problem('no line that ends with `${command.command}`'),
    ...placeProblems(
      _perEnvironment(build.command, _closes),
      what: 'the command of the build',
      missing: 'no line that ends with the command of the build, '
          '`${build.command.of('<environment>')}`',
    ),
    // A format may have the path inside a list on one line, so the path need
    // not end the line. A character of a path after it would make it another
    // file.
    ...placeProblems(
      _perEnvironment(build.artifact, r'(?![\w./-])'),
      what: 'the file of the build',
      missing: 'no line with the file of the build, '
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
