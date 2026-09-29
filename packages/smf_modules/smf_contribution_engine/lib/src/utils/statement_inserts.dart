import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contribution_engine/src/utils/source_edits.dart';

/// Returns [source] with [insert] added to [block]: before each statement
/// directly in it whose source, as the parser prints it, contains [before],
/// and after each one that contains [after].
///
/// Only the new lines are added, so the comments and blank lines of the block
/// stay. A comment above a statement stays with it, and one that trails a
/// statement stays on its line.
///
/// Returns null when no statement contains an anchor.
String? insertStatements(
  String source,
  Block block, {
  required String insert,
  String? before,
  String? after,
}) {
  final insertions = <Insertion>[
    for (final statement in block.statements) ...[
      if (before != null && statement.toSource().contains(before))
        insertionBefore(source, statement.beginToken, insert),
      if (after != null && statement.toSource().contains(after))
        insertionAfter(source, statement.endToken, insert),
    ],
  ];
  if (insertions.isEmpty) return null;
  return applyInsertions(source, insertions);
}
