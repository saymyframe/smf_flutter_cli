import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contribution_engine/src/contribution.dart';

class InsertIntoFunction extends Contribution {
  const InsertIntoFunction({
    required super.file,
    required this.function,
    this.beforeStatement,
    this.afterStatement,
    required this.insert,
  }) : assert(
         beforeStatement != null || afterStatement != null,
         'Either beforeStatement or afterStatement must be provided',
       );

  final String function;
  final String? beforeStatement;
  final String? afterStatement;
  final String insert;

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

    final buffer = StringBuffer();
    final statements = body.block.statements;
    for (final stmt in statements) {
      if (beforeStatement != null &&
          stmt.toSource().contains(beforeStatement!)) {
        buffer.writeln(insert);
      }

      buffer.writeln(stmt.toSource());

      if (afterStatement != null && stmt.toSource().contains(afterStatement!)) {
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
