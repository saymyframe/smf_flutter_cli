import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contracts/core.dart';

/// Thrown when imports cannot be added to a file, such as a part file,
/// which has the imports of its library.
final class ImportTargetException implements Exception {
  /// Creates the exception with the [reason].
  const ImportTargetException(this.reason);

  /// Why, as a phrase such as `it is a part of another library`.
  final String reason;

  @override
  String toString() => 'ImportTargetException: $reason';
}

/// An import directive of a file, with its URI as the app sees it.
final class _Existing {
  _Existing(this.node, this.key, this.shows);

  final ImportDirective node;

  /// The URI, `package:` for a file of the app, and the prefix.
  final (String, String?) key;

  /// The names it shows, or `null` if it imports all of them, or hides
  /// some, or is conditional.
  final Set<String>? shows;
}

/// Adds [imports] to [text], the Dart file at [path] of the app whose
/// package is [appName].
///
/// The directives go among the imports of the file where
/// `directives_ordering` puts them: `dart:` imports first, then `package:`
/// imports, each group sorted by URI, relative imports last. An import the
/// file already has, as the same library with the same prefix and at least
/// the same names, is left out; so is a file of the app imported by a
/// relative URI.
///
/// Returns the new text and the directives added, merged with
/// [ImportRef.merge]. Throws an [ImportTargetException] if [text] is a part
/// of another library, which cannot have imports of its own.
({String text, List<ImportRef> added}) addImports(
  String text, {
  required String path,
  required List<ImportRef> imports,
  required String appName,
}) {
  if (imports.isEmpty) return (text: text, added: const []);
  final unit = parseString(content: text, throwIfDiagnostics: false).unit;
  if (unit.directives.any((directive) => directive is PartOfDirective)) {
    throw const ImportTargetException('it is a part of another library');
  }

  final base = path.startsWith('lib/')
      ? Uri.parse('package:$appName/${path.substring('lib/'.length)}')
      : null;
  final existing = _existingImports(unit, base);

  final added = [
    for (final import in ImportRef.merge(imports, appName: appName))
      if (!existing.any((known) => _covers(known, import))) import,
  ];
  if (added.isEmpty) return (text: text, added: const []);

  final inserter = _Inserter(
    text,
    [for (final known in existing) known.node],
    appName,
  );
  final sections = <String>[];
  for (final group in [0, 1]) {
    if (inserter.addGroup(group, added) case final block?) {
      sections.add(block);
    }
  }
  if (sections.isNotEmpty) {
    inserter.addToFileWithoutImports(sections.join('\n\n'), unit);
  }
  return (text: inserter.result, added: added);
}

/// The imports of [unit], the file at [base] if it is in `lib/`.
List<_Existing> _existingImports(CompilationUnit unit, Uri? base) => [
      for (final directive in unit.directives)
        if (directive is ImportDirective)
          _Existing(
            directive,
            (_canonical(_uriOf(directive), base), directive.prefix?.name),
            directive.configurations.isNotEmpty ||
                    directive.combinators.whereType<HideCombinator>().isNotEmpty
                ? {}
                : _shownNames(directive),
          ),
    ];

/// Puts the directives that [addImports] adds into a file where
/// `directives_ordering` puts them, and gives the file with them.
final class _Inserter {
  _Inserter(this.text, this.nodes, this.appName)
      : _newline = text.contains('\r\n') ? '\r\n' : '\n';

  /// The text of the file.
  final String text;

  /// The import directives of the file.
  final List<ImportDirective> nodes;

  /// The package of the app.
  final String appName;

  final String _newline;

  /// What to insert at each offset, in the order of the merged imports,
  /// which are sorted by group and URI like the result, with the line
  /// endings of the file.
  final Map<int, List<String>> _insertions = {};

  void _insert(int offset, String code) => _insertions
      .putIfAbsent(offset, () => [])
      .add(code.replaceAll('\n', _newline));

