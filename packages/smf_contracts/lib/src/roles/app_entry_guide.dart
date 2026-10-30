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
  AgentNote(String text) : this._(const [], [text.trim()]);

  /// Creates the note [text] of a role: what the role guarantees,
  /// whichever module provides it. Only the template of a role contributes
  /// such a note.
  AgentNote.ofRole(String text) : this._([text.trim()], const []);

  const AgentNote._(this._ofRoles, this._ofModules);

  /// The texts of the notes of roles, each without the spaces and empty
  /// lines around it, in the order they were contributed.
  final List<String> _ofRoles;

  /// The texts of the other notes, each without the spaces and empty lines
  /// around it, in the order they were contributed.
  final List<String> _ofModules;

  /// The Markdown of the note, without the spaces and empty lines around
  /// it: two notes that differ only there are equal.
  ///
  /// The notes of a section united into one have the notes of the roles
  /// first, then the others, in the order they were contributed, with an
  /// empty line between two notes.
  String get text => [..._ofRoles, ..._ofModules].join('\n\n');

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
/// that a heading is one line, that a note is text that stays in its
/// section, and that a note of a role comes from the template of a role.
final class _AgentNotePolicy extends MergePolicy<AgentNote> {
  const _AgentNotePolicy();

  @override
  String? problemFrom(
    ContributionOrigin? origin,
    String key,
    AgentNote value,
  ) {
    if (value.isOfRole && origin is ModuleOrigin) {
      return 'The module ${origin.module} contributes a note of a role to '
          'the section "$key" of the guide for coding agents. Only the '
          'template of a role says what the role guarantees; a module '
          'contributes AgentNote(text).';
    }
    return problemWith(key, value);
  }

