import 'package:smf_contracts/src/routing/params/params.dart';

/// A parameter read from a `:name` segment of the route's path, such as `id`
/// in `/users/:id`. Path parameters are always required.
class PathParam extends RouteParameter {
  /// Declares the path parameter [name] of the given [type].
  const PathParam(super.name, {required super.type});
}
