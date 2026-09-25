import 'package:smf_contracts/lego_core.dart';

/// What a rendered Dart file of the generated app declares and uses, as
/// data.
///
/// The contract test harness builds an index for every Dart file it renders,
/// by parsing it without resolving types. [StructuralRule]s of roles and the
/// [RequiredSymbol]s of role interfaces are checked against these indexes,
/// so roles need no analyzer and the harness knows no role.
///
/// Names are as written in the source: without type resolution, `Foo()` is
/// an invocation of `Foo` whether `Foo` is a function or a class.
final class DartFileIndex {
  /// Creates the index of the file at [path].
  const DartFileIndex({
    required this.path,
    this.imports = const [],
    this.exports = const [],
    this.declarations = const [],
    this.invocations = const [],
    this.references = const [],
    this.memberAccesses = const [],
  });

  /// The path of the file relative to the project root, with forward
  /// slashes, such as `lib/main.dart`.
  final String path;

  /// The import directives, in source order.
  final List<IndexedImport> imports;

  /// The export directives, in source order; an export has no prefix.
  final List<IndexedImport> exports;

  /// The top-level declarations, in source order.
  final List<IndexedDeclaration> declarations;

  /// The function, method and constructor invocations, in source order.
  final List<IndexedInvocation> invocations;

  /// Identifiers used without being invoked, such as tear-offs and reads of
  /// variables, in source order. Declarations and the names of invoked
  /// functions are not included.
  final List<IndexedReference> references;

  /// Property accesses, such as `context.nav` or `nav.home`, in source
  /// order.
  final List<IndexedMemberAccess> memberAccesses;

  /// Whether the file imports [uri].
  bool importsUri(String uri) => imports.any((import) => import.uri == uri);

  /// The top-level declaration named [name], if the file has one.
  IndexedDeclaration? declaration(String name) {
    for (final declaration in declarations) {
      if (declaration.name == name) return declaration;
    }
    return null;
  }

  /// The invocations of [name], optionally only those inside the top-level
  /// declaration [within].
  Iterable<IndexedInvocation> invocationsOf(String name, {String? within}) {
    return invocations.where(
      (invocation) =>
          invocation.name == name &&
          (within == null || invocation.enclosingDeclaration == within),
    );
  }

  /// Whether the file uses [name] at all: invokes it, refers to it, or
  /// accesses it as a property.
  bool uses(String name) =>
      invocations.any((invocation) => invocation.name == name) ||
      references.any((reference) => reference.name == name) ||
      memberAccesses.any((access) => access.name == name);
}

/// An import or export directive of an indexed file.
final class IndexedImport {
  /// Creates the index of an import or export of [uri].
  const IndexedImport(
    this.uri, {
    this.prefix,
    this.show = const [],
    this.hide = const [],
  });

  /// The imported or exported URI, as written.
  final String uri;

  /// The import prefix, if any.
  final String? prefix;

  /// The names in `show` combinators.
  final List<String> show;

  /// The names in `hide` combinators.
  final List<String> hide;
}

/// Kinds of top-level declarations.
enum DeclarationKind {
  /// A class.
  classType,

  /// A mixin.
  mixinType,

  /// An enum.
  enumType,

  /// An extension.
  extension,

  /// An extension type.
  extensionType,

  /// A typedef.
  typedef,

  /// A function.
  function,

  /// A getter.
  getter,

  /// A setter.
  setter,

  /// A variable.
  variable,
}

/// A top-level declaration of an indexed file.
final class IndexedDeclaration {
  /// Creates the index of the declaration [name].
  const IndexedDeclaration({
    required this.name,
    required this.kind,
    this.type,
    this.parameters = const [],
    this.constructors = const [],
    this.annotations = const [],
    this.isAsync = false,
    this.offset = 0,
  });

  /// The declared name.
  final String name;

  /// What is declared.
  final DeclarationKind kind;

  /// The declared type as written: the return type of a function or
  /// getter, the type of a variable, or `null` if it is not written.
  final String? type;

  /// The parameters of a function or setter.
  final List<IndexedParameter> parameters;

  /// The constructors declared by a class, enum or extension type; empty if
  /// it declares none and so has only the implicit default constructor.
  final List<IndexedConstructor> constructors;

  /// The annotations, as written, such as `@RoutePage(name: 'HomeRoute')`.
  final List<String> annotations;

