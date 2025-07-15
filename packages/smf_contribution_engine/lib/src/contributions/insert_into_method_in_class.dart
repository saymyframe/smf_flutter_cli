import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';

class InsertIntoMethodInClass extends Contribution {
  final String className;
  final String method;
  final String afterStatement;
  final String insert;

  InsertIntoMethodInClass({
    required super.file,
    required this.className,
    required this.method,
    required this.afterStatement,
    required this.insert,
  });

  @override
  Future<String> apply(String original) async {
    final result = parseString(content: original);
    final unit = result.unit;

    final targetClass = unit.declarations
        .whereType<ClassDeclaration>()
        .firstWhere(
          (c) => c.name.lexeme == className,
          orElse: () => throw Exception('Class $className not found'),
        );

    final targetMethod = targetClass.members
        .whereType<MethodDeclaration>()
        .firstWhere(
          (m) => m.name.lexeme == method,
          orElse: () =>
              throw Exception('Method $method not found in class $className'),
        );

    final body = targetMethod.body;
    if (body is! BlockFunctionBody) {
      throw Exception('Method body is not a block');
    }

    final buffer = StringBuffer();
    final statements = body.block.statements;
    for (final stmt in statements) {
      buffer.writeln(stmt.toSource());
      if (stmt.toSource().contains(afterStatement)) {
        buffer.writeln(insert);
      }
    }

    final updatedBody = '{\n$buffer}';
    final start = body.block.leftBracket.offset;
    final end = body.block.rightBracket.offset;

    final updated = original.replaceRange(start, end + 1, updatedBody);
    return dartFormater.format(updated);
  }
}
