import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_contribution_engine/src/utils/match_widget_visitor.dart';

/// Replaces the source from [offset] to [end] with [text].
typedef _Edit = ({int offset, int end, String text});

class ModifyWidgetArguments extends Contribution {
  const ModifyWidgetArguments({
    required super.file,
    required this.widgetName,
    this.removeArgs = const [],
    this.addArgs = const {},
  });

  final String widgetName;
  final List<String> removeArgs;

  /// Named arguments to set: one the widget already has gets the new value,
  /// the others are appended.
  final Map<String, String> addArgs;

  @override
  Future<String> apply(String original) async {
    final parsed = parseString(content: original);
    final unit = parsed.unit;

    final edits = <_Edit>[];
    unit.visitChildren(
      MatchWidgetVisitor(
        targetWidget: widgetName,
        onMatch: (node) => edits.addAll(_editsFor(node)),
      ),
    );

    // An edit inside another one, such as in a nested widget passed as an
    // argument that is removed or replaced, goes away with that argument.
    edits.sort((a, b) => a.offset.compareTo(b.offset));
    final applied = <_Edit>[];
    for (final edit in edits) {
      if (applied.isEmpty || edit.offset >= applied.last.end) {
        applied.add(edit);
      }
    }

    // Edit from the end so the offsets of the earlier edits stay valid.
    var result = original;
    for (final edit in applied.reversed) {
      result = result.replaceRange(edit.offset, edit.end, edit.text);
    }

    return dartFormater.format(result);
  }

  /// The edits to [node]'s source. Only the arguments that change are
  /// touched, so the rest, comments included, stays as written.
  List<_Edit> _editsFor(InstanceCreationExpression node) {
    final argumentList = node.argumentList;
    final arguments = argumentList.arguments;
    bool isRemoved(Expression arg) =>
        arg is NamedExpression && removeArgs.contains(arg.name.label.name);
    final kept = arguments.where((arg) => !isRemoved(arg)).toList();

    final edits = <_Edit>[
      // The new arguments need not be constant, so `const` (or `new`) goes.
      if (node.keyword case final keyword?)
        (offset: keyword.offset, end: node.constructorName.offset, text: ''),
    ];

    for (final arg in arguments.where(isRemoved)) {
      // The argument goes with its comma. The last one may have none, and
      // then takes the comma after the last kept argument instead.
      final next = arg.endToken.next!;
      final (start, end) = next.type == TokenType.COMMA
          ? (arg.offset, next.end)
          : (kept.lastOrNull?.end ?? arg.offset, arg.end);
      edits.add((offset: start, end: end, text: ''));
    }

    final keptByName = {
      for (final arg in kept.whereType<NamedExpression>())
        arg.name.label.name: arg.expression,
    };
    final appended = <String>[];
    addArgs.forEach((name, value) {
      final existing = keptByName[name];
      if (existing != null) {
        edits.add((offset: existing.offset, end: existing.end, text: value));
      } else {
        appended.add('$name: $value');
      }
    });

    if (appended.isNotEmpty) {
      var text = appended.join(', ');
      final rightParenthesis = argumentList.rightParenthesis;
      if (kept.isNotEmpty) {
        // A trailing comma stays at the end of the list.
        text = rightParenthesis.previous?.type == TokenType.COMMA
            ? ' $text,'
            : ', $text';
      }
      final offset = rightParenthesis.offset;
      edits.add((offset: offset, end: offset, text: text));
    }

    return edits;
  }
}
