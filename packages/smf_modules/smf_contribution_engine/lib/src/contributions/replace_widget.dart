import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_contribution_engine/src/utils/scoped_widget_visitor.dart';

class ReplaceWidget extends Contribution {
  const ReplaceWidget({
    required super.file,
    required this.fromWidget,
    required this.toWidget,
    this.className,
    this.methodName,
  });

  final String fromWidget;
  final String toWidget;
  final String? className;
  final String? methodName;

  @override
  Future<String> apply(String original) async {
    final parsed = parseString(content: original);
    final unit = parsed.unit;

    final edits = <InstanceCreationExpression>[];
    unit.visitChildren(
      ScopedWidgetVisitor(
        fromWidget: fromWidget,
        className: className,
        methodName: methodName,
        onMatch: (node) => edits.add(node),
      ),
    );

    // Only the type name is replaced, so the rest of the widget stays as
    // written. Matches come in source order: editing from the last one keeps
    // the offsets of the others valid, nested widgets included.
    var result = original;
    for (final node in edits.reversed) {
      // ignore: deprecated_member_use
      final name = node.constructorName.type.name2;
      result = result.replaceRange(name.offset, name.end, toWidget);
    }

    return dartFormater.format(result);
  }
}
