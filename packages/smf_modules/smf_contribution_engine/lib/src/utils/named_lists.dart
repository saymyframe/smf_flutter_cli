import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

/// Reports, in source order, the list literals passed as the named argument
/// [name] that a call or widget creation matching [parentMatch] takes.
///
/// The list matches when one of the calls or widget creations whose
/// arguments hold it, its own or one around it, has [parentMatch] in its
/// source before its arguments, as the parser prints it: `MultiProvider` in
/// `MultiProvider(providers: [...])`, or `const MaterialApp` in
/// `const MaterialApp(supportedLocales: [...])`. The arguments themselves
/// don't count, so neither do the elements of the list nor the arguments
/// next to it.
class NamedListVisitor extends RecursiveAstVisitor<void> {
  /// Creates a visitor that calls [onMatch] for each matching list.
  NamedListVisitor({
    required this.name,
    required this.parentMatch,
    required this.onMatch,
  });

  /// The name of the argument that takes the list, such as `providers`.
  final String name;

  /// Text that a call or widget creation that takes the list has before its
  /// arguments, such as `MultiProvider`.
  final String parentMatch;

  /// Called with each matching list.
  final void Function(ListLiteral) onMatch;

  @override
  void visitNamedArgument(NamedArgument node) {
    final expression = node.argumentExpression;
    if (node.name.lexeme == name &&
        expression is ListLiteral &&
        _isTakenByParentMatch(node)) {
      onMatch(expression);
    }
    super.visitNamedArgument(node);
  }

  /// Whether one of the argument lists that hold [argument] belongs to a
  /// call or widget creation with [parentMatch] before it.
  bool _isTakenByParentMatch(NamedArgument argument) {
    for (var node = argument.parent; node != null; node = node.parent) {
      if (node is ArgumentList) {
        // The argument list comes last in the source of its call.
        final call = node.parent!.toSource();
        final head = call.substring(0, call.length - node.toSource().length);
        if (head.contains(parentMatch)) return true;
      }
    }
    return false;
  }
}
