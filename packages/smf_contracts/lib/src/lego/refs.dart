import 'package:meta/meta.dart';
import 'package:smf_contracts/lego_core.dart';

/// A Dart type that code of the generated app refers to, with the import
/// that declares it, such as `AnalyticsService` of
/// `ImportRef.app('core/analytics/analytics_service.dart')`.
///
/// [name] is a plain type name without type arguments. Two references are
/// the same type when they have the same name and import.
@immutable
final class TypeRef {
  /// Refers to the type [name], declared by [import], or by `dart:core` if
  /// [import] is `null`.
  const TypeRef(this.name, {this.import});

  /// The name of the type, such as `AnalyticsService`.
  final String name;

  /// The import that declares the type, or `null` for a type of `dart:core`,
  /// such as `int`.
  final ImportRef? import;

  /// The type as code refers to it: [name], after the prefix of [import]
  /// if it has one.
  String get code => _prefixed(import, name);

  /// Describes what is wrong with this reference, or returns an empty list.
  List<String> problems() => [
        if (!_isPublicIdentifier(name))
          'The type "$name" is not a public Dart type name.',
        ...?import?.problems(),
      ];

  @override
  bool operator ==(Object other) =>
      other is TypeRef && other.name == name && other.import == import;

  @override
  int get hashCode => Object.hash(name, import);

  @override
  String toString() => name;
}

/// A top-level function of the generated app or of a package, with the
/// import that declares it, such as a function that disposes of a service.
@immutable
final class FunctionRef {
  /// Refers to the function [name] declared by [import].
  const FunctionRef(this.name, {required this.import});

  /// The name of the function.
  final String name;

  /// The import that declares the function.
  final ImportRef import;

  /// The function as code refers to it: [name], after the prefix of
  /// [import] if it has one.
  String get code => _prefixed(import, name);

  /// Describes what is wrong with this reference, or returns an empty list.
  List<String> problems() => [
        if (!_isPublicIdentifier(name))
          'The function "$name" is not a public Dart function name.',
        ...import.problems(),
      ];

  @override
  String toString() => '$name()';
}

/// A top-level function that creates a value, such as
/// `createFirebaseAnalyticsService`, and the services it takes.
///
/// The function takes one positional argument per entry of [deps], in that
/// order, which the DI container resolves (see `DiRegistration`). A factory
/// without [deps] takes no arguments.
@immutable
final class FactoryRef {
  /// Refers to the factory [name] declared by [import], which takes [deps].
  const FactoryRef(this.name, {required this.import, this.deps = const []});

  /// The name of the function.
  final String name;

  /// The import that declares the function.
  final ImportRef import;

  /// The services the function takes, in the order of its parameters.
  final List<ServiceRef> deps;

  /// The function as code refers to it: [name], after the prefix of
  /// [import] if it has one.
  String get code => _prefixed(import, name);

  /// Describes what is wrong with this reference, or returns an empty list.
  List<String> problems() => [
        if (!_isPublicIdentifier(name))
          'The factory "$name" is not a public Dart function name.',
        ...import.problems(),
        for (final dep in deps) ...dep.problems(),
      ];

  @override
  String toString() => '$name()';
}

/// A service of the app's DI container: a type and, if the container has
/// several services of the type, the name of one of them.
@immutable
final class ServiceRef {
  /// Refers to the service of [type], or to the one named [instanceName].
  const ServiceRef(this.type, {this.instanceName});

  /// The type the service is registered as.
  final TypeRef type;

  /// The name that tells apart services of the same type, or `null` for the
  /// unnamed one.
  final String? instanceName;

  /// Describes what is wrong with this reference, or returns an empty list.
  List<String> problems() => [
        ...type.problems(),
        if (instanceName case final name? when name.isEmpty)
          'The instance name of $type must not be empty.',
      ];

  @override
  bool operator ==(Object other) =>
      other is ServiceRef &&
      other.type == type &&
      other.instanceName == instanceName;

  @override
  int get hashCode => Object.hash(type, instanceName);

  @override
  String toString() => instanceName == null ? '$type' : '$type "$instanceName"';
}

String _prefixed(ImportRef? import, String name) {
  final prefix = import?.prefix;
  return prefix == null ? name : '$prefix.$name';
}

bool _isPublicIdentifier(String name) =>
    SmfNames.isDartIdentifier(name) && !name.startsWith('_');
