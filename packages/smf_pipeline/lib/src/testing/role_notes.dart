import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/pubspec.dart';
import 'package:smf_pipeline/src/render.dart';
import 'package:smf_pipeline/src/resolver.dart';
import 'package:smf_pipeline/src/testing/file_indexer.dart';
import 'package:smf_pipeline/src/testing/harness.dart';

/// What the notes of roles in the keyed [socket] name of the modules behind
/// the roles, in the apps of [results]: one line for each.
///
/// A note of a role is an entry of [socket] that the template of a role
/// gives, from its contributions or from its render hook, such as the note
/// of the router role in the guide for coding agents of an app. It tells
/// what holds whichever modules provide the roles, so it names nothing of
/// such a module. [textOf] gives the Markdown of a value of the socket.
///
/// The modules that a note is held against are the providers of every role
/// in an app of [results], not only of the role of the note, and the
/// modules that they depend on. Of them, a note names:
/// - no id and no package that one of them adds from pub.dev: neither as it
///   is, nor with `-` for `_`, nor in camel case, also inside a longer name,
///   so `GoRouterState` names `go_router`. This counts in the text and in
///   code. A name whose words are all words of the ids and descriptions of
///   the roles, such as a module `settings` next to a settings screen role,
///   cannot be told from the role, so it counts only as it is, in code;
/// - in code, no name that only their Dart files declare at the top level
///   or as the prefix of an import;
/// - in code, no name in upper camel case that no file of an app declares
///   at its top level and that is only in the code of files which all
///   import the same thing of theirs: a package that one of them adds from
///   pub.dev, or a file that one of them imports and no module generates,
///   as a tool writes it later. Such a name is taken for one of that
///   package or file, such as `GoRouter` for one of `go_router`. A name
///   that two files have with different packages, or one file without any,
///   is one of Dart, of Flutter or of the app;
/// - in inline code, no file or directory that only they generate.
///
/// What a role guarantees is free to every note: the symbols of its
/// [Role.interface] with their named parameters, their getters and the
/// types that they are declared with, the files of those symbols, the files
/// that its providers generate ([RoleInterface.providerFiles]), and each
/// name that the description of one of its rules gives as code, which is a
/// name before a `(`, or one with an upper-case letter or a `_` after its
/// first character. A file or a directory at the root of the app that
/// every app of [results] has is free too, such as `pubspec.yaml` or
/// `test/`, and so are the names of `dart:core` and `dart:async`.
///
/// Inline code that is the path of a file or a directory of an app is read
/// as that path only. Other code without a space, a quote or a parenthesis
/// and with a `/` is a path too, and is not read for the names of code.
/// `<` and `>` around lower-case words are a placeholder of a pattern, such
/// as `<feature>`, and are not read.
///
/// The check cannot tell everything. It does not read the text for the
/// names of code. It knows the code of the modules only from the files of
/// the apps, so it misses what a package has and no file uses, and a name
/// in lower case that a file only uses, such as a method of a package. It
/// misses a single word of an id of several words, such as the brand of a
/// package. In the other direction, a name of Flutter, or of a library of
/// Dart other than those two, that only files with one package have is
/// taken for a name of that package. [allowed] is for that case, and for a
/// note that the caller cannot change: it has what a note may name after
/// all, as the note gives it, each with the reason. An entry that excuses
/// nothing gets a line too.
///
/// A note is held against the modules of the apps of [results] only, so a
/// registry with other providers of the roles, each with an id, packages
/// and files of its own, checks more.
///
/// ```dart
/// test('the notes of the roles name nothing of their providers', () async {
///   final results = await ContractHarness(ModuleRegistry(modules)).checkAll();
///   expect(
///     roleNoteProblems(
///       results,
///       AppEntryRole.agentSections,
///       textOf: (note) => note.text,
///       allowed: {'NavigatorObserver': 'A class of Flutter.'},
///     ),
///     isEmpty,
///   );
/// });
/// ```
List<String> roleNoteProblems<V extends Object>(
  Iterable<ContractResult> results,
  SocketRef<KeyedSocket<V>> socket, {
  required String Function(V value) textOf,
  Map<String, String> allowed = const {},
}) {
  final (:apps, :notes) = _notesOf(results, socket, textOf);
  final lines = <String>[];
  final excused = <String>{};
  for (final MapEntry(key: (role, heading, text), value: name)
      in notes.entries) {
    for (final MapEntry(key: named, value: what)
        in apps.problemsOf(text).entries) {
      if (allowed.containsKey(named)) {
        excused.add(named);
      } else {
        lines.add(
          'The note of the $role under "$heading" names $what (in the app '
          'of $name).',
        );
      }
    }
  }
  for (final MapEntry(key: named, value: reason) in allowed.entries) {
    if (excused.contains(named)) continue;
    lines.add(
      '`allowed` has `$named` ("$reason"), which no note of a role names in '
      'a way that the check refuses. Remove the entry.',
    );
  }
  return lines;
}

