import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';

/// Inserts statements into the body of a method, after the statements that
/// contain an anchor text, such as a call in `initState` after
/// `super.initState();`.
///
/// The target is the first method named [method] in the first class named
/// [className]. [insert] goes after each statement of its body whose source,
/// as the parser prints it, contains [afterStatement]. Only the statements
/// directly in the body are checked, not those nested in blocks, and when
/// none matches nothing is inserted.
///
/// Throws an [Exception] when the class or the method is missing or the
/// method body is an expression, and a `FormatterException` when [insert]
/// leaves invalid code.
///
/// The body is rebuilt from the source of its statements, so the comments and
/// blank lines in it are lost, and the whole file is reformatted. Nothing
/// checks whether [insert] is already there: every run adds it again.
class InsertIntoMethodInClass extends Contribution {
  /// Creates a contribution that inserts [insert] into [method] of
  /// [className].
  const InsertIntoMethodInClass({
    required super.file,
    required this.className,
    required this.method,
    required this.afterStatement,
    required this.insert,
  });

  /// The name of the class that declares [method], such as `_HomePageState`.
  final String className;

  /// The name of the method to patch, such as `initState`.
  final String method;

  /// Text that marks the statements to insert after, such as
  /// `super.initState()`.
  final String afterStatement;

  /// The statements to insert. [PatchEngine] renders its placeholders.
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
