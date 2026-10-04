part of 'app_entry.dart';

/// A note in a section of [AppEntryRole.agentSections], the guide for
/// coding agents that work on the app: what the code of the app does not
/// show, as Markdown.
///
/// A module adds its note with [AgentNote.new]. The template of a role adds
/// what holds whichever module provides the role with [AgentNote.ofRole],
/// which its section shows before the notes of the modules.
@immutable
final class AgentNote {
  /// Creates the note [text] of a module, such as what the package of a
  /// provider of a role brings.
  AgentNote(String text) : this._(const [], [text]);

  /// Creates the note [text] of a role: what the role guarantees,
  /// whichever module provides it.
  AgentNote.ofRole(String text) : this._([text], const []);

  const AgentNote._(this._ofRoles, this._ofModules);

  /// The texts of the notes of roles, in the order they were contributed.
  final List<String> _ofRoles;

  /// The texts of the other notes, in the order they were contributed.
  final List<String> _ofModules;

  /// The Markdown of the note, without empty lines around it.
  ///
  /// The notes of a section united into one have the notes of the roles
  /// first, then the others, in the order they were contributed, with an
  /// empty line between two notes.
  String get text => [
        for (final note in [..._ofRoles, ..._ofModules]) note.trim(),
      ].join('\n\n');

  /// Whether this is what a role guarantees, whichever module provides it:
  /// a note created with [AgentNote.ofRole].
  bool get isOfRole => _ofModules.isEmpty;

  /// This note followed by [other], each of their texts once.
  AgentNote _with(AgentNote other) => AgentNote._(
        List.unmodifiable({..._ofRoles, ...other._ofRoles}),
        List.unmodifiable({..._ofModules, ...other._ofModules}),
      );

  @override
  bool operator ==(Object other) =>
      other is AgentNote &&
      _sameTexts(other._ofRoles, _ofRoles) &&
      _sameTexts(other._ofModules, _ofModules);

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(_ofRoles), Object.hashAll(_ofModules));

  static bool _sameTexts(List<String> a, List<String> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }

  @override
  String toString() => text;
}

/// Unites the notes of a section of the guide for coding agents, and checks
/// that a heading is one line and that a note is text that stays in its
/// section.
final class _AgentNotePolicy extends MergePolicy<AgentNote> {
  const _AgentNotePolicy();

  @override
  String? problemWith(String key, AgentNote value) {
    if (key.isEmpty ||
        key != key.trim() ||
        key.contains('\n') ||
        key.contains('\r')) {
      return 'The heading "$key" of a section of the guide for coding agents '
          'is not one line of text without spaces around it.';
    }
    final text = value.text;
    if (text.isEmpty) {
      return 'A note of the section "$key" of the guide for coding agents '
          'has no text.';
    }
    // As they render: each before a line break.
    if (Fragment.hasStrippedBackslash('$key\n') ||
        Fragment.hasStrippedBackslash('$text\n')) {
      return 'A note of the section "$key" of the guide for coding agents '
          'has a backslash before a line break or a non-ASCII character, '
          'which mason removes; for a line break in Markdown, end the line '
          'with two spaces instead.';
    }
    final (:lines, :open) = _outsideFences(text);
    if (lines.any(_startsSection.hasMatch)) {
      return 'A note of the section "$key" of the guide for coding agents '
          'has a line that starts with "# " or "## " outside a fenced code '
          'block, which starts a title or another section; a note stays in '
          'its section.';
    }
    if (open) {
      return 'A note of the section "$key" of the guide for coding agents '
          'does not close a fenced code block, which would take in the '
          'sections after it.';
    }
    return null;
  }

  @override
  AgentNote merge(String key, AgentNote existing, AgentNote incoming) =>
      existing._with(incoming);
}

/// A line of Markdown that starts a title or a section: `# ` or `## `.
final RegExp _startsSection = RegExp(r'^ {0,3}#{1,2}(?:[ \t]|$)');

