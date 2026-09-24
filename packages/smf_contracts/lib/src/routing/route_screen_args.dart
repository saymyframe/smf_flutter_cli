import 'package:smf_contracts/smf_contracts.dart';

/// Where the value of a screen argument comes from.
enum ParameterSource {
  /// A segment of the route's path, declared as a [PathParam].
  path,

  /// The query string of the route's location, declared as a [QueryParam].
  query,
}

/// Maps a parameter of a route to a constructor argument of its screen.
///
/// For a route with the path `/users/:userId`, this passes the `userId`
/// segment to the screen's `id` argument:
///
/// ```dart
/// const RouteScreenArgs(
///   name: 'id',
///   sourceName: 'userId',
///   source: ParameterSource.path,
/// )
/// ```
class RouteScreenArgs {
  /// Creates the argument [name], filled from the [source] parameter
  /// [sourceName].
  const RouteScreenArgs({
    required this.name,
    required this.sourceName,
    required this.source,
    this.isNamed = true,
  });

  /// Name of the constructor parameter; ignored when [isNamed] is `false`.
  final String name;

  /// [RouteParameter.name] of the parameter that provides the value.
  ///
  /// The route must declare that parameter in [Route.parameters]; generation
  /// fails otherwise.
  final String sourceName;

  /// Whether the value comes from the path or the query string.
  final ParameterSource source;

  /// Whether the value is passed as a named argument (`name: value`) or as
  /// a positional one.
  final bool isNamed;
}
