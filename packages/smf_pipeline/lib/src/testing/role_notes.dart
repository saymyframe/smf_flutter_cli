import 'dart:convert';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:smf_contracts/core.dart';
import 'package:smf_pipeline/src/testing/file_indexer.dart';
import 'package:smf_pipeline/src/testing/harness.dart';

/// What the notes of roles in the keyed [socket] name of the modules that
/// provide their roles, in the apps of [results]: one line for each.
///
/// A note of a role is an entry of [socket] that the template of a role
/// gives, from its contributions or from its render hook, such as the note
/// of the router role in the guide for coding agents of an app. It tells
/// what holds whichever module provides the role, so it names nothing that
/// only a provider has. [textOf] gives the Markdown of a value of the
/// socket. Of the modules that provide its role in an app of [results], a
/// note names:
/// - no id of such a module, such as `go_router` in a note of the router
///   role;
/// - no package that such a module adds to the app from pub.dev;
/// - no name that only the Dart files of such modules declare, at their top
///   level, as a member of a type or as the prefix of an import;
/// - no name that only the Dart files of such modules use and no file of an
///   app declares, such as a class of the package of a provider: a name in
///   upper camel case anywhere in their code, as that of a type, a function
///   or a method they call, a named argument they pass or a member they
///   read;
/// - no file or directory that only such modules generate, unless a role
///   guarantees it.
///
/// The files are those of every app of [results]. A name that a role
/// requires of its provider (a symbol of its [Role.interface], with its
/// named parameters and its getters), or that the description of one of
/// its rules states, is a name of the role: any note may give it.
///
/// An id or a package counts wherever its name stands as a word of its own,
/// also with `-` for `_`. One whose words are all words of the id or the
/// description of the role, such as a module `settings` that provides the
/// settings screen, counts only in code, since in the text it cannot be
/// told from the role. A name counts in inline code and in fenced code
/// blocks, but not in code with a `/`, which is a path, or between `<` and
/// `>`, where a pattern has its placeholders. A file or a directory counts
/// in inline code.
///
/// A note is held against every provider of its role in the apps of
/// [results], so a registry with a second provider of a role, with an id,
/// packages and files of its own, checks more than a registry with one.
///
/// ```dart
/// test('the notes of the roles name nothing of their providers', () async {
///   final results = await ContractHarness(ModuleRegistry(modules)).checkAll();
///   expect(
///     roleNoteProblems(
///       results,
///       AppEntryRole.agentSections,
///       textOf: (note) => note.text,
///     ),
///     isEmpty,
///   );
/// });
/// ```
List<String> roleNoteProblems<V extends Object>(
  Iterable<ContractResult> results,
  SocketRef<KeyedSocket<V>> socket, {
  required String Function(V value) textOf,
}) {
  final apps = _Apps();
  // Each note once, with the case of the first app that has it.
  final notes = <(Role, String, String), String>{};
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
  final problems = <String>[];
  for (final MapEntry(key: (role, heading, text), value: name)
      in notes.entries) {
    for (final problem in apps.problemsOf(role, text)) {
      problems.add(
        'The note of the $role under "$heading" $problem (in the app of '
        '$name).',
      );
    }
  }
  return problems;
}

/// What the apps of the results of a contract harness tell of the modules
/// that provide the roles.
final class _Apps {
  /// The modules that provide each role in an app.
  final Map<Role, Set<ModuleId>> _providers = {};

  /// The packages that each module adds to an app from pub.dev.
  final Map<ModuleId, Set<String>> _packages = {};

  /// The names that the Dart files of each owner declare, and those that
  /// they use, each with the path of one of those files; `null` owns the
  /// files of no module, such as those of the template of a role.
  final Map<ModuleId?, _Names> _names = {};

  /// Who generates the file at each path.
  final Map<String, Set<ModuleId?>> _owners = {};

  /// The names that the roles require of their providers, or state in
  /// their rules.
  final Set<String> _guaranteedNames = {};

  /// The files that the roles guarantee.
  final Set<String> _guaranteedPaths = {};

  /// The names of a Dart file, by its text.
  final Map<String, _FileNames> _namesOfText = {};