/// A line of Markdown that opens a fenced code block: three or more
/// backticks or tildes; a line with a backtick after its opening backticks
/// is text with an inline code span.
final RegExp _opensFence = RegExp(r'^ {0,3}(`{3,}(?=[^`]*$)|~{3,})');

/// The lines of [markdown] outside its fenced code blocks, with an empty
/// line in place of each block, and whether [markdown] ends in a block that
/// it does not close.
({List<String> lines, bool open}) _outsideFences(String markdown) {
  final lines = <String>[];
  // What closes the block that the line is in.
  RegExp? closing;
  for (final line in const LineSplitter().convert(markdown)) {
    if (closing != null) {
      if (closing.hasMatch(line)) closing = null;
      continue;
    }
    final fence = _opensFence.firstMatch(line)?[1];
    lines.add(fence == null ? line : '');
    // As many of the characters of the opening fence, or more, alone on
    // their line.
    if (fence != null) {
      closing = RegExp(
        '^ {0,3}${RegExp.escape(fence[0])}{${fence.length},}[ \\t]*\$',
      );
    }
  }
  return (lines: lines, open: closing != null);
}

/// Each section under its heading, after an empty line: the section of the
/// app entry first, then the others in the order of their headings.
String _renderAgentSections(List<MapEntry<String, AgentNote>> entries) {
  int rank(String heading) => heading == appEntryRole.description ? 0 : 1;
  final sections = [...entries]..sort((a, b) {
      final byRank = rank(a.key).compareTo(rank(b.key));
      return byRank != 0 ? byRank : a.key.compareTo(b.key);
    });
  return sections
      .map((section) => '\n## ${section.key}\n\n${section.value.text}')
      .join('\n');
}

/// The template of the [AppEntryRole]: the guide for coding agents, which
/// an app has whichever module provides the role, with the note of the role
/// itself.
final class _AppEntryTemplate extends RoleTemplate<NoDsl> {
  const _AppEntryTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(appEntryRoleBundle),
        AppEntryRole.agentSections.entry(
          appEntryRole.description,
          AgentNote.ofRole(_agentNote),
        ),
      ];
}

/// The note of the app entry role in the guide for coding agents: what
/// holds in every app, whichever module provides the role.
final String _agentNote = '''
The app is plain Flutter code that nothing regenerates: change it by hand, unless a section below says what writes a file. After a change, run:

```bash
dart format lib test
flutter analyze
flutter test
```

Format only `lib/` and `test/`: `dart format .` also formats what Flutter writes into `build/`. The app as generated is formatted, and `flutter analyze` finds no issue in it.

- `${AppEntryRole.mainFile}`: `${AppEntryRole.main.name}()` initializes the binding, awaits `${AppEntryRole.bootstrap.name}()` and calls `runApp()`, in this order, and does nothing else. Start-up code goes into `${AppEntryRole.bootstrap.name}()`.
- `${AppEntryRole.bootstrapFile}`: `${AppEntryRole.bootstrap.name}()` runs before the first frame, in four phases: what must come before anything else, then the platform services, then the registration of the services of the app, then what needs these services. Put a new statement into its phase, and import neither `package:flutter/material.dart` nor `package:flutter/cupertino.dart` there.
- Put code that features share into `lib/core/<concern>/`, a directory for each concern, and a feature, with its screens and their state, into `lib/features/<feature>/`.
''';

/// The characters of a path of the app: those of the names of its files and
/// directories, and slashes. A pattern, with `<…>` or `*`, a command and a
/// `package:` URI have others.
final RegExp _pathCharacters = RegExp(r'^[A-Za-z0-9_.\-/]+$');

/// A line of the guide that starts a section, as [_renderAgentSections]
/// writes it.
final RegExp _sectionHeading = RegExp(r'^## (.+)$');

