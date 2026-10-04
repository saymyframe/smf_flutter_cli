import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';
import 'package:smf_contracts/core.dart';

/// Builds the [DartFileIndex] of a Dart file by parsing it, without
/// resolving any type.
///
/// Parse errors do not stop it: the index holds what could be parsed, and
/// [DartFileIndexer.parse] also returns the errors.
///
/// Doc comments and annotations are not uses of names: the index keeps
/// annotations as text and skips comments.
abstract final class DartFileIndexer {
  /// The index of [content], the file at [path] relative to the project
  /// root.
  static DartFileIndex index(String path, String content) =>
      parse(path, content).index;

  /// The index of [content], the file at [path], and its parse errors, each
  /// with its offset.
  static ({DartFileIndex index, List<String> errors}) parse(
    String path,
    String content,
  ) {
    final result = parseString(content: content, throwIfDiagnostics: false);
    return (
      index: _indexOf(path, result.unit),
      errors: [
        for (final error in result.errors)
          '${error.message} (at ${error.offset})',
      ],
    );
  }

  /// The parse errors of [content], each with its offset.
  static List<String> errorsOf(String content) => parse('', content).errors;

  static DartFileIndex _indexOf(String path, CompilationUnit unit) {
    final visitor = _IndexVisitor();
    unit.accept(visitor);
    return DartFileIndex(
      path: path,
      imports: [
        for (final directive in unit.directives)
          if (directive is ImportDirective) _import(directive),
      ],
      exports: [
        for (final directive in unit.directives)
          if (directive is ExportDirective) _import(directive),
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
}

IndexedImport _import(NamespaceDirective directive) => IndexedImport(
      directive.uri.stringValue ?? '',
      prefix: directive is ImportDirective ? directive.prefix?.name : null,
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
    case ClassDeclaration(:final namePart, :final body):
      yield IndexedDeclaration(
        name: namePart.typeName.lexeme,
        kind: DeclarationKind.classType,
        constructors: _constructors(namePart, body.members),
        members: _members(body.members),
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
    case EnumDeclaration(:final namePart, :final body):
      yield IndexedDeclaration(
        name: namePart.typeName.lexeme,
        kind: DeclarationKind.enumType,
        constructors: _constructors(namePart, body.members),
        annotations: annotations,
        offset: offset,
      );
    case ExtensionTypeDeclaration(:final namePart, :final body):
      yield IndexedDeclaration(
        name: namePart.typeName.lexeme,
        kind: DeclarationKind.extensionType,
        constructors: _constructors(namePart, body.members),
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
        kind: _functionKind(member),
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

/// The kind of [function]: a getter, a setter or a function.
DeclarationKind _functionKind(FunctionDeclaration function) {
  if (function.isGetter) return DeclarationKind.getter;
  if (function.isSetter) return DeclarationKind.setter;
  return DeclarationKind.function;
}

/// The constructors of a class, enum or extension type: the primary
/// constructor that [namePart] declares, if it does, such as that of an
/// extension type, whose one parameter is its representation, and then
/// those among its [members].
List<IndexedConstructor> _constructors(
  ClassNamePart namePart,
  NodeList<ClassMember> members,
) {
  // The types of the fields, for initializing formals such as `this.tab`.
  final fields = <String, String>{};
  for (final member in members) {
    if (member is FieldDeclaration && !member.isStatic) {
      final type = member.fields.type?.toSource();
      if (type == null) continue;
      for (final variable in member.fields.variables) {
        fields[variable.name.lexeme] = type;
      }
    }
  }
  return [
    if (namePart
        case PrimaryConstructorDeclaration(
          :final constructorName,
          :final formalParameters,
          :final constKeyword,
        ))
      IndexedConstructor(
        name: constructorName?.name.lexeme ?? '',
        parameters: _parameters(formalParameters, fields),
        isConst: constKeyword != null,
      ),
    for (final member in members)
      if (member is ConstructorDeclaration)
        IndexedConstructor(
          name: member.name?.lexeme ?? '',
          parameters: _parameters(member.parameters, fields),
          isConst: member.constKeyword != null,
          isFactory: member.factoryKeyword != null,
        ),
  ];
}

/// The members among [members] other than the constructors: a member for
/// each variable of a field declaration, and one for each method, getter,
/// setter and operator, with its parameters.
List<IndexedMember> _members(NodeList<ClassMember> members) => [
      for (final member in members)
        if (member is FieldDeclaration)
          for (final variable in member.fields.variables)
            IndexedMember(
              variable.name.lexeme,
              kind: MemberKind.field,
              isStatic: member.isStatic,
            )
        else if (member is MethodDeclaration)
          IndexedMember(
            member.name.lexeme,
            kind: _memberKind(member),
            isStatic: member.isStatic,
            parameters: _parameters(member.parameters),
          ),
    ];

/// The kind of [method]: a getter, a setter or a method.
MemberKind _memberKind(MethodDeclaration method) {
  if (method.isGetter) return MemberKind.getter;
  if (method.isSetter) return MemberKind.setter;
  return MemberKind.method;
}

List<IndexedParameter> _parameters(
  FormalParameterList? list, [
  Map<String, String> fields = const {},
]) =>
    [
      for (final parameter in list?.parameters ?? const <FormalParameter>[])
        IndexedParameter(
          parameter.name?.lexeme ?? '',
          kind: _parameterKind(parameter),
          type: _typeOf(parameter, fields),
          annotations: _annotations(parameter.metadata),
        ),
    ];

/// The kind of [parameter]: positional or named, required or optional.
ParameterKind _parameterKind(FormalParameter parameter) {
  if (parameter.isRequiredPositional) return ParameterKind.requiredPositional;
  if (parameter.isOptionalPositional) return ParameterKind.optionalPositional;
  if (parameter.isRequiredNamed) return ParameterKind.requiredNamed;
  return ParameterKind.optionalNamed;
}

/// The type of [parameter] as written, without its default value: that of
/// its field for an initializing formal without one, and the whole
/// parameter for a function-typed one, such as `void callback(int value)`.
String? _typeOf(FormalParameter parameter, Map<String, String> fields) =>
    switch (parameter) {
      FieldFormalParameter(:final type, :final name) =>
        type?.toSource() ?? fields[name.lexeme],
      SuperFormalParameter(:final type) => type?.toSource(),
      RegularFormalParameter(
        :final type,
        :final name?,
        :final functionTypedSuffix?,
      ) =>
        [
          if (type != null) type.toSource(),
          '${name.lexeme}${functionTypedSuffix.toSource()}',
        ].join(' '),
      RegularFormalParameter(:final type) => type?.toSource(),
    };

/// The name of the top-level declaration that contains [node], if any.
String? _enclosing(AstNode node) {
  for (AstNode? current = node; current != null; current = current.parent) {
    final parent = current.parent;
    if (parent is! CompilationUnit) continue;
    return switch (current) {
      ClassDeclaration(:final namePart) ||
      EnumDeclaration(:final namePart) ||
      ExtensionTypeDeclaration(:final namePart) =>
        namePart.typeName.lexeme,
      MixinDeclaration(:final name) ||
      FunctionDeclaration(:final name) ||
      TypeAlias(:final name) =>
        name.lexeme,
      ExtensionDeclaration(:final name) => name?.lexeme,
      TopLevelVariableDeclaration(:final variables) =>
        _variableOf(variables, node),
      // coverage:ignore-start
      // The other children of a compilation unit are its directives and
      // script tag, in which the index records no use.
      _ => null,
      // coverage:ignore-end
    };
  }
  return null;
}

/// The name of the method, getter or setter that contains [node], if any.
String? _enclosingMember(AstNode node) =>
    node.thisOrAncestorOfType<MethodDeclaration>()?.name.lexeme;

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
          if (argument is NamedArgument) argument.name.lexeme,
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
        enclosingMember: _enclosingMember(node),
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
        target: _creationTarget(type, named),
        typeArguments: _typeArguments(type.typeArguments),
        namedArguments: _namedArguments(node.argumentList),
        enclosingDeclaration: _enclosing(node),
        enclosingMember: _enclosingMember(node),
        awaited: _isAwaited(node),
        offset: node.offset,
      ),
    );
    super.visitInstanceCreationExpression(node);
  }

  // Doc comments refer to names without using them.
  @override
  void visitComment(Comment node) {}

  // Annotations are kept as text; the names in them are not uses.
  @override
  void visitAnnotation(Annotation node) {}

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
    if (_named.contains(node) || _isNotAUse(node)) return;
    references.add(
      IndexedReference(
        node.name,
        enclosingDeclaration: _enclosing(node),
        offset: node.offset,
      ),
    );
  }

  /// Whether [node] is not a use of a name: a part of the declaration of a
  /// constructor or of a call to one, a name in a combinator, a part of a
  /// directive, or a part of an annotation, which the index keeps as text.
  /// The labels of named arguments, of the named fields of records and of
  /// statements are tokens rather than identifiers, so the visitor meets
  /// none of them.
  static bool _isNotAUse(SimpleIdentifier node) {
    final parent = node.parent;
    if ((parent is ConstructorDeclaration && parent.typeName == node) ||
        (parent is ConstructorFieldInitializer && parent.fieldName == node) ||
        parent is ConstructorName ||
        parent is SuperConstructorInvocation ||
        parent is RedirectingConstructorInvocation) {
      return true;
    }
    for (var current = node.parent; current != null; current = current.parent) {
      if (current is Combinator ||
          current is Directive ||
          current is Annotation) {
        return true;
      }
      if (current is Expression || current is Statement) return false;
    }
    return false;
  }
}

/// The target of a creation of [type] with the constructor [named]: the
/// prefix of the type for its unnamed constructor, and the type, after its
/// prefix, for a named one.
String? _creationTarget(NamedType type, String? named) {
  final prefix = type.importPrefix?.name.lexeme;
  if (named == null) return prefix;
  return prefix == null ? type.name.lexeme : '$prefix.${type.name.lexeme}';
}
