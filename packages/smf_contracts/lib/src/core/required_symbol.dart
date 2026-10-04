import 'package:smf_contracts/core.dart';

/// A symbol that every provider of a role must generate, such as the
/// `createAppRouter()` function of a router.
///
/// Other code of the app refers to it by name, so it must be declared at
/// the top level of the file at [path]. It must be callable the way that
/// code calls it: with [positionalArguments] positional arguments and the
/// named arguments [namedParameters], and no other required parameters.
///
/// The contract test harness checks it structurally against the
/// [DartFileIndex] of that file with [checkIn]; types are checked by
/// compiling the generated app.
sealed class RequiredSymbol {
  const RequiredSymbol(
    this.name, {
    required this.path,
    required this.namedParameters,
    required this.positionalArguments,
  });

  /// The name of the symbol.
  final String name;

  /// The path of the file that declares it, relative to the project root,
  /// such as `lib/bootstrap.dart`.
  final String path;

  /// The named parameters that callers pass; the symbol may have other
  /// named parameters only if they are optional.
  final List<String> namedParameters;

  /// How many positional arguments callers pass.
  final int positionalArguments;

  /// The import of [path], for code that uses the symbol.
  ImportRef get importRef => ImportRef.app(
        path.startsWith('lib/') ? path.substring('lib/'.length) : path,
      );

  /// Checks that [files], indexes by path, declare this symbol as required,
  /// and returns the problems found.
  List<SmfIssue> checkIn(Map<String, DartFileIndex> files) {
    final file = files[path];
    if (file == null) {
      return [
        SmfIssue('$path is missing, so it cannot declare $this.', path: path),
      ];
    }
    final declaration = file.declaration(name);
    if (declaration == null) {
      return [SmfIssue('$path does not declare $this.', path: path)];
    }
    return [
      for (final problem in _problemsOf(declaration))
        SmfIssue('$this in $path $problem.', path: path),
    ];
  }

  List<String> _problemsOf(IndexedDeclaration declaration);

  List<String> _parameterProblems(List<IndexedParameter> parameters) {
    final problems = <String>[];
    final positional = parameters.where((p) => !p.kind.isNamed).toList();
    final required = positional.where((p) => p.kind.isRequired).length;
    if (required > positionalArguments) {
      problems.add(
        'must not require more than $positionalArguments positional '
        'arguments',
      );
    }
    if (positional.length < positionalArguments) {
      problems.add('must accept $positionalArguments positional arguments');
    }
    for (final name in namedParameters) {
      if (!parameters.any((p) => p.kind.isNamed && p.name == name)) {
        problems.add('must accept the named parameter $name');
      }
    }
    for (final parameter in parameters) {
      if (parameter.kind == ParameterKind.requiredNamed &&
          !namedParameters.contains(parameter.name)) {
        problems.add('must not require the parameter ${parameter.name}');
      }
    }
    return problems;
  }
}

/// A top-level function that a provider must generate.
final class RequiredFunction extends RequiredSymbol {
  /// Requires the function [name] in [path], returning [returnType] if set.
  const RequiredFunction(
    super.name, {
    required super.path,
    this.returnType,
    super.namedParameters = const [],
    super.positionalArguments = 0,
  });

  /// The return type as written, such as `Future<void>`, or `null` to allow
  /// any.
  final String? returnType;

  @override
  List<String> _problemsOf(IndexedDeclaration declaration) {
    if (declaration.kind != DeclarationKind.function) {
      return ['must be a function, not a ${declaration.kind.name}'];
    }
    final type = declaration.type;
    return [
      if (returnType != null &&
          (type == null || _normalized(type) != _normalized(returnType!)))
        'must return $returnType, not ${type ?? 'an undeclared type'}',
      ..._parameterProblems(declaration.parameters),
    ];
  }

  @override
  String toString() => 'function $name()';
}

/// A top-level class that a provider must generate; the parameters are those
/// of its unnamed constructor, and the [getters] are what other code reads
/// from its instances.
final class RequiredClass extends RequiredSymbol {
  /// Requires the class [name] in [path], whose unnamed constructor is
  /// `const` if [constConstructor] is set, and which declares [getters].
  const RequiredClass(
    super.name, {
    required super.path,
    super.namedParameters = const [],
    super.positionalArguments = 0,
    this.constConstructor = false,
    this.getters = const [],
  });

  /// Whether the unnamed constructor must be `const`, so other code can
  /// create constant instances.
  final bool constConstructor;

  /// The names that other code reads from an instance of the class, such
  /// as `destinations` in `shell.destinations`.
  ///
  /// The class must declare each of them as a public instance field or
  /// getter. It must declare them itself: the check sees only the members
  /// that the class declares, not those it inherits.
  final List<String> getters;

  @override
  List<String> _problemsOf(IndexedDeclaration declaration) {
    if (declaration.kind != DeclarationKind.classType) {
      return ['must be a class, not a ${declaration.kind.name}'];
    }
    final constructor = declaration.unnamedConstructor;
    return [
      if (constructor == null)
        'must have an unnamed constructor'
      else ...[
        if (constConstructor && !constructor.isConst)
          'must have a const unnamed constructor',
        ..._parameterProblems(constructor.parameters),
      ],
      for (final getter in getters)
        if (!declaration.members.any((member) => _reads(member, getter)))
          'must declare the public instance field or getter $getter',
    ];
  }

  @override
  String toString() => 'class $name';
}

/// An extension that a provider must generate, such as the one that gives
/// every `BuildContext` the texts of the app; the [getters] are what other
/// code reads from an instance of the type it is [on].
///
/// Other code never calls an extension, so it has no parameters. It names
/// the extension only to show or to hide it in an import, and reads its
/// getters from the objects it extends, as in `context.l10n`.
final class RequiredExtension extends RequiredSymbol {
  /// Requires the extension [name] in [path] on the type [on], which
  /// declares [getters].
  const RequiredExtension(
    super.name, {
    required super.path,
    required this.on,
    this.getters = const [],
  }) : super(namedParameters: const [], positionalArguments: 0);

  /// The type that the extension is on, as written, such as `BuildContext`.
  final String on;

  /// The names that other code reads from an instance of [on] through the
  /// extension, such as `l10n` in `context.l10n`.
  ///
  /// The extension must declare each of them as an instance getter.
  final List<String> getters;

  @override
  List<String> _problemsOf(IndexedDeclaration declaration) {
    if (declaration.kind != DeclarationKind.extension) {
      return ['must be an extension, not a ${declaration.kind.name}'];
    }
    final type = declaration.type;
    return [
      if (type == null || _normalized(type) != _normalized(on))
        'must be on $on, not on ${type?.trim() ?? 'an undeclared type'}',
      for (final getter in getters)
        if (!declaration.members.any(
          (member) =>
              member.name == getter &&
              !member.isStatic &&
              member.kind == MemberKind.getter,
        ))
          'must declare the instance getter $getter',
    ];
  }

  @override
  String toString() => 'extension $name';
}

/// Whether other code reads [name] from an instance as [member]: an
/// instance field or getter of that name.
bool _reads(IndexedMember member, String name) =>
    member.name == name &&
    !member.isStatic &&
    (member.kind == MemberKind.field || member.kind == MemberKind.getter);

String _normalized(String type) => type.replaceAll(RegExp(r'\s+'), '');
