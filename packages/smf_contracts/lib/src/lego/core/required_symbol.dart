import 'package:smf_contracts/lego_core.dart';

/// A symbol that every provider of a role must generate, such as the
/// `createAppRouter()` function of a router.
///
/// Other code of the app refers to it by name, so it must be declared at
/// the top level of the file at [path]. The contract test harness checks it
/// structurally against the [DartFileIndex] of that file with [checkIn];
/// types are checked by compiling the generated app.
sealed class RequiredSymbol {
  const RequiredSymbol(this.name, {required this.path});

  /// The name of the symbol.
  final String name;

  /// The path of the file that declares it, relative to the project root,
  /// such as `lib/bootstrap.dart`.
  final String path;

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
}

/// A parameter a [RequiredSymbol] must accept.
final class RequiredParameter {
  /// Requires a parameter called [name], named unless [named] is `false`.
  const RequiredParameter(this.name, {this.named = true});

  /// The name of the parameter.
  final String name;

  /// Whether it is a named parameter.
  final bool named;
}

/// A top-level function that a provider must generate.
final class RequiredFunction extends RequiredSymbol {
  /// Requires the function [name] in [path], returning [returnType] if set
  /// and callable with exactly [parameters].
  const RequiredFunction(
    super.name, {
    required super.path,
    this.returnType,
    this.parameters = const [],
  });

  /// The return type as written, such as `Future<void>`, or `null` to allow
  /// any.
  final String? returnType;

  /// The parameters the function must accept; it may have others only if
  /// they are optional.
  final List<RequiredParameter> parameters;

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
      ..._parameterProblems(declaration.parameters, parameters),
    ];
  }

  @override
  String toString() => 'function $name()';
}

/// A top-level class that a provider must generate.
final class RequiredClass extends RequiredSymbol {
  /// Requires the class [name] in [path], whose unnamed constructor accepts
  /// exactly [constructorParameters] and is `const` if [constConstructor]
  /// is set.
  const RequiredClass(
    super.name, {
    required super.path,
    this.constructorParameters = const [],
    this.constConstructor = false,
  });

  /// The parameters the unnamed constructor must accept; it may have others
  /// only if they are optional.
  final List<RequiredParameter> constructorParameters;

  /// Whether the unnamed constructor must be `const`, so other code can
  /// create constant instances.
  final bool constConstructor;

  @override
  List<String> _problemsOf(IndexedDeclaration declaration) {
    if (declaration.kind != DeclarationKind.classType) {
      return ['must be a class, not a ${declaration.kind.name}'];
    }
    final constructor = declaration.unnamedConstructor;
    if (constructor == null) return ['must have an unnamed constructor'];
    return [
      if (constConstructor && !constructor.isConst)
        'must have a const unnamed constructor',
      ..._parameterProblems(constructor.parameters, constructorParameters),
    ];
  }

  @override
  String toString() => 'class $name';
}

List<String> _parameterProblems(
  List<IndexedParameter> actual,
  List<RequiredParameter> required,
) {
  final problems = <String>[];
  for (final parameter in required) {
    final accepted = actual.any(
      (p) => p.name == parameter.name && p.kind.isNamed == parameter.named,
    );
    if (!accepted) {
      final kind = parameter.named ? 'named' : 'positional';
      problems.add('must accept the $kind parameter ${parameter.name}');
    }
  }
  for (final parameter in actual) {
    if (parameter.kind.isRequired &&
        !required.any((r) => r.name == parameter.name)) {
      problems.add('must not require the parameter ${parameter.name}');
    }
  }
  return problems;
}

String _normalized(String type) => type.replaceAll(RegExp(r'\s+'), '');
