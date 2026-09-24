import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';

/// Adds an element at the end of a list literal passed as a named argument
/// in a method, such as the `supportedLocales` of the `MaterialApp` built in
/// `MainApp.build`.
///
/// The target is the first method named [method] in the first class named
/// [className]. In its body, the candidates are the lists passed as a
/// [listVariableMatch] argument, nested ones included, where an enclosing
/// expression contains [parentExpressionMatch]; [index] picks one of them in
/// source order, and [insert] goes right before its `]`.
///
/// Throws an [Exception] when the class or the method is missing, when the
/// method body is an expression, or when there is no candidate at [index].
///
/// Nothing checks whether [insert] is already in the list: every run adds it
/// again. Comments in the file are kept, but the whole file is reformatted.
class InsertIntoListInMethodInClass extends Contribution {
  /// Creates a contribution that adds [insert] to a list in [method] of
  /// [className].
  const InsertIntoListInMethodInClass({
    required super.file,
    required this.className,
    required this.method,
    required this.listVariableMatch,
    required this.parentExpressionMatch,
    required this.insert,
    this.index = 0,
  });

  /// The name of the class that declares [method], such as `MainApp`.
  final String className;

  /// The name of the method that holds the list, such as `build`.
  final String method;

  /// The name of the argument that takes the list, such as
  /// `supportedLocales`.
  final String listVariableMatch;

  /// Text that an expression around the list must contain, such as
  /// `MaterialApp`.
  ///
  /// The check goes up to the whole file, so for now the text appearing
  /// anywhere in the file is enough.
  final String parentExpressionMatch;

  /// Which of the matching lists to change, counting from zero in source
  /// order.
  final int index;

  /// The element to add, such as `Locale('uk'),`. [PatchEngine] renders its
  /// placeholders.
  ///
  /// Nothing separates it from the last element, so a list without a
  /// trailing comma makes [apply] throw a `FormatterException`.
  final String insert;

  @override
  Future<String> apply(String original) async {
    final result = parseString(content: original);
    final unit = result.unit;

    final targetClass =
        unit.declarations.whereType<ClassDeclaration>().firstWhere(
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
        onMatch: matches.add,
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
  _ListLiteralVisitor({
    required this.match,
    required this.parentMatch,
    required this.onMatch,
  });
  final String match;
  final String parentMatch;
  final void Function(ListLiteral) onMatch;

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
