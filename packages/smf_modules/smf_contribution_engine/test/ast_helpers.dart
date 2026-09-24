/// Helpers that inspect patched sources through the analyzer AST, so tests can
/// assert on structure without depending on the formatter's layout.
library;

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Parses [source], throwing if it is not syntactically valid Dart.
CompilationUnit parseValid(String source) => parseString(content: source).unit;

/// The `toSource()` of each directive in [source].
List<String> directivesOf(String source) =>
    parseValid(source).directives.map((d) => d.toSource()).toList();

/// The `toSource()` of each statement in the top-level function [name].
List<String> functionStatements(String source, String name) {
  final function = parseValid(source)
      .declarations
      .whereType<FunctionDeclaration>()
      .singleWhere((f) => f.name.lexeme == name);
  return _statements(function.functionExpression.body);
}

/// The `toSource()` of each statement in [method] of [className].
List<String> methodStatements(
  String source,
  String className,
  String method,
) {
  final classDeclaration = parseValid(source)
      .declarations
      .whereType<ClassDeclaration>()
      .singleWhere((c) => c.name.lexeme == className);
  final methodDeclaration = classDeclaration.members
      .whereType<MethodDeclaration>()
      .singleWhere((m) => m.name.lexeme == method);
  return _statements(methodDeclaration.body);
}

/// The elements of every list literal passed as the named argument [name],
/// in source order.
List<List<String>> namedListsOf(String source, String name) {
  final lists = <List<String>>[];
  parseValid(source).accept(_NamedListCollector(name, lists));
  return lists;
}

List<String> _statements(FunctionBody body) =>
    (body as BlockFunctionBody).block.statements.map((s) {
      return s.toSource();
    }).toList();

class _NamedListCollector extends RecursiveAstVisitor<void> {
  _NamedListCollector(this.name, this.lists);

  final String name;
  final List<List<String>> lists;

  @override
  void visitNamedExpression(NamedExpression node) {
    final expression = node.expression;
    if (node.name.label.name == name && expression is ListLiteral) {
      lists.add(expression.elements.map((e) => e.toSource()).toList());
    }
    super.visitNamedExpression(node);
  }
}