/// A note of a role: the role, the heading that the note is under, and its
/// text.
typedef _Note = (Role, String, String);

/// The apps of [results] that rendered, and the notes of roles in the
/// keyed [socket] of those apps, with the text that [textOf] gives: each
/// note once, with the name of the case of the first app that has it; see
/// [roleNoteProblems].
({_Apps apps, Map<_Note, String> notes}) _notesOf<V extends Object>(
  Iterable<ContractResult> results,
  SocketRef<KeyedSocket<V>> socket,
  String Function(V value) textOf,
) {
  final apps = _Apps();
  final notes = <_Note, String>{};
  for (final result in results) {
    final app = result.app;
    if (app == null) continue;
    apps.add(result);
    for (final (origin, heading, value) in app.entriesOf(socket)) {
      if (origin case RoleTemplateOrigin(:final role)) {
        notes.putIfAbsent(
          (role, heading, textOf(value)),
          () => result.contractCase.name,
        );
      }
    }
  }
  return (apps: apps, notes: notes);
}

/// What the apps of the results of a contract harness tell of the modules
/// behind the roles.
final class _Apps {
  /// How many apps there are.
  int _count = 0;

  /// The first role that each provider of a role provides.
  final Map<ModuleId, Role> _providers = {};

  /// Each module that a provider of a role depends on, with the first such
  /// provider.
  final Map<ModuleId, ModuleId> _dependencies = {};

  /// The words of the ids and of the descriptions of the roles.
  final Set<String> _roleWords = {};

  /// The packages that each module adds to an app from pub.dev.
  final Map<ModuleId, Set<String>> _packages = {};

  /// The names that the Dart files of each owner declare at their top
  /// level, and the prefixes of their imports, each with the path of one of
  /// those files; `null` owns the files of no module, such as those of the
  /// template of a role.
  final Map<ModuleId?, Map<String, String>> _topLevel = {};

  /// The members of the types that the Dart files of each owner declare.
  final Map<ModuleId?, Set<String>> _members = {};

  /// Who generates the file at each path.
  final Map<String, Set<ModuleId?>> _owners = {};

  /// In how many apps each file and directory at the root of an app is.
  final Map<String, int> _atRoot = {};

  /// For each name in upper camel case in the code of a Dart file, what
  /// every file with the name imports from outside Dart and the files of
  /// its app: a package as `package:<name>`, and a file that the app does
  /// not have by its path. A name without any is one of Dart or of an app.
  final Map<String, Set<String>> _outside = {};

  /// The modules behind each thing from outside: those that add a package
  /// from pub.dev, and those that import a file which the app does not
  /// have. No module is behind a package of an SDK, such as Flutter.
  final Map<String, Set<ModuleId>> _behind = {};

  /// The names that the roles require of their providers, or give as code
  /// in the descriptions of their rules.
  final Set<String> _guaranteedNames = {};

  /// The files of the symbols that the roles require, and the files that
  /// they require of their providers.
  final Set<String> _guaranteedPaths = {};

  /// The names of a Dart file, by its text.
  final Map<String, _FileNames> _namesOfText = {};

  /// Takes in the app of [result], which rendered.
  void add(ContractResult result) {
    final resolution = result.resolution!;
    final app = result.app!;
    _count++;
    for (final role in resolution.presentRoles) {
      _roleWords
        ..addAll(_wordsOf(role.id))
        ..addAll(_wordsOf(role.description));
      _addGuarantees(role);
      _addProviders(role, resolution);
    }
    final packages = _addPackagesOf(result.validation!.pubspec);
    final atRoot = <String>{};
    for (final file in app.files.values) {
      atRoot.add(file.path.split('/').first);
      _addFile(file, packages, app);
    }
    for (final entry in atRoot) {
      _atRoot[entry] = (_atRoot[entry] ?? 0) + 1;
    }
  }

