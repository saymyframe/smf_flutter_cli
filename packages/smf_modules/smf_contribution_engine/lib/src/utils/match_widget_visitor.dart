import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// A creation of a widget that [MatchWidgetVisitor] found.
final class WidgetCreation {
  WidgetCreation._(
    this.expression,
    this.name,
    this.argumentList, {
    this.keyword,
  });

  /// The whole creation, such as `const Text('a')` or `Text('a')`.
  ///
  /// Written with `const` or `new`, it is an [InstanceCreationExpression];
  /// without either, a [MethodInvocation], since the parser can't tell it
  /// from a call without resolution.
  final Expression expression;

  /// The name the widget was matched by, such as `Text` in `m.Text('a')`.
  final Token name;

  /// The arguments of the creation.
  final ArgumentList argumentList;

  /// `const` or `new`, when the creation is written with one.
  final Token? keyword;
}

/// Reports each creation of a widget named [targetWidget], outer ones before
/// those nested in them.
///
/// The AST is not resolved, so the widget is matched by the name the parser
/// sees. An import prefix doesn't count, and a named constructor reads as
/// its name: `MaterialApp.router()` as `router`. A creation without `const`
/// or `new`, such as `Text('a')`, parses as a call, which counts when it
/// names a class as a creation does, going by the capital letter that
/// starts the name of a class: `Text('a')`, `m.Text('a')` or
/// `MaterialApp.router()`, but not `delegate.builder()`, `a?.Text()` or
/// `..Text()`.
class MatchWidgetVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor that calls [onMatch] for each [targetWidget].
  MatchWidgetVisitor({required this.targetWidget, required this.onMatch});

  /// The name to look for, such as `Text`.
  final String targetWidget;

  /// Called with each matching widget creation.
  final void Function(WidgetCreation) onMatch;

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final name = node.constructorName.type.name;
    if (name.lexeme == targetWidget) {
      onMatch(
        WidgetCreation._(node, name, node.argumentList, keyword: node.keyword),
      );
    }

    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitMethodInvocation(MethodInvocation node) {
    final name = node.methodName.token;
    if (name.lexeme == targetWidget && _mayCreate(node)) {
      onMatch(WidgetCreation._(node, name, node.argumentList));
    }

    super.visitMethodInvocation(node);
  }

  /// Whether [node] could create an instance, going by the capitalized names
  /// of classes: `Text('a')` or `m.Text('a')` for an unnamed constructor,
  /// and `MaterialApp.router()` or `m.MaterialApp.router()` for a named one.
  static bool _mayCreate(MethodInvocation node) => switch (node) {
        MethodInvocation(target: null, operator: null) ||
        MethodInvocation(
          target: SimpleIdentifier(),
          operator: Token(type: TokenType.PERIOD),
        )
            when _isClassName(node.methodName.name) =>
          true,
        MethodInvocation(
          target: SimpleIdentifier(:final name) ||
              PrefixedIdentifier(identifier: SimpleIdentifier(:final name)),
          operator: Token(type: TokenType.PERIOD),
        )
            when _isClassName(name) =>
          true,
        _ => false,
      };

  /// Whether [name] is capitalized, as the name of a class, private or not.
  static bool _isClassName(String name) =>
      RegExp(r'^[_$]*[A-Z]').hasMatch(name);
}
