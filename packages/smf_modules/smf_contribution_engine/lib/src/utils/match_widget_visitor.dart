import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Reports each creation of a widget named [targetWidget], outer ones before
/// those nested in them.
///
/// The AST is not resolved, so the widget is matched by the type name the
/// parser sees: an import prefix doesn't count, and `MaterialApp.router()`
/// reads as the type `router`. Only creations written with `const` or `new`
/// are seen, since `Text('a')` alone parses as a method call.
class MatchWidgetVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor that calls [onMatch] for each [targetWidget].
  MatchWidgetVisitor({required this.targetWidget, required this.onMatch});

  /// The type name to look for, such as `Text`.
  final String targetWidget;

  /// Called with each matching widget creation.
  final void Function(InstanceCreationExpression) onMatch;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final type = node.constructorName.type;
    // ignore: deprecated_member_use, name2's replacement isn't in analyzer 7.x, which this package still supports.
    if (type.name2.lexeme == targetWidget) {
      onMatch(node);
    }

    super.visitInstanceCreationExpression(node);
  }
}