  /// Takes in what [role] guarantees: the files of the symbols of its
  /// [Role.interface], their names with their named parameters, their
  /// getters and the types that they are declared with, the files that it
  /// requires of its providers, and the names that the descriptions of its
  /// rules give as code.
  void _addGuarantees(Role role) {
    _guaranteedPaths.addAll(role.interface.providerFiles);
    for (final symbol in role.interface.symbols) {
      _guaranteedPaths.add(symbol.path);
      _guaranteedNames
        ..add(symbol.name)
        ..addAll(symbol.namedParameters)
        ..addAll(
          switch (symbol) {
            RequiredClass(:final getters) => getters,
            RequiredExtension(:final getters, :final on) => [
                ...getters,
                ..._identifiersOf(on),
              ],
            RequiredFunction(:final returnType) =>
              _identifiersOf(returnType ?? ''),
          },
        );
    }
    for (final description in [
      for (final rule in role.structuralRules) rule.description,
      for (final rule in role.moduleRules) rule.description,
    ]) {
      _guaranteedNames.addAll(_codeNamesOf(description));
    }
  }

  /// Takes in the providers of [role] in the app of [resolution], and the
  /// modules that each of them depends on.
  void _addProviders(Role role, Resolution resolution) {
    for (final provider in resolution.providersOf(role)) {
      _providers.putIfAbsent(provider.id, () => role);
      for (final dependency in resolution.dependencyClosure(provider.id)) {
        _dependencies.putIfAbsent(dependency, () => provider.id);
      }
    }
  }

  /// Takes in the packages that the modules of an app add from pub.dev,
  /// with [pubspec], the merged pubspec of the app, and returns the names
  /// of all the packages of the app.
  Set<String> _addPackagesOf(MergedPubspec pubspec) {
    final packages = <String>{};
    for (final dependency in [
      ...pubspec.dependencies.values,
      ...pubspec.devDependencies.values,
    ]) {
      packages.add(dependency.package);
      if (dependency.source != PubspecSource.hosted) continue;
      for (final origin in dependency.origins) {
        if (origin case ModuleOrigin(:final module)) {
          final package = dependency.package;
          _packages.putIfAbsent(module, () => {}).add(package);
          _behind.putIfAbsent('$_packageScheme$package', () => {}).add(module);
        }
      }
    }
    return packages;
  }

  /// Takes in [file] of [app], whose packages are [packages]: who generates
  /// it, and of a Dart file the names that it declares and has in its code
  /// and what it takes from outside Dart and the files of the app.
  void _addFile(RenderedFile file, Set<String> packages, RenderedApp app) {
    final owner = switch (file.owner) {
      ModuleOrigin(:final module) => module,
      _ => null,
    };
    _owners.putIfAbsent(file.path, () => {}).add(owner);
    if (!file.isText || !file.path.endsWith('.dart')) return;
    final names = _namesOfText.putIfAbsent(
      file.text,
      () => _FileNames.of(file.path, file.text),
    );
    final topLevel = _topLevel.putIfAbsent(owner, () => {});
    for (final name in names.topLevel) {
      topLevel.putIfAbsent(name, () => file.path);
    }
    _members.putIfAbsent(owner, () => {}).addAll(names.members);
    final outside = _outsideOf(file, names.imports, packages, app);
    for (final name in names.upperCamel) {
      _outside[name] = _outside[name]?.intersection(outside) ?? outside;
    }
  }

  /// What [file] of [app], with [imports], takes from outside Dart and the
  /// files of the app: each of the [packages] of the app that it imports,
  /// and each file that it imports and the app does not have.
  Set<String> _outsideOf(
    RenderedFile file,
    List<String> imports,
    Set<String> packages,
    RenderedApp app,
  ) {
    final outside = <String>{};
    for (final uri in imports) {
      if (uri.startsWith('dart:')) continue;
      final (:package, :path) = _importOf(uri, file.path);
      if (package != null && packages.contains(package)) {
        outside.add('$_packageScheme$package');
      } else if (!app.files.containsKey(path)) {
        outside.add(path);
        _addImporters(path, uri, file);
      }
    }
    return outside;
  }

  /// What [uri] imports into the file at [path]: the `package` of a
  /// `package:` URI, and the `path` of the file in an app. The path of a
  /// `package:` URI is in `lib/`, as if the package were that of the app
  /// itself, which it is when the app does not depend on the package.
  static ({String? package, String path}) _importOf(String uri, String path) {
    var imported = Uri.parse(path).resolve(uri).path;
    String? package;
    if (uri.startsWith(_packageScheme)) {
      final rest = uri.substring(_packageScheme.length).split('/');
      package = rest.removeAt(0);
      imported = 'lib/${rest.join('/')}';
    }
    return (package: package, path: imported);
  }

