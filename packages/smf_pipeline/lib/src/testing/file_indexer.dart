import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/lego_core.dart';

/// Builds the [DartFileIndex] of a Dart file by parsing it, without
/// resolving any type.
///
/// Parse errors do not stop it: the index holds what could be parsed, and
/// [DartFileIndexer.errorsOf] reports the errors.
abstract final class DartFileIndexer {
  /// The index of [content], the file at [path] relative to the project
  /// root.
  static DartFileIndex index(String path, String content) {
    final unit = parseString(content: content, throwIfDiagnostics: false).unit;
    final visitor = _IndexVisitor();
    unit.accept(visitor);
    return DartFileIndex(
      path: path,
      imports: [
        for (final directive in unit.directives)
          if (directive is ImportDirective) _import(directive),
      ],
      declarations: [
        for (final declaration in unit.declarations)
          ..._declarations(declaration),
      ],
      invocations: List.unmodifiable(visitor.invocations),
      references: List.unmodifiable(visitor.references),
      memberAccesses: List.unmodifiable(visitor.memberAccesses),
    );
  }

  /// The parse errors of [content], each with its offset.
  static List<String> errorsOf(String content) => [
        for (final error
            in parseString(content: content, throwIfDiagnostics: false).errors)
          '${error.message} (at ${error.offset})',
      ];
}

IndexedImport _import(ImportDirective directive) => IndexedImport(
      directive.uri.stringValue ?? '',
      prefix: directive.prefix?.name,
      show: [
        for (final combinator in directive.combinators)
          if (combinator is ShowCombinator)
            for (final name in combinator.shownNames) name.name,
      ],
      hide: [
        for (final combinator in directive.combinators)
          if (combinator is HideCombinator)
            for (final name in combinator.hiddenNames) name.name,
      ],
    );

List<String> _annotations(NodeList<Annotation> metadata) =>
    [for (final annotation in metadata) annotation.toSource()];

Iterable<IndexedDeclaration> _declarations(
  CompilationUnitMember member,
) sync* {
  final annotations = _annotations(member.metadata);
  final offset = member.offset;
  switch (member) {
    case ClassDeclaration():
      yield IndexedDeclaration(
        name: member.name.lexeme,
        kind: DeclarationKind.classType,
        constructors: _constructors(member.members),
        annotations: annotations,
        offset: offset,
      );
    case MixinDeclaration():
      yield IndexedDeclaration(
        name: member.name.lexeme,
        kind: DeclarationKind.mixinType,
        annotations: annotations,
        offset: offset,
      );
    case EnumDeclaration():
      yield IndexedDeclaration(
        name: member.name.lexeme,
        kind: DeclarationKind.enumType,
        constructors: _constructors(member.members),
        annotations: annotations,
        offset: offset,
      );
    case ExtensionTypeDeclaration(:final representation):
      yield IndexedDeclaration(
        name: member.name.lexeme,
        kind: DeclarationKind.extensionType,
        constructors: [
          IndexedConstructor(
            name: representation.constructorName?.name.lexeme ?? '',
            parameters: [
              IndexedParameter(
                representation.fieldName.lexeme,
                kind: ParameterKind.requiredPositional,
                type: representation.fieldType.toSource(),
                annotations: _annotations(representation.fieldMetadata),
              ),
            ],
            isConst: member.constKeyword != null,
          ),
          ..._constructors(member.members),
        ],
        annotations: annotations,
        offset: offset,
      );
    case ExtensionDeclaration(:final name?):
      yield IndexedDeclaration(
        name: name.lexeme,
        kind: DeclarationKind.extension,
        annotations: annotations,
        offset: offset,
      );
    case ExtensionDeclaration():
      break;
    case ClassTypeAlias():
      yield IndexedDeclaration(
        name: member.name.lexeme,
        kind: DeclarationKind.classType,
        annotations: annotations,
        offset: offset,
      );
    case TypeAlias():
      yield IndexedDeclaration(
        name: member.name.lexeme,
        kind: DeclarationKind.typedef,
        annotations: annotations,
        offset: offset,
      );
    case FunctionDeclaration():
      final function = member.functionExpression;
      yield IndexedDeclaration(
        name: member.name.lexeme,
        kind: member.isGetter
            ? DeclarationKind.getter
            : member.isSetter
                ? DeclarationKind.setter
                : DeclarationKind.function,
        type: member.returnType?.toSource(),
        parameters: _parameters(function.parameters),
        annotations: annotations,
        isAsync: function.body.isAsynchronous,
        offset: offset,
      );
    case TopLevelVariableDeclaration():
      final type = member.variables.type?.toSource();
      for (final variable in member.variables.variables) {
        yield IndexedDeclaration(
          name: variable.name.lexeme,
          kind: DeclarationKind.variable,
          type: type,
          annotations: annotations,
          offset: variable.offset,
        );
      }
  }
}

