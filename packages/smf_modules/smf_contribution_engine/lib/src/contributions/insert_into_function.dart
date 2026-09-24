import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contribution_engine/src/contribution.dart';

/// Inserts statements into the body of a top-level function, next to the
/// statements that contain an anchor text.
///
/// The target is the first top-level function named [function]; methods
/// don't count. [insert] goes before each statement of its body whose source
/// contains [beforeStatement], and after each one that contains
/// [afterStatement], the source being the statement as the parser prints it.
/// Only the statements directly in the body are checked, not those nested in
/// blocks, and when none matches nothing is inserted.
///
/// Throws an [Exception] when the function is missing or has an expression
/// body, and a `FormatterException` when [insert] leaves invalid code.
///
/// The body is rebuilt from the source of its statements, so the comments and
/// blank lines in it are lost, and the whole file is reformatted. Nothing
/// checks whether [insert] is already there: every run adds it again.
class InsertIntoFunction extends Contribution {
  /// Creates a contribution that inserts [insert] into [function].
  ///
  /// At least one of [beforeStatement] and [afterStatement] is required.
  const InsertIntoFunction({
    required super.file,
    required this.function,
    required this.insert,
    this.beforeStatement,
    this.afterStatement,
  }) : assert(
          beforeStatement != null || afterStatement != null,
          'Either beforeStatement or afterStatement must be provided',
        );

  /// The name of the top-level function to patch, such as `main`.
  final String function;

  /// Text that marks the statements to insert before, such as `runApp(`.
  final String? beforeStatement;

  /// Text that marks the statements to insert after, such as
  /// `WidgetsFlutterBinding.ensureInitialized`.
  final String? afterStatement;

  /// The statements to insert. `PatchEngine` renders its placeholders.
  final String insert;

  @override
  Future<String> apply(String original) async {
    final result = parseString(content: original);
    final unit = result.unit;

    final targetFunction =
        unit.declarations.whereType<FunctionDeclaration>().firstWhere(
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