  /// Takes in who imports [path], a file that the app does not have, with
  /// [uri] in [file]: whoever gave the fragment that the import was added
  /// for, or else the owner of [file].
  void _addImporters(String path, String uri, RenderedFile file) {
    final contributors = [
      for (final added in file.addedImports)
        if (added.import.uri == uri) added.contributor,
    ];
    for (final origin in contributors.isEmpty ? [file.owner] : contributors) {
      if (origin case ModuleOrigin(:final module)) {
        _behind.putIfAbsent(path, () => {}).add(module);
      }
    }
  }

  /// The modules that a note is held against, in the order of their ids:
  /// the providers of the roles, and the modules that they depend on.
  late final List<ModuleId> _held = {
    ..._providers.keys,
    ..._dependencies.keys,
  }.toList()
    ..sort((a, b) => a.value.compareTo(b.value));

  /// What [module], which a note is held against, is.
  String _describe(ModuleId module) => switch (_providers[module]) {
        final role? => 'a module that provides the $role',
        null => 'a module that ${_dependencies[module]} depends on',
      };

  /// The ids of the modules that a note is held against and the packages
  /// that they add, each with its words and with what it is.
  late final List<(String, List<String>, String)> _heldNames = [
    for (final module in _held) ...[
      (module.value, _wordsOf(module.value), 'the id of ${_describe(module)}'),
      for (final package in _packages[module] ?? const <String>{})
        (
          package,
          _wordsOf(package),
          'a package of $module, ${_describe(module)}',
        ),
    ],
  ];

  /// The names that a Dart file of an owner that no note is held against
  /// declares, in any way.
  late final Set<String> _declaredElsewhere = {
    for (final MapEntry(key: owner, value: names) in _topLevel.entries)
      if (!_held.contains(owner)) ...names.keys,
    for (final MapEntry(key: owner, value: names) in _members.entries)
      if (!_held.contains(owner)) ...names,
  };

  /// What [text], a note of a role, names of the modules that it is held
  /// against: each thing as the note gives it, with the rest of a sentence
  /// that starts with "The note names".
  Map<String, String> problemsOf(String text) {
    final (:prose, :spans, :blocks) = _partsOf(text);
    final problems = <String, String>{};
    for (final span in spans) {
      _readSpan(span, problems);
    }
    for (final line in blocks) {
      final isPath = line.contains('/') && !_notOfPath.hasMatch(line.trim());
      _read(line, problems, names: !isPath);
    }
    for (final token in _tokensOf(prose)) {
      if (_heldNameIn(token, code: false) case final what?) {
        problems.putIfAbsent(token, () => '$token in its text, $what');
      }
    }
    return problems;
  }

  /// Adds to [problems] what [span], inline code of a note, names of the
  /// modules that the note is held against. A span that is the path of a
  /// file or a directory of an app is read as that path only, and other
  /// code that is a path is not read for the names of code.
  void _readSpan(String span, Map<String, String> problems) {
    final pathLike = !_notOfPath.hasMatch(span);
    if (pathLike) {
      final path =
          span.endsWith('/') ? span.substring(0, span.length - 1) : span;
      final files = _filesAt(path);
      if (files.isNotEmpty) {
        if (_pathProblem(span, path, files) case final what?) {
          problems.putIfAbsent(span, () => what);
        }
        return;
      }
    }
    _read(span, problems, names: !(pathLike && span.contains('/')));
  }

  /// The files of the apps at [path], or under it as a directory.
  List<String> _filesAt(String path) => [
        for (final file in _owners.keys)
          if (file == path || file.startsWith('$path/')) file,
      ];

  /// What [span], inline code of a note that is the path [path] of [files],
  /// the files of the apps at it or under it, names of the modules that the
  /// note is held against, as the end of a sentence, or `null` when a note
  /// may give it: a file or a directory that only they generate, that no
  /// role guarantees and that not every app has at its root.
  String? _pathProblem(String span, String path, List<String> files) {
    final owners = {for (final file in files) ..._owners[file]!};
    if (!files.any(_guaranteedPaths.contains) &&
        _atRoot[path] != _count &&
        owners.every(_held.contains)) {
      return '`$span`, which only ${owners.join(' and ')} '
          '${owners.length == 1 ? 'generates' : 'generate'} and no '
          'role guarantees';
    }
    return null;
  }

