import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_contribution_engine/src/utils/list_inserts.dart';

/// Adds an element at the start of a list literal passed as a named
/// argument, such as the `providers` of a `MultiProvider` built in `main`.
///
/// The target is the first top-level function named [function]. In its body,
/// the candidates are the lists passed as a [listVariableMatch] argument,
/// nested ones included, where an enclosing expression contains
/// [parentExpressionMatch]; [index] picks one of them in source order, and
/// [insert] goes right after its `[`.
///
/// Throws an [Exception] when no top-level function is named [function],
/// when its body is an expression, or when there is no candidate at [index].
///
/// When the list already has every element of [insert], as the parser prints
/// them, the file is returned as it is, so running it again changes nothing.
/// Comments in the file are kept, but the whole file is reformatted.
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

    final childrenMatches = <ListLiteral>[];

    body.visitChildren(
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
    if (ListInsert.parse(insert)?.isIn(targetList) ?? false) return original;

    final start = targetList.leftBracket.end;
    final updated = original.replaceRange(start, start, '\n  $insert');

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
    final expression = node.expression;
    if (node.name.label.name == listVariableMatch.replaceAll(':', '') &&
        expression is ListLiteral &&
        _matchesParent(node)) {
      collector(expression);
    }
    super.visitNamedExpression(node);
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