List<IndexedConstructor> _constructors(NodeList<ClassMember> members) => [
      for (final member in members)
        if (member is ConstructorDeclaration)
          IndexedConstructor(
            name: member.name?.lexeme ?? '',
            parameters: _parameters(member.parameters),
            isConst: member.constKeyword != null,
            isFactory: member.factoryKeyword != null,
          ),
    ];

List<IndexedParameter> _parameters(FormalParameterList? list) => [
      for (final parameter in list?.parameters ?? const <FormalParameter>[])
        IndexedParameter(
          parameter.name?.lexeme ?? '',
          kind: parameter.isRequiredPositional
              ? ParameterKind.requiredPositional
              : parameter.isOptionalPositional
                  ? ParameterKind.optionalPositional
                  : parameter.isRequiredNamed
                      ? ParameterKind.requiredNamed
                      : ParameterKind.optionalNamed,
          type: _typeOf(parameter),
          annotations: _annotations(parameter.metadata),
        ),
    ];

String? _typeOf(FormalParameter parameter) {
  final normal = switch (parameter) {
    DefaultFormalParameter(:final parameter) => parameter,
    NormalFormalParameter() => parameter,
  };
  return switch (normal) {
    SimpleFormalParameter(:final type) => type?.toSource(),
    FieldFormalParameter(:final type) => type?.toSource(),
    SuperFormalParameter(:final type) => type?.toSource(),
    FunctionTypedFormalParameter() => normal.toSource(),
  };
}

/// The name of the top-level declaration that contains [node], if any.
String? _enclosing(AstNode node) {
  for (AstNode? current = node; current != null; current = current.parent) {
    final parent = current.parent;
    if (parent is! CompilationUnit) continue;
    return switch (current) {
      NamedCompilationUnitMember(:final name) => name.lexeme,
      ExtensionDeclaration(:final name) => name?.lexeme,
      TopLevelVariableDeclaration(:final variables) =>
        _variableOf(variables, node),
      _ => null,
    };
  }
  return null;
}

/// The name of the variable among [variables] whose initializer holds
/// [node].
String? _variableOf(VariableDeclarationList variables, AstNode node) {
  for (final variable in variables.variables) {
    if (node.offset >= variable.offset && node.end <= variable.end) {
      return variable.name.lexeme;
    }
  }
  return null;
}

bool _isAwaited(AstNode node) {
  var current = node.parent;
  while (current is ParenthesizedExpression) {
    current = current.parent;
  }
  return current is AwaitExpression;
}

final class _IndexVisitor extends RecursiveAstVisitor<void> {
  final List<IndexedInvocation> invocations = [];
  final List<IndexedReference> references = [];
  final List<IndexedMemberAccess> memberAccesses = [];

  /// Identifiers that name something invoked or accessed, which are not
  /// references of their own.
  final Set<SimpleIdentifier> _named = {};

  List<String> _typeArguments(TypeArgumentList? list) => [
        for (final type in list?.arguments ?? const <TypeAnnotation>[])
          type.toSource(),
      ];

  List<String> _namedArguments(ArgumentList list) => [
        for (final argument in list.arguments)
          if (argument is NamedExpression) argument.name.label.name,
      ];