  /// Adds to [problems] what [code] of a note names of the modules that
  /// the note is held against: their ids and packages, and with [names]
  /// the names of their code.
  void _read(
    String code,
    Map<String, String> problems, {
    required bool names,
  }) {
    final read = code.replaceAll(_placeholder, ' ');
    if (names) {
      for (final name in _identifiersOf(read)) {
        if (_nameProblem(name) case final what?) {
          problems.putIfAbsent(name, () => '`$name`, $what');
        }
      }
    }
    for (final token in _tokensOf(read)) {
      if (_heldNameIn(token, code: true) case final what?) {
        problems.putIfAbsent(token, () => '`$token`, $what');
      }
    }
  }

  /// What the name [name] of code is of a module that a note is held
  /// against, as the end of a sentence, or `null` when a note may give it.
  String? _nameProblem(String name) {
    if (_guaranteedNames.contains(name) ||
        _dartNames.contains(name) ||
        _declaredElsewhere.contains(name)) {
      return null;
    }
    for (final module in _held) {
      if (_topLevel[module]?[name] case final path?) {
        return 'which only $path of $module declares, ${_describe(module)}';
      }
    }
    for (final outside in [...?_outside[name]]..sort()) {
      for (final module in _held) {
        if (!(_behind[outside]?.contains(module) ?? false)) continue;
        return outside.startsWith(_packageScheme)
            ? 'which only code that imports $outside uses, a package of '
                '$module, ${_describe(module)}'
            : 'which only code that imports $outside uses, a file that no '
                'module generates and $module imports, ${_describe(module)}';
      }
    }
    return null;
  }

  /// What [token] of a note names of the ids and the packages of the
  /// modules that the note is held against, as the end of a sentence, or
  /// `null`. In [code] or in the text of the note.
  String? _heldNameIn(String token, {required bool code}) {
    if (_guaranteedNames.contains(token)) return null;
    final words = ' ${_wordsOf(token).join(' ')} ';
    for (final (name, ofName, what) in _heldNames) {
      if (ofName.every(_roleWords.contains)) {
        if (code && token == name) return what;
      } else if (words.contains(' ${ofName.join(' ')} ')) {
        return token == name ? what : 'which has the words of $name, $what';
      }
    }
    return null;
  }
}

/// The names of a Dart file.
final class _FileNames {
  _FileNames._(this.topLevel, this.members, this.upperCamel, this.imports);

  /// The names of the file at [path] with [text].
  factory _FileNames.of(String path, String text) {
    final index = DartFileIndexer.index(path, text);
    return _FileNames._(
      {
        for (final declaration in index.declarations) declaration.name,
        for (final import in index.imports)
          if (import.prefix case final prefix?) prefix,
      },
      {
        for (final declaration in index.declarations)
          for (final member in declaration.members) member.name,
      },
      _upperCamelNamesOf(text).toSet(),
      [for (final import in index.imports) import.uri],
    );
  }

  /// What the file declares at its top level, and the prefixes of its
  /// imports.
  final Set<String> topLevel;

  /// The members of the types that the file declares.
  final Set<String> members;

  /// The names in upper camel case in the code of the file.
  final Set<String> upperCamel;

  /// What the file imports.
  final List<String> imports;
}

/// The names in the code of [dart] that start with an upper-case letter, as
/// those of types do: not those in its comments or in the text of its
/// strings.
Iterable<String> _upperCamelNamesOf(String dart) sync* {
  final unit = parseString(content: dart, throwIfDiagnostics: false).unit;
  for (var token = unit.beginToken; !token.isEof; token = token.next!) {
    if (token.type == TokenType.IDENTIFIER &&
        token.lexeme.startsWith(_upperCase)) {
      yield token.lexeme;
    }
  }
}

