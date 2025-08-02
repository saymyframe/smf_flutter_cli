import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class MatchWidgetVisitor extends RecursiveAstVisitor<void> {
  MatchWidgetVisitor({required this.targetWidget, required this.onMatch});

  final String targetWidget;
  final void Function(InstanceCreationExpression) onMatch;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type;
    if (type.name2.lexeme == targetWidget) {
      onMatch(node);
    }

    super.visitInstanceCreationExpression(node);
  }
}
