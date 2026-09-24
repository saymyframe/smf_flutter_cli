import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contribution_engine/src/utils/match_widget_visitor.dart';

class ScopedWidgetVisitor extends GeneralizingAstVisitor<void> {
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

  MatchWidgetVisitor get _matcher =>
      MatchWidgetVisitor(targetWidget: fromWidget, onMatch: onMatch);

  @override
  void visitClassDeclaration(ClassDeclaration node) {
    if (className != null && node.name.lexeme != className) return;

    if (methodName != null) {
      final methods = node.members.whereType<MethodDeclaration>();
      for (final method in methods) {
        if (method.name.lexeme == methodName) {
          method.visitChildren(_matcher);
        }
      }
    } else {
      node.visitChildren(_matcher);
    }
  }

  // Top-level functions, such as main(), are in scope when no class is given;
  // a method name picks them out like it picks methods.
  @override
  void visitFunctionDeclaration(FunctionDeclaration node) {
    if (className != null) return;
    if (methodName != null && node.name.lexeme != methodName) return;
    node.visitChildren(_matcher);
  }

  // Without any scope, so is the rest of the file: top-level variables,
  // mixins, extensions and so on.
  @override
  void visitCompilationUnitMember(CompilationUnitMember node) {
    if (className == null && methodName == null) {
      node.visitChildren(_matcher);
    }
  }
}
