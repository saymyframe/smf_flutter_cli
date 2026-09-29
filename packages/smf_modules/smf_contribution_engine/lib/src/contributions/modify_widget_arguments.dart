import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_contribution_engine/src/utils/match_widget_visitor.dart';

/// Replaces the source from `offset` to `end` with `text`.
typedef _Edit = ({int offset, int end, String text});

/// Removes, overrides and appends named arguments of a widget, such as
/// swapping `home` for `routerConfig` on `MaterialApp.router`.
///
/// Every instance of [widgetName] in the file is changed: the arguments named
/// in [removeArgs] go with their comma, those in [addArgs] that the widget
/// already has get the new value, and the rest of [addArgs] are appended,
/// keeping a trailing comma at the end of the list. Each matched widget loses
/// its `const` (or `new`), since the new arguments need not be constant, and
/// so do the widget creations and collection literals around it whose
/// `const` makes it constant; a `const` declaration around it stays. An
/// edit inside an argument that an outer widget removes or overrides goes
/// away with that argument.
///
/// Without a matching widget nothing is edited. Only the changed arguments
/// are touched, so the others and their comments stay as written, but the
/// whole file is reformatted. Running it again changes nothing: the removed
/// arguments are gone, and [addArgs] overrides what it added instead of
/// repeating it.
class ModifyWidgetArguments extends Contribution {
  /// Creates a contribution that changes the arguments of [widgetName].
  const ModifyWidgetArguments({
    required super.file,
    required this.widgetName,
    this.removeArgs = const [],
    this.addArgs = const {},
  });

  /// The name of the widget to change, such as `Text`.
  ///
  /// It is matched against the type name as parsed without resolution: an
  /// import prefix doesn't count, and `MaterialApp.router()` reads as the
  /// type `router`. Widgets created without `const` or `new`, such as
  /// `Text('a')`, parse as calls and are found by the same name when the
  /// call names a class, going by its capital letter: `m.Text('a')` and
  /// `MaterialApp.router()` count, `delegate.builder()` doesn't.
  final String widgetName;

  /// The names of the named arguments to remove, such as `home`.
  final List<String> removeArgs;

  /// Named arguments to set: one the widget already has gets the new value,
  /// the others are appended.
  ///
  /// Maps each name to the source of its value, such as
  /// `{'routerConfig': 'router'}`. [PatchEngine] renders the placeholders in
  /// both.
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
    // Of two edits that start together, the wider one comes first, so that
    // the argument that starts with `const` goes rather than the `const`.
    edits.sort(
      (a, b) => a.offset != b.offset
          ? a.offset.compareTo(b.offset)
          : b.end.compareTo(a.end),
    );
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

  /// The edits to the source of [creation]. Only the arguments that change
  /// are touched, so the rest, comments included, stays as written.
  List<_Edit> _editsFor(WidgetCreation creation) {
    final arguments = creation.argumentList.arguments;
    final kept = arguments.where((arg) => !_isRemoved(arg)).toList();
    return [
      ..._constEdits(creation),
      for (final arg in arguments.where(_isRemoved)) _removal(arg, kept),
      ..._additions(creation.argumentList, kept),
    ];
  }

  bool _isRemoved(Expression arg) =>
      arg is NamedExpression && removeArgs.contains(arg.name.label.name);

  /// The edits that drop the `const` (or `new`) of [creation], and each
  /// `const` around it that makes it constant: the new arguments need not
  /// be constant.
  static List<_Edit> _constEdits(WidgetCreation creation) => [
        for (final keyword in [
          if (creation.keyword case final keyword?) keyword,
          ..._constsAround(creation.expression),
        ])
          (offset: keyword.offset, end: keyword.next!.offset, text: ''),
      ];

  /// The edit that removes [arg] with its comma. The last argument may have
  /// none, and then takes the comma after the last of [kept] instead.
  static _Edit _removal(Expression arg, List<Expression> kept) {
    final next = arg.endToken.next!;
    final (start, end) = next.type == TokenType.COMMA
        ? (arg.offset, next.end)
        : (kept.lastOrNull?.end ?? arg.offset, arg.end);
    return (offset: start, end: end, text: '');
  }

  /// The edits of [addArgs] to [argumentList], whose arguments after the
  /// removals are [kept]: a value replaces that of a kept argument of its
  /// name, and the other arguments go at the end of the list.
  List<_Edit> _additions(ArgumentList argumentList, List<Expression> kept) {
    final keptByName = {
      for (final arg in kept.whereType<NamedExpression>())
        arg.name.label.name: arg.expression,
    };
    final edits = <_Edit>[];
    final appended = <String>[];
    addArgs.forEach((name, value) {
      final existing = keptByName[name];
      if (existing != null) {
        edits.add((offset: existing.offset, end: existing.end, text: value));
      } else {
        appended.add('$name: $value');
      }
    });
    if (appended.isEmpty) return edits;

    var text = appended.join(', ');
    final rightParenthesis = argumentList.rightParenthesis;
    if (kept.isNotEmpty) {
      // A trailing comma stays at the end of the list.
      text = rightParenthesis.previous?.type == TokenType.COMMA
          ? ' $text,'
          : ', $text';
    }
    final offset = rightParenthesis.offset;
    return edits..add((offset: offset, end: offset, text: text));
  }
}

/// The `const` of each widget creation and collection literal around [node],
/// each of which makes [node] constant.
Iterable<Token> _constsAround(AstNode node) sync* {
  for (var parent = node.parent; parent != null; parent = parent.parent) {
    if (parent
        case InstanceCreationExpression(keyword: final keyword?) ||
            TypedLiteral(constKeyword: final keyword?)
        when keyword.keyword == Keyword.CONST) {
      yield keyword;
    }
  }
}
