import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_contribution_engine/src/utils/match_widget_visitor.dart';

class ModifyWidgetArguments extends Contribution {
  const ModifyWidgetArguments({
    required super.file,
    required this.widgetName,
    this.removeArgs = const [],
    this.addArgs = const {},
  });

  final String widgetName;
  final List<String> removeArgs;
  final Map<String, String> addArgs;

  @override
  Future<String> apply(String original) async {
    final parsed = parseString(content: original);
    final unit = parsed.unit;

    final edits = <InstanceCreationExpression>[];
    unit.visitChildren(
      MatchWidgetVisitor(
        targetWidget: widgetName,
        onMatch: (node) => edits.add(node),
      ),
    );

    var result = original;
    for (final node in edits.reversed) {
      final newArgs = node.argumentList.arguments
          .where((arg) {
            return !(arg is NamedExpression &&
                removeArgs.contains(arg.name.label.name));
          })
          .map((e) => e.toSource())
          .toList();

      addArgs.forEach((key, value) {
        newArgs.add("$key: $value");
      });

      final newArgsStr = newArgs.join(', ');
      final newSource = '${node.constructorName.toSource()}($newArgsStr)';

      result = result.replaceRange(node.offset, node.end, newSource);
    }

    return dartFormater.format(result);
  }
}