/// The problems of the paths that the guide for coding agents of the app
/// names in inline code, outside its fenced code blocks:
/// - a path below a top-level directory of the app, such as `lib/`, that is
///   neither a file nor a directory of the app;
/// - a Dart file that is not named by its path from the root of the app,
///   such as `core/di/dependencies.dart` or `main.dart`.
///
/// Anything else in inline code is not a path of the app: a pattern, such
/// as `lib/features/<feature>/`, a route, such as `/home`, a command, a
/// name of the code, a file at the root of the app, which nothing tells
/// from a name such as `Icons.home`, or a path below a directory that the
/// app is generated without, such as `build/`.
List<SmfIssue> _checkAgentGuidePaths(StructuralRuleInput<NoDsl> input) {
  const guide = AppEntryRole.agentsFile;
  final text = input.texts[guide];
  if (text == null) return const [];

  final files = input.owners.keys.toSet();
  final directories = <String>{};
  final topLevel = <String>{};
  for (final file in files) {
    final segments = file.split('/');
    for (var depth = 1; depth < segments.length; depth++) {
      directories.add(segments.sublist(0, depth).join('/'));
    }
    if (segments.length > 1) topLevel.add(segments.first);
  }

  final issues = <SmfIssue>[];
  final reported = <(String?, String)>{};
  for (final (:heading, :code) in _codeSpansOf(text)) {
    if (!_pathCharacters.hasMatch(code)) continue;
    final String problem;
    final String hint;
    if (code.contains('/') && topLevel.contains(code.split('/').first)) {
      final path =
          code.endsWith('/') ? code.substring(0, code.length - 1) : code;
      if (files.contains(path) || directories.contains(path)) continue;
      problem = 'names `$code`, but the app has no such file or directory.';
      hint = 'A note names a file or a directory of the app by its path from '
          'the root of the app. What it tells of a file that only some apps '
          'have is a contribution of its own, with the role of the file in '
          'its when. A file that a later step writes is a pattern, with <…> '
          'or *, or left to the README.';
    } else if (code.endsWith('.dart')) {
      problem = 'names the Dart file `$code` without its path from the root '
          'of the app.';
      hint = 'Write the path from the root of the app, such as '
          '${AppEntryRole.mainFile}.';
    } else {
      continue;
    }
    if (!reported.add((heading, code))) continue;
    final where =
        heading == null ? 'The introduction' : 'The section "$heading"';
    issues.add(
      SmfIssue(
        '$where of $guide $problem',
        hint: hint,
        origin: input.owners[guide],
        path: guide,
      ),
    );
  }
  return issues;
}

/// The inline code spans of [markdown], the guide for coding agents,
/// outside its fenced code blocks, each with the heading of its section, or
/// `null` before the first section.
List<({String? heading, String code})> _codeSpansOf(String markdown) {
  final spans = <({String? heading, String code})>[];
  String? heading;
  var paragraph = <String>[];
  // A code span does not go beyond its paragraph.
  void endParagraph() {
    for (final code in _inlineCodeOf(paragraph.join('\n'))) {
      spans.add((heading: heading, code: code));
    }
    paragraph = [];
  }

  for (final line in [..._outsideFences(markdown).lines, '']) {
    final section = _sectionHeading.firstMatch(line);
    if (section != null) {
      endParagraph();
      heading = section[1];
    } else if (line.trim().isEmpty) {
      endParagraph();
    } else {
      paragraph.add(line);
    }
  }
  return spans;
}

/// The inline code spans of [text], a paragraph of Markdown: what stands
/// between two runs of as many backticks, without the spaces around it.
List<String> _inlineCodeOf(String text) {
  final runs = RegExp('`+').allMatches(text).toList();
  final spans = <String>[];
  for (var open = 0; open < runs.length; open++) {
    final length = runs[open].end - runs[open].start;
    final close = runs.indexWhere(
      (run) => run.end - run.start == length,
      open + 1,
    );
    // A run that nothing closes is text.
    if (close < 0) continue;
    spans.add(text.substring(runs[open].end, runs[close].start).trim());
    open = close;
  }
  return spans;
}
