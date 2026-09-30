import 'package:analyzer/dart/ast/ast.dart';

/// The block body of the first top-level function named [function] in
/// [unit]; methods don't count.
///
/// Throws when there is no such function, or when its body is not a block,
/// such as an arrow body.
BlockFunctionBody functionBodyIn(CompilationUnit unit, String function) {
  final declaration =
      unit.declarations.whereType<FunctionDeclaration>().firstWhere(
            (f) => f.name.lexeme == function,
            orElse: () => throw Exception('Function $function not found'),
          );
  final body = declaration.functionExpression.body;
  if (body is! BlockFunctionBody) {
    throw Exception('Function body is not a block');
  }
  return body;
}

/// The block body of the method [method] of the first class named
/// [className] in [unit].
///
/// Throws when there is no such class or method, or when the body of the
/// method is not a block, such as an arrow body.
BlockFunctionBody methodBodyIn(
  CompilationUnit unit, {
  required String className,
  required String method,
}) {
  final declaration =
      unit.declarations.whereType<ClassDeclaration>().firstWhere(
            (c) => c.namePart.typeName.lexeme == className,
            orElse: () => throw Exception('Class $className not found'),
          );
  final member =
      declaration.body.members.whereType<MethodDeclaration>().firstWhere(
            (m) => m.name.lexeme == method,
            orElse: () =>
                throw Exception('Method $method not found in class $className'),
          );
  final body = member.body;
  if (body is! BlockFunctionBody) {
    throw Exception('Method body is not a block');
  }
  return body;
}
