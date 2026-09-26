import 'package:smf_contracts/lego_core.dart';

/// Identifies a module: a lower snake_case name such as `go_router`.
///
/// A module package declares its id once, as a constant of its module
/// class:
///
/// ```dart
/// final class GoRouterModule extends SmfModule {
///   static const id = ModuleId('go_router');
///   // ...
/// }
/// ```
///
/// Other modules refer to that constant in [ModuleDescriptor.dependsOn], so
/// that a dependency on a module is also a pub dependency on its package;
/// the contract tests check that the two agree, because writing
/// `ModuleId('go_router')` by hand would bypass it. [Variants] key their
/// variants by the id's value instead, because a feature must not depend on
/// the packages of every provider it supports.
///
/// The id is a zero-cost wrapper over the name: ids compare by name, work as
/// keys of constant maps, and print as the plain name. The pipeline rejects
/// registries with invalid ids; see [isValid].
extension type const ModuleId(String value) implements Object {
  /// Parses [value], such as a module name given on the command line.
  ///
  /// Throws a [FormatException] unless [value] [isValid].
  factory ModuleId.parse(String value) {
    if (!isValid(value)) {
      throw FormatException(
        'A module id must be lower snake_case, such as go_router.',
        value,
      );
    }
    return ModuleId(value);
  }

  /// Whether [value] is a valid module id: lower snake_case, see
  /// [SmfNames.isSnakeCase].
  static bool isValid(String value) => SmfNames.isSnakeCase(value);

  /// The id as a lowerCamelCase Dart identifier: `firebase_core` becomes
  /// `firebaseCore`.
  String get lowerCamelCase => SmfNames.lowerCamelCase(value);

  /// The id as an UpperCamelCase Dart identifier: `firebase_core` becomes
  /// `FirebaseCore`.
  String get upperCamelCase => SmfNames.upperCamelCase(value);
}