/// The names in upper camel case that `dart:core` and `dart:async` declare,
/// as of Dart 3.12. They are names of Dart whatever else a file imports, so
/// no note names a package with one.
const Set<String> _dartNames = {
  'ArgumentError',
  'AssertionError',
  'AsyncError',
  'BigInt',
  'Comparable',
  'Comparator',
  'Completer',
  'ConcurrentModificationError',
  'DateTime',
  'DeferredLoadException',
  'Deprecated',
  'Duration',
  'Enum',
  'Error',
  'EventSink',
  'Exception',
  'Expando',
  'Finalizer',
  'FormatException',
  'Function',
  'Future',
  'FutureOr',
  'IndexError',
  'IntegerDivisionByZeroException',
  'Invocation',
  'Iterable',
  'Iterator',
  'List',
  'Map',
  'MapEntry',
  'Match',
  'MultiStreamController',
  'Never',
  'NoSuchMethodError',
  'Null',
  'Object',
  'OutOfMemoryError',
  'ParallelWaitError',
  'Pattern',
  'RangeError',
  'Record',
  'RegExp',
  'RegExpMatch',
  'RuneIterator',
  'Runes',
  'Set',
  'Sink',
  'StackOverflowError',
  'StackTrace',
  'StateError',
  'Stopwatch',
  'Stream',
  'StreamConsumer',
  'StreamController',
  'StreamIterator',
  'StreamSink',
  'StreamSubscription',
  'StreamTransformer',
  'StreamTransformerBase',
  'StreamView',
  'String',
  'StringBuffer',
  'StringSink',
  'Symbol',
  'SynchronousStreamController',
  'TimeoutException',
  'Timer',
  'Type',
  'TypeError',
  'UnimplementedError',
  'UnsupportedError',
  'Uri',
  'UriData',
  'WeakReference',
  'Zone',
  'ZoneDelegate',
  'ZoneSpecification',
};

/// The start of the URI of a library of a package, its scheme with the
/// colon, as in `package:<name>/<path>`.
const String _packageScheme = 'package:';

/// A word of a name or of a text: a run of lower-case letters, with an
/// upper-case letter before it or not, a run of upper-case letters, or a
/// run of digits.
final RegExp _word = RegExp('[A-Z]+(?![a-z])|[A-Z]?[a-z]+|[0-9]+');

/// What may hold the id of a module or the name of a package: a name of
/// code, also with `-` between its parts.
final RegExp _token = RegExp(r'[A-Za-z0-9_$]+(?:-[A-Za-z0-9_$]+)*');

/// An identifier of Dart.
final RegExp _identifier = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');

/// An upper-case letter, as the name of a type starts with.
final RegExp _upperCase = RegExp('[A-Z]');

/// An upper-case letter or an underscore after the first character of a
/// name.
final RegExp _insideMark = RegExp('.[A-Z_]');

/// A placeholder of a pattern, such as `<feature>`.
final RegExp _placeholder = RegExp('<[a-z][a-z0-9_ ]*>');

/// What the path of a file does not have.
final RegExp _notOfPath = RegExp(r'''[\s'"()]''');

/// A span of inline code of a line of Markdown.
final RegExp _span = RegExp('`([^`]+)`');

/// A line of Markdown that opens or closes a fenced code block.
final RegExp _fence = RegExp(r'^\s*(`{3,}|~{3,})');

/// The identifiers of [code].
Iterable<String> _identifiersOf(String code) =>
    _identifier.allMatches(code).map((identifier) => identifier[0]!);

/// The tokens of [text]; see [_token].
Iterable<String> _tokensOf(String text) =>
    _token.allMatches(text).map((token) => token[0]!);

/// The words of [text] in lower case, in their order: those of a name in
/// camel case, in snake case or with hyphens, such as `go` and `router` of
/// `GoRouter`, of `go_router` and of `go-router`.
List<String> _wordsOf(String text) => [
      for (final word in _word.allMatches(text)) word[0]!.toLowerCase(),
    ];

/// The names that [description], a sentence about code without marks
/// around its code, gives as code: those before a `(`, and those with an
/// upper-case letter or an underscore after their first character, such as
/// `runApp()` and `MaterialApp`.
Iterable<String> _codeNamesOf(String description) sync* {
  for (final match in _identifier.allMatches(description)) {
    final name = match[0]!;
    if (description.startsWith('(', match.end) || _insideMark.hasMatch(name)) {
      yield name;
    }
  }
}

/// The parts of [markdown]: its text without its code, its spans of inline
/// code, and the lines of its fenced code blocks.
({String prose, List<String> spans, List<String> blocks}) _partsOf(
  String markdown,
) {
  final prose = StringBuffer();
  final spans = <String>[];
  final blocks = <String>[];
  // The characters that opened the block that the line is in.
  String? fence;
  for (final line in const LineSplitter().convert(markdown)) {
    final marker = _fence.firstMatch(line)?[1];
    if (fence != null) {
      if (marker != null && marker.startsWith(fence)) {
        fence = null;
      } else {
        blocks.add(line);
      }
    } else if (marker != null) {
      fence = marker;
    } else {
      prose.writeln(
        line.replaceAllMapped(_span, (span) {
          spans.add(span[1]!.trim());
          return ' ';
        }),
      );
    }
  }
  return (prose: '$prose', spans: spans, blocks: blocks);
}