  @override
  void visitMethodInvocation(MethodInvocation node) {
    _named.add(node.methodName);
    invocations.add(
      IndexedInvocation(
        node.methodName.name,
        target: node.realTarget?.toSource(),
        typeArguments: _typeArguments(node.typeArguments),
        namedArguments: _namedArguments(node.argumentList),
        enclosingDeclaration: _enclosing(node),
        awaited: _isAwaited(node),
        offset: node.offset,
      ),
    );
    super.visitMethodInvocation(node);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression node) {
    final constructor = node.constructorName;
    final type = constructor.type;
    final named = constructor.name?.name;
    invocations.add(
      IndexedInvocation(
        named ?? type.name.lexeme,
        target: named == null
            ? type.importPrefix?.name.lexeme
            : type.importPrefix == null
                ? type.name.lexeme
                : '${type.importPrefix!.name.lexeme}.${type.name.lexeme}',
        typeArguments: _typeArguments(type.typeArguments),
        namedArguments: _namedArguments(node.argumentList),
        enclosingDeclaration: _enclosing(node),
        awaited: _isAwaited(node),
        offset: node.offset,
      ),
    );
    super.visitInstanceCreationExpression(node);
  }

  @override
  void visitFunctionExpressionInvocation(FunctionExpressionInvocation node) {
    final function = node.function;
    final (name, target) = switch (function) {
      SimpleIdentifier(:final name) => (name, null),
      PrefixedIdentifier(:final prefix, :final identifier) => (
          identifier.name,
          prefix.name,
        ),
      PropertyAccess(:final realTarget, :final propertyName) => (
          propertyName.name,
          realTarget.toSource(),
        ),
      _ => (null, null),
    };
    if (name != null) {
      invocations.add(
        IndexedInvocation(
          name,
          target: target,
          typeArguments: _typeArguments(node.typeArguments),
          namedArguments: _namedArguments(node.argumentList),
          enclosingDeclaration: _enclosing(node),
          awaited: _isAwaited(node),
          offset: node.offset,
        ),
      );
    }
    super.visitFunctionExpressionInvocation(node);
  }

  @override
  void visitPropertyAccess(PropertyAccess node) {
    _named.add(node.propertyName);
    memberAccesses.add(
      IndexedMemberAccess(
        node.realTarget.toSource(),
        node.propertyName.name,
        enclosingDeclaration: _enclosing(node),
        offset: node.propertyName.offset,
      ),
    );
    super.visitPropertyAccess(node);
  }

  @override
  void visitPrefixedIdentifier(PrefixedIdentifier node) {
    _named.add(node.identifier);
    memberAccesses.add(
      IndexedMemberAccess(
        node.prefix.name,
        node.identifier.name,
        enclosingDeclaration: _enclosing(node),
        offset: node.identifier.offset,
      ),
    );
    super.visitPrefixedIdentifier(node);
  }

  @override
  void visitSimpleIdentifier(SimpleIdentifier node) {
    if (_named.contains(node) || _isDeclarationOrLabel(node)) return;
    references.add(
      IndexedReference(
        node.name,
        enclosingDeclaration: _enclosing(node),
        offset: node.offset,
      ),
    );
  }

  /// Whether [node] is not a use of a name: a part of the declaration of a
  /// constructor or of a call to one, the label of a named argument, a name
  /// in a combinator, a part of a directive, or a part of an annotation,
  /// which the index keeps as text.
  static bool _isDeclarationOrLabel(SimpleIdentifier node) {
    final parent = node.parent;
    if ((parent is ConstructorDeclaration && parent.returnType == node) ||
        (parent is ConstructorFieldInitializer && parent.fieldName == node) ||
        parent is ConstructorName ||
        parent is SuperConstructorInvocation ||
        parent is RedirectingConstructorInvocation) {
      return true;
    }
    for (var current = node.parent; current != null; current = current.parent) {
      if (current is Label ||
          current is Combinator ||
          current is Directive ||
          current is Annotation) {
        return true;
      }
      if (current is Expression || current is Statement) return false;
    }
    return false;
  }
}
