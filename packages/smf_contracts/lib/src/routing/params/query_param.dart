import 'package:smf_contracts/src/routing/params/params.dart';

/// A parameter read from the query string of the route's location, such as
/// `q` in `/search?q=flutter`.
class QueryParam extends RouteParameter {
  /// Declares the query parameter [name] of the given [type]; set [optional]
  /// if the location may leave it out.
  const QueryParam(super.name, {required super.type, super.optional});
}