  /// Adds those of [imports] that are in [group] next to the imports of the
  /// file, or returns them as a block if the file has no imports.
  String? addGroup(int group, List<ImportRef> imports) {
    final lines = [
      for (final import in imports)
        if (_groupOf(import.uri) == group) import,
    ];
    if (lines.isEmpty) return null;
    final sameGroup = [
      for (final node in nodes)
        if (_groupOf(_uriOf(node)) == group) node,
    ];
    if (sameGroup.isNotEmpty) {
      _addAmong(lines, sameGroup);
      return null;
    }
    final block = lines.map((import) => import.toDirective(appName)).join('\n');
    final next =
        nodes.where((node) => _groupOf(_uriOf(node)) > group).firstOrNull;
    final previous =
        nodes.where((node) => _groupOf(_uriOf(node)) < group).lastOrNull;
    if (next != null) {
      _insert(_lineStart(text, next.offset), '$block\n\n');
    } else if (previous != null) {
      _insert(_lineEnd(text, previous.end), '\n\n$block');
    } else {
      return block;
    }
    return null;
  }

  /// Adds each of [imports] among [sameGroup], the imports of the file in
  /// its group: before the first with a greater URI, or after the last.
  void _addAmong(List<ImportRef> imports, List<ImportDirective> sameGroup) {
    for (final import in imports) {
      final directive = import.toDirective(appName);
      final next = sameGroup
          .where((node) => _uriOf(node).compareTo(import.uri) > 0)
          .firstOrNull;
      if (next != null) {
        _insert(_lineStart(text, next.offset), '$directive\n');
      } else {
        _insert(_lineEnd(text, sameGroup.last.end), '\n$directive');
      }
    }
  }

  /// Adds [block], the imports of [unit], a file that has none, before its
  /// first directive or declaration after the library directive.
  void addToFileWithoutImports(String block, CompilationUnit unit) {
    final first = [
      ...unit.directives.where((directive) => directive is! LibraryDirective),
      ...unit.declarations,
    ].firstOrNull;
    final library = unit.directives.whereType<LibraryDirective>().firstOrNull;
    if (first != null) {
      // Before the first node, or at the start of the file if only blank
      // lines come before it.
      final start = _lineStart(text, first.offset);
      _insert(
        text.substring(0, start).trim().isEmpty ? 0 : start,
        '$block\n\n',
      );
    } else if (library != null) {
      _insert(_lineEnd(text, library.end), '\n\n$block');
    } else {
      _insert(0, '$block\n');
    }
  }

  /// The text of the file with what was added.
  String get result {
    final buffer = StringBuffer();
    var position = 0;
    for (final offset in _insertions.keys.toList()..sort()) {
      buffer
        ..write(text.substring(position, offset))
        ..writeAll(_insertions[offset]!);
      position = offset;
    }
    buffer.write(text.substring(position));
    return buffer.toString();
  }
}

String _uriOf(ImportDirective node) => node.uri.stringValue ?? '';

/// The group of an import in `directives_ordering`: `dart:`, `package:`,
/// then relative.
int _groupOf(String uri) {
  if (uri.startsWith('dart:')) return 0;
  if (uri.startsWith('package:')) return 1;
  return 2;
}

/// [uri] as the app sees it: a relative import of a file in `lib/` becomes
/// the `package:` URI of the file, when [base], the file that imports it,
/// is in `lib/` too.
String _canonical(String uri, Uri? base) {
  if (base == null || uri.startsWith('dart:') || uri.startsWith('package:')) {
    return uri;
  }
  return base.resolve(uri).toString();
}

Set<String>? _shownNames(ImportDirective directive) {
  final shows = directive.combinators.whereType<ShowCombinator>().toList();
  if (shows.isEmpty) return null;
  // Several show combinators import only the names they all show.
  Set<String>? names;
  for (final show in shows) {
    final these = {for (final name in show.shownNames) name.name};
    names = names == null ? these : names.intersection(these);
  }
  return names;
}

/// Whether [known] already imports what [import] would.
bool _covers(_Existing known, ImportRef import) {
  if (known.key != (import.uri, import.prefix)) return false;
  final shows = known.shows;
  if (shows == null) return true;
  return import.show.isNotEmpty && shows.containsAll(import.show);
}

int _lineStart(String text, int offset) =>
    text.lastIndexOf('\n', offset == 0 ? 0 : offset - 1) + 1;

int _lineEnd(String text, int offset) {
  final end = text.indexOf('\n', offset);
  if (end < 0) return text.length;
  return end > 0 && text[end - 1] == '\r' ? end - 1 : end;
}
