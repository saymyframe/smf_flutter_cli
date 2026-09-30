import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:smf_contribution_engine/src/contribution.dart';
import 'package:smf_contribution_engine/src/utils/bodies.dart';
import 'package:smf_contribution_engine/src/utils/statement_inserts.dart';

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
/// When the body already has the statements of [insert] in a row, as the
/// parser prints them, nothing is inserted, so running it again changes
/// nothing; an insert of nothing but comments is added on every run.
///
/// Only the new lines are added: the comments and blank lines of the body
/// stay, and a comment above a statement stays with it. The whole file is
/// then reformatted, or returned as it is when nothing is inserted.
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

    final body = functionBodyIn(unit, function);

    final updated = insertStatements(
      original,
      body.block,
      insert: insert,
      before: beforeStatement,
      after: afterStatement,
    );
    return updated == null ? original : dartFormater.format(updated);
  }
}