  /// Takes in the app of [result], which rendered.
  void add(ContractResult result) {
    final resolution = result.resolution!;
    for (final role in resolution.presentRoles) {
      _providers.putIfAbsent(role, () => {}).addAll([
        for (final provider in resolution.providersOf(role)) provider.id,
      ]);
      _guaranteedPaths.addAll(role.interface.files);
      for (final symbol in role.interface.symbols) {
        _guaranteedPaths.add(symbol.path);
        _guaranteedNames
          ..add(symbol.name)
          ..addAll(symbol.namedParameters)
          ..addAll(
            switch (symbol) {
              RequiredClass(:final getters) => getters,
              RequiredExtension(:final getters) => getters,
              RequiredFunction() => const [],
            },
          );
      }
      for (final description in [
        for (final rule in role.structuralRules) rule.description,
        for (final rule in role.moduleRules) rule.description,
      ]) {
        _guaranteedNames.addAll(_identifiersOf(description));
      }
    }
    final pubspec = result.validation!.pubspec;
    for (final dependency in [
      ...pubspec.dependencies.values,
      ...pubspec.devDependencies.values,
    ]) {
      if (dependency.source != PubspecSource.hosted) continue;
      for (final origin in dependency.origins) {
        if (origin case ModuleOrigin(:final module)) {
          _packages.putIfAbsent(module, () => {}).add(dependency.package);
        }
      }
    }
    for (final file in result.app!.files.values) {
      final owner = switch (file.owner) {
        ModuleOrigin(:final module) => module,
        _ => null,
      };
      _owners.putIfAbsent(file.path, () => {}).add(owner);
      if (!file.isText || !file.path.endsWith('.dart')) continue;
      final ofFile = _namesOfText.putIfAbsent(
        file.text,
        () => _FileNames.of(file.path, file.text),
      );
      _names.putIfAbsent(owner, _Names.new).add(ofFile, file.path);
    }
  }

  /// What [text], a note of [role], names of the providers of the role,
  /// each as the rest of a sentence about the note.
  List<String> problemsOf(Role role, String text) {
    // The app with the note has the role, so it has a provider of it.
    final providers = _providers[role]!.toList()
      ..sort((a, b) => a.value.compareTo(b.value));
    final (:prose, :spans, :blocks) = _partsOf(text);
    final proseWords = _wordsOf(prose);
    final codeWords = _wordsOf([...spans, ...blocks].join('\n'));
    final ofRole = {
      ...role.id.split('_'),
      ..._lowerWord.allMatches(role.description.toLowerCase()).map(
            (word) => word[0]!,
          ),
    };
    bool names(String name) =>
        codeWords.contains(name) ||
        (proseWords.contains(name) && !name.split('_').every(ofRole.contains));

    final problems = <String>[];
    for (final provider in providers) {
      if (names(provider.value)) {
        problems.add(
          'names ${provider.value}, the id of a module that provides the '
          'role',
        );
      }
      for (final package in [...?_packages[provider]]..sort()) {
        if (package != provider.value && names(package)) {
          problems.add('names $package, a package that $provider adds');
        }
      }
    }

    final declaredElsewhere = <String>{};
    final usedElsewhere = <String>{};
    final declared = <String>{};
    for (final MapEntry(key: owner, value: names) in _names.entries) {
      declared.addAll(names.declared.keys);
      if (providers.contains(owner)) continue;
      declaredElsewhere.addAll(names.declared.keys);
      usedElsewhere.addAll(names.used.keys);
    }
    // What only the providers have, each with what they do with it and
    // where.
    final ofProviders = <String, String>{};
    for (final provider in providers) {
      final names = _names[provider] ?? _Names();
      for (final MapEntry(key: name, value: path) in names.declared.entries) {
        if (!declaredElsewhere.contains(name)) {
          ofProviders[name] = 'only $path of $provider declares';
        }
      }
      for (final MapEntry(key: name, value: path) in names.used.entries) {
        if (!usedElsewhere.contains(name) && !declared.contains(name)) {
          ofProviders[name] = 'only $path of $provider uses';
        }
      }
    }
    final identifiers = {
      for (final code in [...spans, ...blocks])
        if (!code.contains('/'))
          ..._identifiersOf(code.replaceAll(_placeholder, ' ')),
    };
    for (final identifier in identifiers) {
      if (_guaranteedNames.contains(identifier)) continue;
      if (ofProviders[identifier] case final what?) {
        problems.add('names `$identifier`, which $what');
      }
    }

    for (final span in {...spans}) {
      final path =
          span.endsWith('/') ? span.substring(0, span.length - 1) : span;
      final under = [
        for (final file in _owners.keys)
          if (file == path || file.startsWith('$path/')) file,
      ];
      if (under.isEmpty || under.any(_guaranteedPaths.contains)) continue;
      final owners = {for (final file in under) ..._owners[file]!};
      if (owners.every(providers.contains)) {
        problems.add(
          'names `$span`, which only ${owners.join(' and ')} '
          '${owners.length == 1 ? 'generates' : 'generate'} and no role '
          'guarantees',
        );
      }
    }
    return problems;
  }
}

