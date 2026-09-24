import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contribution_engine/src/utils/match_widget_visitor.dart';

/// Runs a [MatchWidgetVisitor] for [fromWidget] over the declarations that
/// [className] and [methodName] select.
///
/// With both, that is the methods named [methodName] of the class named
/// [className]; with just [className], the whole class; with just
/// [methodName], the methods and top-level functions of that name; with
/// neither, every declaration in the file.
class ScopedWidgetVisitor extends GeneralizingAstVisitor<void> {
  /// Creates a visitor that calls [onMatch] for each [fromWidget] in scope.
  const ScopedWidgetVisitor({
    required this.fromWidget,
    required this.className,
    required this.methodName,
    required this.onMatch,
  });

  /// The type name to look for, as [MatchWidgetVisitor.targetWidget].
  final String fromWidget;

  /// The class to limit the search to, if any.
  final String? className;

  /// The method, or top-level function without [className], to limit the
  /// search to, if any.
  final String? methodName;

  /// Called with each matching widget creation in scope.
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
