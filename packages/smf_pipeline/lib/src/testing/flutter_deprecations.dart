import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/source/line_info.dart';
import 'package:smf_pipeline/src/render.dart';

/// The libraries of Flutter that Flutter 3.50 deprecates, for
/// `package:material_ui` and `package:cupertino_ui`.
const _libraries = {
  'package:flutter/material.dart',
  'package:flutter/cupertino.dart',
};

/// The classes of `flutter_localizations` that Flutter 3.50 deprecates, for
/// the classes of the same names of `package:material_ui` and
/// `package:cupertino_ui`.
const _names = {'GlobalMaterialLocalizations', 'GlobalCupertinoLocalizations'};

/// The code of the diagnostic of a deprecated library or name.
const _code = 'deprecated_member_use';

/// The places in the Dart files of [app] for which `flutter analyze` of
/// Flutter 3.50 reports `deprecated_member_use`, and which have no ignore of
/// it: each import or export of `package:flutter/material.dart` or
/// `package:flutter/cupertino.dart`, and each name of
/// `GlobalMaterialLocalizations` or `GlobalCupertinoLocalizations`, one line
/// for each, as `<path>:<line>: <what>`, in the order of the files and the
/// lines.
///
/// The apps allow Flutter 3.44, and keep Flutter's own material library,
/// which their root `MaterialApp` is of: a widget of `material_ui` finds no
/// theme and no localizations of that root. So the code that SMF generates
/// ignores the deprecation where Flutter 3.50 reports it, with
/// `// ignore: deprecated_member_use` on the line above, or with
/// `ImportRef(..., ignore: ['deprecated_member_use'])` for a fragment.
/// Then `flutter analyze` finds no issue on any Flutter that the apps allow,
/// and `dart fix` of Flutter 3.50, which takes no fix for an ignored
/// diagnostic, leaves the app on that library.
///
/// It reads the ignores as the analyzer does: an `// ignore:` comment
/// applies to its own line, or to the next line when it is alone on its
/// line, and an `// ignore_for_file:` comment to the whole file; each names
/// codes, separated by commas, before any text of its own.
List<String> flutterDeprecationProblems(RenderedApp app) => [
      for (final file in app.files.values)
        if (file.path.endsWith('.dart')) ..._problemsOf(file),
    ];

/// The places of [flutterDeprecationProblems] in [file].
List<String> _problemsOf(RenderedFile file) {
  final text = file.text;
  final unit = parseString(content: text, throwIfDiagnostics: false).unit;
  final ignored = _IgnoredLines.of(unit, text);
  if (ignored.wholeFile) return const [];

  final places = <(int, String)>[
    for (final directive in unit.directives)
      if (directive is NamespaceDirective &&
          _libraries.contains(directive.uri.stringValue))
        (
          directive.firstTokenAfterCommentAndMetadata.offset,
          _directiveOf(file, directive),
        ),
    for (final token in _tokensOf(unit))
      if (token.type == TokenType.IDENTIFIER && _names.contains(token.lexeme))
        (token.offset, '${token.lexeme}, in a file of ${file.owner}'),
  ];
  return [
    for (final (offset, what) in places)
      if (_lineOf(unit.lineInfo, offset) case final line
          when !ignored.has(line))
        '${file.path}:$line: $what, has no $_missingIgnore',
  ];
}

/// What a problem of [flutterDeprecationProblems] says its place lacks.
const _missingIgnore = '// ignore: $_code on its line or the line above';

/// What [directive] of [file] is, and who wrote it: the pipeline for a
/// fragment, when it added the import, or else the owner of the file.
String _directiveOf(RenderedFile file, NamespaceDirective directive) {
  final uri = directive.uri.stringValue;
  final kind = directive is ImportDirective ? 'import' : 'export';
  final writer = switch ([
    for (final added in file.addedImports)
      if (added.import.uri == uri) added.contributor,
  ]) {
    [final contributor, ...] =>
      'which the pipeline added for a fragment of $contributor',
    _ when file.fromHook => 'which a render hook of ${file.owner} wrote',
    _ => 'of the template of ${file.owner}',
  };
  return 'the $kind of $uri, $writer';
}

/// The tokens of [unit], in their order, without its end.
Iterable<Token> _tokensOf(CompilationUnit unit) sync* {
  for (Token? token = unit.beginToken;
      token != null && !token.isEof;
      token = token.next) {
    yield token;
  }
}

int _lineOf(LineInfo lines, int offset) => lines.getLocation(offset).lineNumber;

/// The lines of a file that an ignore of `deprecated_member_use` covers.
final class _IgnoredLines {
  _IgnoredLines._(this._lines, {required this.wholeFile});

  /// Reads the `// ignore:` and `// ignore_for_file:` comments of [unit],
  /// whose text is [text].
  factory _IgnoredLines.of(CompilationUnit unit, String text) {
    final lines = <int>{};
    var wholeFile = false;
    for (Token? token = unit.beginToken; token != null; token = token.next) {
      for (Token? comment = token.precedingComments;
          comment != null;
          comment = comment.next) {
        final match = _comment.firstMatch(comment.lexeme);
        if (match == null || !_codesOf(match[2]!).contains(_code)) continue;
        if (match[1] != null) {
          wholeFile = true;
          continue;
        }
        final line = _lineOf(unit.lineInfo, comment.offset);
        final lineStart = unit.lineInfo.getOffsetOfLine(line - 1);
        final alone = text.substring(lineStart, comment.offset).trim().isEmpty;
        lines.add(alone ? line + 1 : line);
      }
      if (token.isEof) break;
    }
    return _IgnoredLines._(lines, wholeFile: wholeFile);
  }

  /// An ignore comment: `// ignore:` or `// ignore_for_file:`, with the
  /// slashes and spaces that the analyzer allows, and what follows.
  static final _comment = RegExp(r'^//+ *ignore(_for_file)?:(.*)$');

  /// A code at the start of an item of the list of an ignore comment, and
  /// what ends it: a blank or the end of the item.
  static final _codeOfItem = RegExp(r'^\s*([A-Za-z_]\w*)(\s|$)');

  /// The codes that [text], what follows the colon of an ignore comment,
  /// names: words of letters, digits and underscores, separated by commas,
  /// up to the first text that is not such a list.
  static Set<String> _codesOf(String text) {
    final codes = <String>{};
    for (final item in text.split(',')) {
      final word = _codeOfItem.firstMatch(item);
      if (word == null) break;
      codes.add(word[1]!.toLowerCase());
      // Text after the word, such as a reason, ends the list.
      if (item.trim() != word[1]) break;
    }
    return codes;
  }

  /// The lines that an ignore of `deprecated_member_use` covers.
  final Set<int> _lines;

  /// Whether an `// ignore_for_file:` comment covers the whole file.
  final bool wholeFile;

  /// Whether an ignore covers [line].
  bool has(int line) => _lines.contains(line);
}
