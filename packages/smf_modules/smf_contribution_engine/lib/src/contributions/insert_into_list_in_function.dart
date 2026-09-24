import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';

/// Adds an element at the start of a list literal passed as a named
/// argument, such as the `providers` of a `MultiProvider` built in `main`.
///
/// The candidates are the lists passed as a [listVariableMatch] argument
/// where an enclosing expression contains [parentExpressionMatch]; [index]
/// picks one of them in source order, and [insert] goes right after its `[`.
/// A list passed inside another named argument, such as in a `child`, is
/// never a candidate.
///
/// Throws an [Exception] when no top-level function is named [function],
/// when its body is an expression, or when there is no candidate at [index].
/// Although the function has to exist, the candidates are currently looked
/// for in the whole file, not just in its body.
///
/// Nothing checks whether [insert] is already in the list: every run adds it
/// again. Comments in the file are kept, but the whole file is reformatted.
class InsertIntoListInFunction extends Contribution {
  /// Creates a contribution that adds [insert] to a list in [function].
  const InsertIntoListInFunction({
    required super.file,
    required this.function,
    required this.listVariableMatch,
    required this.parentExpressionMatch,
    required this.insert,
    this.index = 0,
  });

  /// The name of the top-level function that holds the list, such as
  /// `main`.
  final String function;

  /// The name of the argument that takes the list, such as `providers`; a
  /// trailing colon is ignored.
  final String listVariableMatch;

  /// Text that an expression around the list must contain, such as
  /// `MultiProvider`.
  ///
  /// The check goes up to the whole file, so for now the text appearing
  /// anywhere in the file is enough.
  final String parentExpressionMatch;

  /// The element to add, with its trailing comma, such as
  /// `Provider(create: (_) => Logger()),`. [PatchEngine] renders its
  /// placeholders.
  final String insert;

  /// Which of the matching lists to change, counting from zero in source
  /// order.
  final int index;

  @override
  Future<String> apply(String original) async {
    final result = parseString(content: original);
    final unit = result.unit;

    final targetFunction =
        unit.declarations.whereType<FunctionDeclaration>().firstWhere(
              (f) => f.name.lexeme == function,
              orElse: () => throw Exception('Function $function not found'),
            );

    final body = targetFunction.functionExpression.body;
    if (body is! BlockFunctionBody) {
      throw Exception('Function body is not a block');
    }

    final fullContent = original;
    final childrenMatches = <ListLiteral>[];

    unit.visitChildren(
      _Visitor(
        listVariableMatch: listVariableMatch,
        parentMatch: parentExpressionMatch,
        collector: childrenMatches.add,
      ),
    );

    if (childrenMatches.length <= index) {
      throw Exception('List match not found at index $index');
    }

    final targetList = childrenMatches[index];
    final start = targetList.leftBracket.end;
    final updated = fullContent.replaceRange(start, start, '\n  $insert');

    return dartFormater.format(updated);
  }
}

class _Visitor extends RecursiveAstVisitor<void> {
  _Visitor({
    required this.listVariableMatch,
    required this.parentMatch,
    required this.collector,
  });
  final String listVariableMatch;
  final String parentMatch;
  final void Function(ListLiteral) collector;

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name != listVariableMatch.replaceAll(':', '')) return;
    final expression = node.expression;
    if (expression is ListLiteral && _matchesParent(node)) {
      collector(expression);
    }
  }

  bool _matchesParent(AstNode node) {
    AstNode? current = node;
    while (current != null) {
      if (current.toSource().contains(parentMatch)) {
        return true;
      }
      current = current.parent;
    }
    return false;
  }
}
