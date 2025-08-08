import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contribution_engine/src/utils/match_widget_visitor.dart';

class ScopedWidgetVisitor extends RecursiveAstVisitor<void> {
  const ScopedWidgetVisitor({
    required this.fromWidget,
    required this.className,
    required this.methodName,
    required this.onMatch,
  });

  final String fromWidget;
  final String? className;
  final String? methodName;
  final void Function(InstanceCreationExpression) onMatch;

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (className != null && node.name.lexeme != className) return;

    if (methodName != null) {
      final methods = node.members.whereType<MethodDeclaration>();
      for (final method in methods) {
        if (method.name.lexeme == methodName) {
          method.visitChildren(
            MatchWidgetVisitor(targetWidget: fromWidget, onMatch: onMatch),
          );
        }
      }
    } else {
      node.visitChildren(
        MatchWidgetVisitor(targetWidget: fromWidget, onMatch: onMatch),
      );
    }
  }
}