/// The names that the Dart files of one owner declare and those that they
/// use, each with the path of the first file that has it.
final class _Names {
  final Map<String, String> declared = {};
  final Map<String, String> used = {};

  /// Adds the names [ofFile], those of the file at [path].
  void add(_FileNames ofFile, String path) {
    for (final name in ofFile.declared) {
      declared.putIfAbsent(name, () => path);
    }
    for (final name in ofFile.used) {
      used.putIfAbsent(name, () => path);
    }
  }
}

/// The names of a Dart file.
final class _FileNames {
  _FileNames._(this.declared, this.used);

  /// The names of the file at [path] with [text].
  factory _FileNames.of(String path, String text) {
    final index = DartFileIndexer.index(path, text);
    return _FileNames._(
      {
        for (final declaration in index.declarations) ...[
          declaration.name,
          for (final member in declaration.members) member.name,
        ],
        for (final import in index.imports)
          if (import.prefix case final prefix?) prefix,
      },
      {
        ..._upperCamelNamesOf(text),
        for (final invocation in index.invocations) ...[
          invocation.name,
          ...invocation.namedArguments,
        ],
        for (final access in index.memberAccesses) access.name,
      },
    );
  }

  /// What the file declares: its top-level declarations, the members of
  /// its types and the prefixes of its imports.
  final Set<String> declared;

  /// What the file uses: the names in upper camel case in its code, the
  /// functions and methods it calls, the named arguments it passes and the
  /// members it reads.
  final Set<String> used;
}

/// The names in the code of [dart] that start with an upper-case letter, as
/// those of types do: not those in its comments or in the text of its
/// strings. A name in lower case may be a local variable, which is no name
/// that a note could give.
Iterable<String> _upperCamelNamesOf(String dart) sync* {
  final unit = parseString(content: dart, throwIfDiagnostics: false).unit;
  for (var token = unit.beginToken; !token.isEof; token = token.next!) {
    if (token.type == TokenType.IDENTIFIER &&
        token.lexeme.startsWith(_upperCase)) {
      yield token.lexeme;
    }
  }
}

/// A word of lower-case letters and digits.
final RegExp _lowerWord = RegExp('[a-z0-9]+');

/// A word that may be the id of a module or the name of a package.
final RegExp _word = RegExp('[A-Za-z0-9_]+');

/// An identifier of Dart.
final RegExp _identifier = RegExp(r'[A-Za-z_$][A-Za-z0-9_$]*');

/// An upper-case letter, as the name of a type starts with.
final RegExp _upperCase = RegExp('[A-Z]');

/// A placeholder of a pattern, such as `<feature>`.
final RegExp _placeholder = RegExp('<[^<>]*>');

/// A span of inline code of a line of Markdown.
final RegExp _span = RegExp('`([^`]+)`');

/// A line of Markdown that opens or closes a fenced code block.
final RegExp _fence = RegExp(r'^\s*(`{3,}|~{3,})');

/// The identifiers of [code].
Iterable<String> _identifiersOf(String code) =>
    _identifier.allMatches(code).map((identifier) => identifier[0]!);

/// The words of [text], as they are and with `_` for `-`, so that the tool
/// `gen-l10n` is a word like the id `gen_l10n`.
Set<String> _wordsOf(String text) => {
      for (final variant in [text, text.replaceAll('-', '_')])
        for (final word in _word.allMatches(variant)) word[0]!,
    };

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
