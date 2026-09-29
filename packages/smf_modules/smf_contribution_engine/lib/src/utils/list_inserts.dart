import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';

/// The elements that an insert adds to a list literal, such as
/// `Locale('uk'),`, parsed in a list literal of their own.
final class ListInsert {
  ListInsert._(this.elements);

  /// Parses [insert], or returns null when it holds no element or doesn't
  /// parse as the elements of a list.
  static ListInsert? parse(String insert) {
    // In an async function, since an element may await.
    final parsed = parseString(
      content: 'Future<Object> f() async => [\n$insert\n];',
      throwIfDiagnostics: false,
    );
    if (parsed.unit.declarations
        case [
          FunctionDeclaration(
            functionExpression: FunctionExpression(
              body: ExpressionFunctionBody(
                expression: ListLiteral(:final elements),
              ),
            ),
          ),
        ] when parsed.errors.isEmpty && elements.isNotEmpty) {
      return ListInsert._([for (final e in elements) e.toSource()]);
    }
    return null;
  }

  /// The source of each element, as the parser prints it.
  final List<String> elements;

  /// Whether [list] already has each of [elements], as the parser prints
  /// them.
  bool isIn(ListLiteral list) {
    final existing = {for (final e in list.elements) e.toSource()};
    return elements.every(existing.contains);
  }
}
