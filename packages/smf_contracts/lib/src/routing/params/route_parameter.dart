import 'package:smf_contracts/smf_contracts.dart';

/// A value that a route reads from its location to pass to its screen.
///
/// Declare parameters in [Route.parameters] as a [PathParam] or
/// [QueryParam], and map them to constructor arguments of the screen with
/// [RouteScreenArgs].
abstract class RouteParameter {
  /// Declares the parameter [name] of the given [type].
  const RouteParameter(this.name, {required this.type, this.optional = false});

  /// Name of the path segment (without the `:`) or of the query key.
  final String name;

  /// Dart type of the value: `int` and `double` are parsed, `bool` is `true`
  /// only for the text `true`, and any other type is passed as a `String`.
  final Type type;

  /// Whether the location may leave the value out.
  ///
  /// Generated code null-checks required values and passes optional ones on
  /// as nullable, so the screen argument must accept `null`.
  final bool optional;
}