  /// Whether the body of a function is `async` or `async*`.
  final bool isAsync;

  /// The offset of the declaration in the file.
  final int offset;

  /// The unnamed constructor, the implicit default one if the declaration
  /// declares no constructors, or `null` if it declares only named ones.
  IndexedConstructor? get unnamedConstructor {
    if (constructors.isEmpty) return const IndexedConstructor();
    for (final constructor in constructors) {
      if (constructor.name.isEmpty) return constructor;
    }
    return null;
  }
}

/// A constructor of an indexed class.
final class IndexedConstructor {
  /// Creates the index of a constructor; the default is the implicit
  /// default constructor.
  const IndexedConstructor({
    this.name = '',
    this.parameters = const [],
    this.isConst = false,
    this.isFactory = false,
  });

  /// The name after the class name, or empty for the unnamed constructor.
  final String name;

  /// The parameters.
  final List<IndexedParameter> parameters;

  /// Whether the constructor is `const`.
  final bool isConst;

  /// Whether the constructor is a `factory`.
  final bool isFactory;
}

/// Kinds of parameters.
enum ParameterKind {
  /// A required positional parameter.
  requiredPositional,

  /// An optional positional parameter, in square brackets.
  optionalPositional,

  /// A named parameter marked `required`.
  requiredNamed,

  /// A named parameter that is not `required`.
  optionalNamed;

  /// Whether the parameter is named.
  bool get isNamed => this == requiredNamed || this == optionalNamed;

  /// Whether a call must pass the parameter.
  bool get isRequired => this == requiredPositional || this == requiredNamed;
}

/// A parameter of an indexed function or constructor.
final class IndexedParameter {
  /// Creates the index of the parameter [name].
  const IndexedParameter(
    this.name, {
    required this.kind,
    this.type,
    this.annotations = const [],
  });

  /// The name of the parameter.
  final String name;

  /// What kind of parameter it is.
  final ParameterKind kind;

  /// The type as written; for an initializing formal such as `this.tab`,
  /// the type of the field it initializes, if the class declares it with
  /// one; otherwise `null`, as in `super.key`.
  final String? type;

  /// The annotations, as written, such as `@PathParam('id')`.
  final List<String> annotations;
}

/// An invocation in an indexed file, such as `getIt<A>()`,
/// `context.nav.home.details(id: 1)` or `HomeScreen()`.
final class IndexedInvocation {
  /// Creates the index of an invocation of [name].
  const IndexedInvocation(
    this.name, {
    this.target,
    this.typeArguments = const [],
    this.namedArguments = const [],
    this.enclosingDeclaration,
    this.awaited = false,
    this.offset = 0,
  });

  /// The name of the invoked function, method or class.
  final String name;

  /// The expression before the name, as written, such as `context.nav.home`
  /// in `context.nav.home.details()`; `null` for a plain call.
  final String? target;

  /// The type arguments, as written, such as `['AnalyticsService']`.
  final List<String> typeArguments;

  /// The names of the named arguments.
  final List<String> namedArguments;

  /// The name of the top-level declaration the invocation is in, or `null`
  /// outside any.
  final String? enclosingDeclaration;

  /// Whether the invocation is the operand of an `await`.
  final bool awaited;

  /// The offset of the invocation in the file.
  final int offset;
}

/// An identifier used without being invoked, such as the tear-off
/// `resolve<A>` or a read of `appRouter`.
final class IndexedReference {
  /// Creates the index of a reference to [name].
  const IndexedReference(
    this.name, {
    this.enclosingDeclaration,
    this.offset = 0,
  });

  /// The referenced name.
  final String name;

  /// The name of the top-level declaration the reference is in, or `null`
  /// outside any.
  final String? enclosingDeclaration;

  /// The offset of the reference in the file.
  final int offset;
}

/// A property access, such as `nav.home` in `context.nav.home`.
final class IndexedMemberAccess {
  /// Creates the index of an access to [name] on [target].
  const IndexedMemberAccess(
    this.target,
    this.name, {
    this.enclosingDeclaration,
    this.offset = 0,
  });

  /// The expression before the dot, as written, such as `context.nav`.
  final String target;

  /// The accessed property.
  final String name;

  /// The name of the top-level declaration the access is in, or `null`
  /// outside any.
  final String? enclosingDeclaration;

  /// The offset of the access in the file.
  final int offset;
}
