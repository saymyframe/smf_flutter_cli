import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';

class InsertIntoListInMethodInClass extends Contribution {
  const InsertIntoListInMethodInClass({
    required super.file,
    required this.className,
    required this.method,
    required this.listVariableMatch,
    required this.parentExpressionMatch,
    required this.insert,
    this.index = 0,
  });

  final String className;
  final String method;
  final String listVariableMatch;
  final String parentExpressionMatch;
  final int index;
  final String insert;

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

    final matches = <ListLiteral>[];

    body.visitChildren(
      _ListLiteralVisitor(
        match: listVariableMatch,
        parentMatch: parentExpressionMatch,
        onMatch: (list) => matches.add(list),
      ),
    );

    if (matches.length <= index) {
      throw Exception('No matching list found at index $index');
    }

    final targetList = matches[index];
    final updated = original.replaceRange(
      targetList.rightBracket.offset,
      targetList.rightBracket.offset,
      '\n$insert',
    );

    return dartFormater.format(updated);
  }
}

class _ListLiteralVisitor extends RecursiveAstVisitor<void> {
  final String match;
  final String parentMatch;
  final void Function(ListLiteral) onMatch;

  _ListLiteralVisitor({
    required this.match,
    required this.parentMatch,
    required this.onMatch,
  });

  @override
  void visitNamedExpression(NamedExpression node) {
    if (node.name.label.name == match && node.expression is ListLiteral) {
      AstNode? parent = node;
      while (parent != null) {
        if (parent.toSource().contains(parentMatch)) {
          onMatch(node.expression as ListLiteral);
          break;
        }
        parent = parent.parent;
      }
    }
    super.visitNamedExpression(node);
  }
}
