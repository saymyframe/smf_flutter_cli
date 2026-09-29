import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';

/// The elements that an insert adds to a list literal, such as
/// `Locale('uk'),`, parsed in a list literal of their own.
final class ListInsert {
  ListInsert._(
    this.source,
    this.elements, {
    required int end,
    required int? trailingComma,
  })  : _end = end,
        _trailingComma = trailingComma;

  /// Parses [insert], or returns null when it holds no element or doesn't
  /// parse as the elements of a list.
  static ListInsert? parse(String insert) {
    // In an async function, since an element may await.
    const prefix = 'Future<Object> f() async => [\n';
    final parsed = parseString(
      content: '$prefix$insert\n];',
      throwIfDiagnostics: false,
    );
    if (parsed.unit.declarations
        case [
          FunctionDeclaration(
            functionExpression: FunctionExpression(
              body: ExpressionFunctionBody(expression: final ListLiteral list),
            ),
          ),
        ] when parsed.errors.isEmpty && list.elements.isNotEmpty) {
      final beforeBracket = list.rightBracket.previous!;
      return ListInsert._(
        insert,
        [for (final e in list.elements) e.toSource()],
        end: list.elements.last.end - prefix.length,
        trailingComma: beforeBracket.type == TokenType.COMMA
            ? beforeBracket.offset - prefix.length
            : null,
      );
    }
    return null;
  }

  /// The insert as written.
  final String source;

  /// The source of each element, as the parser prints it.
  final List<String> elements;

  /// Where the last element ends in [source].
  final int _end;

  /// Where the comma after the last element is in [source], if it has one.
  final int? _trailingComma;

  /// Whether [list] already has each of [elements], as the parser prints
  /// them.
  bool isIn(ListLiteral list) {
    final existing = {for (final e in list.elements) e.toSource()};
    return elements.every(existing.contains);
  }

  /// [source] with a comma right after its last element when [comma] is
  /// true, and without one when it is false.
  String withTrailingComma({required bool comma}) {
    if (_trailingComma case final offset?) {
      return comma ? source : source.replaceRange(offset, offset + 1, '');
    }
    return comma ? source.replaceRange(_end, _end, ',') : source;
  }
}
