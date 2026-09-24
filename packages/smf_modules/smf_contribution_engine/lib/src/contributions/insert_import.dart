import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:smf_contribution_engine/src/contribution.dart';

/// Adds an import directive to [file], unless the file already has it.
///
/// An existing import counts as the same when it has the same URI, prefix and
/// combinators, whatever its quotes or line breaks, so running this again
/// changes nothing. Commented-out imports don't count.
///
/// The import goes on a new line after the last import, or else after the
/// library directive, past any comment that trails it on that line. A file
/// with neither gets it above its first directive or declaration, below
/// leading comments such as a license header, or at the end when it holds
/// only comments. Only the new line is added: the rest of the file keeps its
/// formatting, and syntax errors elsewhere in the file don't stop it.
class InsertImport extends Contribution {
  /// Creates a contribution that adds [import] to [file].
  const InsertImport({required super.file, required this.import});

  /// A single import directive, such as `import 'package:a/a.dart';`.
  ///
  /// `PatchEngine` renders its placeholders. [apply] throws an
  /// [ArgumentError] when it isn't a single import directive.
  final String import;

  @override
  Future<String> apply(String original) async {
    final wanted = _importKey(_parseImport(import));
    final unit = parseString(content: original, throwIfDiagnostics: false).unit;
    final imports = unit.directives.whereType<ImportDirective>();
    if (imports.any((i) => _importKey(i) == wanted)) {
      return original;
    }

    // Go on a new line after the last import (or the library directive), past
    // any comment that trails it.
    final anchor = imports.lastOrNull ??
        unit.directives.whereType<LibraryDirective>().firstOrNull;
    if (anchor != null) {
      final offset = _endOfTrailingComments(original, anchor);
      return original.replaceRange(offset, offset, '\n$import');
    }

    // Otherwise go before the first directive or declaration, below leading
    // comments such as a license header.
    final first = unit.directives.firstOrNull ?? unit.declarations.firstOrNull;
    if (first != null) {
      return original.replaceRange(first.offset, first.offset, '$import\n\n');
    }

    // The file holds comments at most, so the import goes at the end.
    final lineBreak = original.isEmpty || original.endsWith('\n') ? '' : '\n';
    return '$original$lineBreak$import\n';
  }
}

ImportDirective _parseImport(String source) {
  final directives = parseString(content: source).unit.directives;
  if (directives case [final ImportDirective directive]) return directive;
  throw ArgumentError.value(source, 'import', 'Not a single import directive');
}

/// What [directive] imports, whatever its quotes and line breaks.
(String?, String?, String) _importKey(ImportDirective directive) => (
      directive.uri.stringValue,
      directive.prefix?.name,
      directive.combinators.map((c) => c.toSource()).join(' '),
    );

/// The end of [node], or of the last comment that starts on the line it ends.
int _endOfTrailingComments(String source, AstNode node) {
  var lineEnd = source.indexOf('\n', node.end);
  if (lineEnd == -1) lineEnd = source.length;

  var end = node.end;
  Token? comment = node.endToken.next?.precedingComments;
  while (comment != null && comment.offset < lineEnd) {
    end = comment.end;
    comment = comment.next;
  }
  return end;
}
