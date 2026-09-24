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

    var result = original;
    for (final node in edits.reversed) {
      final oldSource = node.toSource();
      final newSource = oldSource.replaceFirst(fromWidget, toWidget);
      result = result.replaceRange(node.offset, node.end, newSource);
    }

    return dartFormater.format(result);
  }
}
