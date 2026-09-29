import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/token.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_contribution_engine/src/utils/scoped_widget_visitor.dart';

/// Replaces the type name of a widget, such as `MaterialApp` with
/// `MaterialApp.router`, keeping its arguments.
///
/// The scope narrows with [className] and [methodName]: with both, only that
/// method of that class is searched; with just [className], the whole class;
/// with just [methodName], the methods and top-level functions of that name;
/// with neither, the whole file. Every instance of [fromWidget] in the scope,
/// nested ones included, gets [toWidget] in place of its type name, so
/// `const`, an import prefix and the arguments stay as written.
///
/// Without a matching widget nothing is edited, but the whole file is
/// reformatted either way. Running it again changes nothing as long as
/// [toWidget] doesn't match [fromWidget] itself, as `MaterialApp.router`
/// doesn't match `MaterialApp`.
class ReplaceWidget extends Contribution {
  /// Creates a contribution that turns [fromWidget] into [toWidget].
  const ReplaceWidget({
    required super.file,
    required this.fromWidget,
    required this.toWidget,
    this.className,
    this.methodName,
  });

  /// The name of the widget to replace, such as `MaterialApp`.
  ///
  /// It is matched against the type name as parsed without resolution: an
  /// import prefix doesn't count, and `MaterialApp.router()` reads as the
  /// type `router`. Widgets created without `const` or `new`, such as
  /// `Text('a')`, parse as calls and are found by the same name when the
  /// call names a class, going by its capital letter: `m.Text('a')` and
  /// `MaterialApp.router()` count, `delegate.builder()` doesn't.
  final String fromWidget;

  /// The source that takes the place of the type name, such as
  /// `MaterialApp.router`. [PatchEngine] renders its placeholders.
  final String toWidget;

  /// The class to limit the search to, if any.
  final String? className;

  /// The method to limit the search to, if any. Without [className],
  /// top-level functions of that name are searched too.
  final String? methodName;

  @override
  Future<String> apply(String original) async {
    final parsed = parseString(content: original);
    final unit = parsed.unit;

    final names = <Token>[];
    unit.visitChildren(
      ScopedWidgetVisitor(
        fromWidget: fromWidget,
        className: className,
        methodName: methodName,
        onMatch: (creation) => names.add(creation.name),
      ),
    );

    // Only the type name is replaced, so the rest of the widget stays as
    // written. Matches come in source order: editing from the last one keeps
    // the offsets of the others valid, nested widgets included.
    var result = original;
    for (final name in names.reversed) {
      result = result.replaceRange(name.offset, name.end, toWidget);
    }

    return dartFormater.format(result);
  }
}
