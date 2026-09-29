import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:smf_contribution_engine/smf_contribution_engine.dart';
import 'package:smf_contribution_engine/src/utils/list_inserts.dart';
import 'package:smf_contribution_engine/src/utils/named_lists.dart';

/// Adds an element at the end of a list literal passed as a named argument
/// in a method, such as the `supportedLocales` of the `MaterialApp` built in
/// `MainApp.build`.
///
/// The target is the first method named [method] in the first class named
/// [className]. In its body, the candidates are the lists passed as a
/// [listVariableMatch] argument, nested ones included, to a call or widget
/// creation that matches [parentExpressionMatch]; [index] picks one of them
/// in source order, and [insert] goes right before its `]`.
///
/// Throws an [Exception] when the class or the method is missing, when the
/// method body is an expression, or when there is no candidate at [index].
///
/// When the list already has every element of [insert], as the parser prints
/// them, the file is returned as it is, so running it again changes nothing.
/// Comments in the file are kept, but the whole file is reformatted.
class InsertIntoListInMethodInClass extends Contribution {
  /// Creates a contribution that adds [insert] to a list in [method] of
  /// [className].
  const InsertIntoListInMethodInClass({
    required super.file,
    required this.className,
    required this.method,
    required this.listVariableMatch,
    required this.parentExpressionMatch,
    required this.insert,
    this.index = 0,
  });

  /// The name of the class that declares [method], such as `MainApp`.
  final String className;

  /// The name of the method that holds the list, such as `build`.
  final String method;

  /// The name of the argument that takes the list, such as
  /// `supportedLocales`.
  final String listVariableMatch;

  /// Text that the call or widget creation taking the list, or one around
  /// it, has before its arguments, such as `MaterialApp`.
  ///
  /// It is matched against the source as the parser prints it, such as
  /// `const MaterialApp` or `MaterialApp.router`. The arguments don't count,
  /// so neither do the elements of the list nor the arguments next to it.
  final String parentExpressionMatch;

  /// Which of the matching lists to change, counting from zero in source
  /// order.
  final int index;

  /// The element to add, such as `Locale('uk'),`. [PatchEngine] renders its
  /// placeholders.
  ///
  /// Nothing separates it from the last element, so a list without a
  /// trailing comma makes [apply] throw a `FormatterException`.
  final String insert;

  @override
  Future<String> apply(String original) async {
    final result = parseString(content: original);
    final unit = result.unit;

    final targetClass =
        unit.declarations.whereType<ClassDeclaration>().firstWhere(
              (c) => c.name.lexeme == className,
              orElse: () => throw Exception('Class $className not found'),
            );

    final targetMethod = targetClass.members
        .whereType<MethodDeclaration>()
        .firstWhere(
          (m) => m.name.lexeme == method,
          orElse: () =>
              throw Exception('Method $method not found in class $className'),
        );

    final body = targetMethod.body;
    if (body is! BlockFunctionBody) {
      throw Exception('Method body is not a block');
    }

    final matches = <ListLiteral>[];

    body.visitChildren(
      NamedListVisitor(
        name: listVariableMatch,
        parentMatch: parentExpressionMatch,
        onMatch: matches.add,
      ),
    );

    if (matches.length <= index) {
      throw Exception('No matching list found at index $index');
    }

    final targetList = matches[index];
    if (ListInsert.parse(insert)?.isIn(targetList) ?? false) return original;

    final updated = original.replaceRange(
      targetList.rightBracket.offset,
      targetList.rightBracket.offset,
      '\n$insert',
    );

    return dartFormater.format(updated);
  }
}
