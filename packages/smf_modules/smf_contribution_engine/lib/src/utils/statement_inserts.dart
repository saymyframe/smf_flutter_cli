import 'package:analyzer/dart/analysis/utilities.dart';
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
/// Returns null when there is nothing to add: no statement contains an
/// anchor, or the statements directly in [block] already have those of
/// [insert] in a row, as the parser prints them. An insert of nothing but
/// comments is added every time.
String? insertStatements(
  String source,
  Block block, {
  required String insert,
  String? before,
  String? after,
}) {
  final inserted = _statementsOf(insert);
  final existing = block.statements.map((s) => s.toSource()).toList();
  if (inserted != null && _containsRun(existing, inserted)) return null;

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

/// The statements of [insert] as the parser prints them, or null when it
/// holds none or doesn't parse as statements.
List<String>? _statementsOf(String insert) {
  // In an async function, since the insert may await.
  final parsed = parseString(
    content: 'Future<void> f() async {\n$insert\n}',
    throwIfDiagnostics: false,
  );
  if (parsed.unit.declarations
      case [
        FunctionDeclaration(
          functionExpression: FunctionExpression(
            body: BlockFunctionBody(block: Block(:final statements)),
          ),
        ),
      ] when parsed.errors.isEmpty && statements.isNotEmpty) {
    return [for (final statement in statements) statement.toSource()];
  }
  return null;
}

/// Whether [items] has the items of [run] next to each other, in order.
bool _containsRun(List<String> items, List<String> run) {
  for (var start = 0; start + run.length <= items.length; start++) {
    var i = 0;
    while (i < run.length && items[start + i] == run[i]) {
      i++;
    }
    if (i == run.length) return true;
  }
  return false;
}
