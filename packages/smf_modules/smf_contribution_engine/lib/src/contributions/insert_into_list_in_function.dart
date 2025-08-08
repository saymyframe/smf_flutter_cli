import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';

class InsertIntoListInFunction extends Contribution {
  const InsertIntoListInFunction({
    required super.file,
    required this.function,
    required this.listVariableMatch,
    required this.parentExpressionMatch,
    required this.insert,
    this.index = 0,
  });

  final String function;
  final String listVariableMatch;
  final String parentExpressionMatch;
  final String insert;
  final int index;

  @override
  Future<String> apply(String original) async {
    final result = parseString(content: original);
    final unit = result.unit;

    final targetFunction = unit.declarations
        .whereType<FunctionDeclaration>()
        .firstWhere(
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
        collector: (list) => childrenMatches.add(list),
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
  final String listVariableMatch;
  final String parentMatch;
  final void Function(ListLiteral) collector;

  _Visitor({
    required this.listVariableMatch,
    required this.parentMatch,
    required this.collector,
  });

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
