import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_contribution_engine/src/utils/list_inserts.dart';
import 'package:smf_contribution_engine/src/utils/named_lists.dart';
import 'package:smf_contribution_engine/src/utils/source_edits.dart';

/// Adds an element at the start of a list literal passed as a named
/// argument, such as the `providers` of a `MultiProvider` built in `main`.
///
/// The target is the first top-level function named [function]. In its body,
/// the candidates are the lists passed as a [listVariableMatch] argument,
/// nested ones included, to a call or widget creation that matches
/// [parentExpressionMatch]; [index] picks one of them in source order, and
/// [insert] goes first in it, above the comments that lead up to its first
/// element, with a comma after it.
///
/// Throws an [Exception] when no top-level function is named [function],
/// when its body is an expression, or when there is no candidate at [index].
///
/// When the list already has every element of [insert], as the parser prints
/// them, the file is returned as it is, so running it again changes nothing.
/// Comments in the file are kept, but the whole file is reformatted.
class InsertIntoListInFunction extends Contribution {
  /// Creates a contribution that adds [insert] to a list in [function].
  const InsertIntoListInFunction({
    required super.file,
    required this.function,
    required this.listVariableMatch,
    required this.parentExpressionMatch,
    required this.insert,
    this.index = 0,
  });

  /// The name of the top-level function that holds the list, such as
  /// `main`.
  final String function;

  /// The name of the argument that takes the list, such as `providers`; a
  /// trailing colon is ignored.
  final String listVariableMatch;

  /// Text that the call or widget creation taking the list, or one around
  /// it, has before its arguments, such as `MultiProvider`.
  ///
  /// It is matched against the source as the parser prints it, such as
  /// `const MaterialApp` or `MaterialApp.router`. The arguments don't count,
  /// so neither do the elements of the list nor the arguments next to it.
  final String parentExpressionMatch;

  /// The element to add, such as `Provider(create: (_) => Logger()),`; the
  /// comma after it is added when it has none. [PatchEngine] renders its
  /// placeholders.
  final String insert;

  /// Which of the matching lists to change, counting from zero in source
  /// order.
  final int index;

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

    final childrenMatches = <ListLiteral>[];

    body.visitChildren(
      NamedListVisitor(
        name: listVariableMatch.replaceAll(':', ''),
        parentMatch: parentExpressionMatch,
        onMatch: childrenMatches.add,
      ),
    );

    if (childrenMatches.length <= index) {
      throw Exception('List match not found at index $index');
    }

    final targetList = childrenMatches[index];
    final elements = ListInsert.parse(insert);
    if (elements?.isIn(targetList) ?? false) return original;

    final first = targetList.elements.firstOrNull;
    final insertion = first == null
        ? insertionAfter(original, targetList.leftBracket, insert)
        // A comma separates the insert from the element that follows it.
        : insertionBefore(
            original,
            first.beginToken,
            elements?.withTrailingComma(comma: true) ?? insert,
          );

    return dartFormater.format(applyInsertions(original, [insertion]));
  }
}