  @override
  String? problemWith(String key, AgentNote value) {
    if (key.isEmpty ||
        key != key.trim() ||
        key.contains('\n') ||
        key.contains('\r')) {
      return 'The heading "$key" of a section of the guide for coding agents '
          'is not one line of text without spaces around it.';
    }
    // As it renders: before a line break.
    if (Fragment.hasStrippedBackslash('$key\n')) {
      return 'The heading "$key" of a section of the guide for coding agents '
          'has a backslash at its end or before a non-ASCII character, '
          'which mason removes.';
    }
    final text = value.text;
    if (text.isEmpty) {
      return 'A note of the section "$key" of the guide for coding agents '
          'has no text.';
    }
    if (Fragment.hasStrippedBackslash('$text\n')) {
      return 'A note of the section "$key" of the guide for coding agents '
          'has a backslash before a line break or a non-ASCII character, '
          'which mason removes. For a line break in Markdown, end the line '
          'with two spaces, and write a command on one line rather than '
          'continue it with a backslash.';
    }
    final (:lines, :open) = _outsideFences(text);
    if (lines.any(_startsSection.hasMatch)) {
      return 'A note of the section "$key" of the guide for coding agents '
          'has a line that starts with "# " or "## " outside a fenced code '
          'block, which starts a title or another section; a note stays in '
          'its section.';
    }
    for (var i = 1; i < lines.length; i++) {
      if (_underlinesHeading.hasMatch(lines[i]) &&
          lines[i - 1].trim().isNotEmpty) {
        return 'A note of the section "$key" of the guide for coding agents '
            'has a line of "=" or "-" under a line of text outside a fenced '
            'code block, which makes that line a title or the heading of '
            'another section; a note stays in its section.';
      }
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

/// A line of Markdown that makes the line of text above it a title or the
/// heading of a section: nothing but `=`, or nothing but `-`.
final RegExp _underlinesHeading = RegExp(r'^ {0,3}(?:=+|-+)[ \t]*$');

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

/// The widget that the template of the [AppEntryRole] puts around the
/// content of every route ([AppEntryRole.appBuilder]): `StatusBarIcons` of
/// [AppEntryRole.statusBarIconsFile], which the brick of the template has
/// with a widget test. It tells the system which icons of the status bar
/// suit the theme of the app, dark ones on a light theme and light ones on
/// a dark theme.
///
/// It reads the theme from a context of its own, below the root
/// `MaterialApp`, so it needs no name from the `builder` of the provider.
/// It says nothing of the navigation bar of the system, which stays as the
/// platform has it. A screen with an `AppBar` gets the icons that suit its
/// bar, since the bar tells them for the top of the screen itself.
const _statusBarIcons = Fragment.wrap(
  'StatusBarIcons(child: ',
  ')',
  imports: [ImportRef.app('core/app/status_bar_icons.dart')],
);

/// The template of the [AppEntryRole], for what an app has whichever module
/// provides the role: the guide for coding agents, with the note of the
/// role itself, the icons of the status bar that suit the theme of the
/// app, on every screen, with a widget test of them, the section of the
/// README on the flavors of the app, and in an app with steps by hand the
/// section of the README that lists them.
final class _AppEntryTemplate extends RoleTemplate<NoDsl> {
  const _AppEntryTemplate();

  @override
  List<Contribution> contribute(ModuleContext context) => [
        BrickContribution(appEntryRoleBundle),
        AppEntryRole.agentSections.entry(
          appEntryRole.description,
          AgentNote.ofRole(_agentNote),
        ),
        const SocketContribution.wrap(AppEntryRole.appBuilder, _statusBarIcons),
        // What the widget of the icons of the status bar and its test import.
        const PubspecContribution.sdk('flutter'),
        const PubspecContribution.sdk('flutter_test', dev: true),
        AppEntryRole.readmeSections.entry(
          AppEntryRole.flavorsHeading,
          _flavorsSection(context.appIdentity),
        ),
      ];

  /// The section [AppEntryRole.setupHeading] of the README, with the note
  /// of the role about it in the guide for coding agents, in an app with
  /// steps by hand; nothing in an app without them.
  @override
  RoleOutput render(RoleHookInput<NoDsl> input) {
    final setup = input.manualSetup;
    if (setup.steps.isEmpty) return const RoleOutput();
    return RoleOutput(
      fragments: [
        AppEntryRole.readmeSections.entry(
          AppEntryRole.setupHeading,
          _setupSection(setup),
        ),
        AppEntryRole.agentSections.entry(
          appEntryRole.description,
          AgentNote.ofRole(_setupAgentNote),
        ),
      ],
    );
  }
}

/// The section [AppEntryRole.setupHeading] of the README of an app with
/// the steps of [setup]: that no command can do them, the link to their
/// guide when [setup] has one, the titles of the steps as they are, in a
/// numbered list in their order, and that a step may repeat for a flavor.
String _setupSection(ManualSetup setup) {
  final link = setup.link;
  const intro = 'Once any commands of the sections below have run, the setup '
      'still needs these steps, which no command can do';
  return [
    if (link == null)
      '$intro:'
    else
      '$intro. [The guide]($link) shows each one click by click:',
    '',
    for (final (index, step) in setup.steps.indexed)
      '${index + 1}. ${step.title}',
    '',
    _repeatStepOfFlavors,
  ].join('\n');
}

/// What the section of the steps by hand says below the list of the steps.
const _repeatStepOfFlavors = 'Repeat a step for each flavor that needs it: a '
    'service knows each id as an app of its own.';

/// The note of the app entry role in the guide for coding agents of an app
/// with steps by hand: they are for the developer of the app, whom an agent
/// points to them.
const String _setupAgentNote = '''
- The section "${AppEntryRole.setupHeading}" of the README lists the steps of the setup that no command can do, such as a step in the web console of a service that the app uses. Only the developer of the app does them: when a task depends on one of them, point the developer to that section, and do not try to do the step yourself.
''';

/// The note of the app entry role in the guide for coding agents: what the
/// role guarantees in every app, whichever module provides it. What depends
/// on the files of the provider, such as the commands that check a change,
/// which need its tests, is in the note of the provider.
final String _agentNote = '''
The app is plain Flutter code that nothing regenerates. Change it by hand, unless a section below says what writes a file.

- `${AppEntryRole.main.name}()` in `${AppEntryRole.mainFile}` initializes the binding, awaits `${AppEntryRole.bootstrap.name}()` and calls `runApp()`, in this order. Start-up code goes into `${AppEntryRole.bootstrap.name}()`.
- `${AppEntryRole.bootstrap.name}()` in `${AppEntryRole.bootstrapFile}` runs before the first frame, in four phases: what must come before anything else, then the platform services, then the services of the app, then what needs them. Put a new statement into its phase, and import neither `package:flutter/material.dart` nor `package:flutter/cupertino.dart` there.
- Put code that features share into `lib/core/<concern>/`, one directory for each concern. Put a feature, with its screens and their state, into `lib/features/<feature>/`.
- The root of the app asks the system for the icons of the status bar that suit the theme, around every screen, with `StatusBarIcons` of `${AppEntryRole.statusBarIconsFile}`: dark icons on a light theme, light ones on a dark theme. A screen without an app bar needs no `AnnotatedRegion` for them. Add one only to a screen whose top has another brightness than the theme, such as a picture behind the status bar.
- The app has the flavors `${_devFlavor.name}`, `${_stagingFlavor.name}` and `${_prodFlavor.name}`. A `flutter` command without `--flavor` builds `${AppEntryRole.defaultFlavor.name}`, in release mode too, so a build for a store takes `--flavor ${AppEntryRole.releaseFlavor.name}`. Code reads the flavor from `appFlavor` of `package:flutter/services.dart`. The app has one entry: add no `main_<flavor>.dart`.
''';

/// The characters of a path of the app: those of the names of its files and
/// directories, and slashes. A pattern, with `<…>` or `*`, a command and a
/// `package:` URI have others.
final RegExp _pathCharacters = RegExp(r'^[A-Za-z0-9_.\-/]+$');

/// A line of the guide that starts a section, as [_renderAgentSections]
/// writes it.
final RegExp _sectionHeading = RegExp(r'^## (.+)$');

/// A line of Markdown that starts an item of a list, which a code span of
/// the item before it does not reach into.
final RegExp _startsListItem = RegExp(r'^\s*(?:[-*+]|\d+[.)])\s');

/// The top-level directories of a Flutter project. A path below one of them
/// is a path of the app, whether the app has that directory or not.
const _flutterDirectories = {
  'lib',
  'test',
  'integration_test',
  'test_driver',
  'assets',
  'android',
  'ios',
  'web',
  'linux',
  'macos',
  'windows',
};

/// The problems of the paths that the guide for coding agents of the app
/// names in inline code, outside its fenced code blocks:
/// - a path below a top-level directory of a Flutter project, such as
///   `lib/` or `android/`, or below another top-level directory of the app,
///   that is neither a file nor a directory of the app;
/// - a path to a Dart file that the app does not have, whatever it starts
///   with, such as `core/di/dependencies.dart`;
/// - the name of a Dart file without a path, such as `main.dart`.
///
/// Anything else in inline code is not read as a path of the app: a
/// pattern, such as `lib/features/<feature>/`, a route, such as `/home`, a
/// command, a name of the code, a file at the root of the app, which
/// nothing tells from a name such as `Icons.home`, or a path below a
/// directory that is neither of a Flutter project nor of the app, such as
/// `build/`.
List<SmfIssue> _checkAgentGuidePaths(StructuralRuleInput<NoDsl> input) {
  const guide = AppEntryRole.agentsFile;
  final text = input.texts[guide];
  if (text == null) return const [];

  final paths = _pathsOf(input.owners.keys.toSet());
  final issues = <SmfIssue>[];
  final reported = <(String?, String)>{};
  for (final (:heading, :code) in _codeSpansOf(text)) {
    final found = _pathProblemOf(code, paths);
    if (found == null || !reported.add((heading, code))) continue;
    final where =
        heading == null ? 'The introduction' : 'The section "$heading"';
    issues.add(
      SmfIssue(
        '$where of $guide ${found.problem}',
        hint: found.hint,
        origin: input.owners[guide],
        path: guide,
      ),
    );
  }
  return issues;
}

/// The paths of an app: its `files`, the `directories` that have its
/// files, and the `roots`, the top-level directories below which a path is
/// one of the app: those of its files and those of a Flutter project.
typedef _AppPaths = ({
  Set<String> files,
  Set<String> directories,
  Set<String> roots,
});

/// The paths of the app whose files are [files], each by its path from the
/// root of the app.
_AppPaths _pathsOf(Set<String> files) {
  final directories = <String>{};
  final roots = {..._flutterDirectories};
  for (final file in files) {
    final segments = file.split('/');
    for (var depth = 1; depth < segments.length; depth++) {
      directories.add(segments.sublist(0, depth).join('/'));
    }
    if (segments.length > 1) roots.add(segments.first);
  }
  return (files: files, directories: directories, roots: roots);
}

/// A problem of a path that the guide for coding agents names: the end of
/// the sentence that reports it, after the section of the guide, and the
/// hint for it.
typedef _PathProblem = ({String problem, String hint});

/// The problem of [code], a code span of the guide for coding agents of
/// the app with [paths], or `null` if [code] is no path of the app or names
/// one that the app has; see [_checkAgentGuidePaths].
_PathProblem? _pathProblemOf(String code, _AppPaths paths) {
  if (!_pathCharacters.hasMatch(code)) return null;
  if (code.contains('/')) return _missingPathProblemOf(code, paths);
  if (code.endsWith('.dart')) {
    return (
      problem: 'names the Dart file `$code` without its path from the root '
          'of the app.',
      hint: 'Write the path from the root of the app, such as '
          '${AppEntryRole.mainFile}, or, for the files of a kind, a pattern '
          'with *, such as *_test.dart.',
    );
  }
  return null;
}

/// The problem of [code], a path with a slash in a code span of the guide
/// for coding agents of the app with [paths], if the app has neither a file
/// nor a directory at it, or `null`. A path below no top-level directory of
/// the app or of a Flutter project is no path of the app, unless it is the
/// path to a Dart file.
_PathProblem? _missingPathProblemOf(String code, _AppPaths paths) {
  if (!paths.roots.contains(code.split('/').first) && !code.endsWith('.dart')) {
    return null;
  }
  final path = code.endsWith('/') ? code.substring(0, code.length - 1) : code;
  if (paths.files.contains(path) || paths.directories.contains(path)) {
    return null;
  }
  return (
    problem: 'names `$code`, but the app has no such file or directory.',
    hint: 'A note names a file or a directory of the app by its path from '
        'the root of the app. What it tells of a file that only some apps '
        'have is a contribution of its own, with the role of the file in '
        'its when. A file that a later step writes is a pattern, with <…> '
        'or *, or left to the README.',
  );
}

/// The inline code spans of [markdown], the guide for coding agents,
/// outside its fenced code blocks, each with the heading of its section, or
/// `null` before the first section.
List<({String? heading, String code})> _codeSpansOf(String markdown) {
  final spans = <({String? heading, String code})>[];
  String? heading;
  var block = <String>[];
  // A code span does not go beyond its paragraph or its item of a list.
  void endBlock() {
    for (final code in _inlineCodeOf(block.join('\n'))) {
      spans.add((heading: heading, code: code));
    }
    block = [];
  }

  for (final line in [..._outsideFences(markdown).lines, '']) {
    final section = _sectionHeading.firstMatch(line);
    if (section != null) {
      endBlock();
      heading = section[1];
    } else if (line.trim().isEmpty) {
      endBlock();
    } else {
      if (_startsListItem.hasMatch(line)) endBlock();
      block.add(line);
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
